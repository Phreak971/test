import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';

import 'voice.dart';
import 'voice_fx.dart';
import 'voice_select.dart';

/// Speaks guidance with the selected persona, ducking other audio.
abstract class Speaker {
  Future<void> speak(String text, VoicePersona persona, String langCode);
  Future<void> stop();
}

/// On-device TTS. Each persona gets its own system voice (gender/accent),
/// pitch and rate; personas with an effect are rendered to a file,
/// processed and played back. Any failure on that path falls back to
/// speaking directly so guidance is never lost.
class TtsSpeaker implements Speaker {
  TtsSpeaker() : _tts = FlutterTts() {
    unawaited(_init());
  }

  final FlutterTts _tts;
  AudioPlayer? _player;
  bool _ready = false;
  List<SystemVoice> _voices = const [];
  String? _dir;

  /// Turned off for the session after an effect render fails or stalls.
  bool _fxUsable = !kIsWeb;

  /// Bumped by every speak/stop so a slow render can't play late.
  int _generation = 0;
  int _clip = 0;

  static const _locales = {'en': 'en-US', 'de': 'de-DE', 'fr': 'fr-FR', 'it': 'it-IT', 'es': 'es-ES', 'tr': 'tr-TR'};
  static const _renderTimeout = Duration(milliseconds: 3500);

  bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> _init() async {
    if (_ready) return;
    try {
      if (_isIOS) {
        await _tts.setSharedInstance(true);
        await _tts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
          IosTextToSpeechAudioCategoryOptions.duckOthers,
          IosTextToSpeechAudioCategoryOptions.interruptSpokenAudioAndMixWithOthers,
        ], IosTextToSpeechAudioMode.voicePrompt);
      }
      if (_isAndroid) {
        await _tts.setAudioAttributesForNavigation();
      }
      await _tts.awaitSpeakCompletion(false);
      // Android signals file completion reliably; iOS is polled instead.
      if (_isAndroid) await _tts.awaitSynthCompletion(true);
    } catch (e) {
      debugPrint('TTS init failed: $e');
    }
    try {
      final raw = await _tts.getVoices;
      _voices = [
        if (raw is List)
          for (final v in raw) ?SystemVoice.fromMap(v),
      ];
    } catch (e) {
      debugPrint('TTS voices unavailable: $e');
    }
    _ready = true;
  }

  /// Serialises speak calls so language/pitch settings of overlapping
  /// prompts can't interleave; a newer prompt replaces the current one.
  Future<void> _queue = Future.value();

  @override
  Future<void> speak(String text, VoicePersona persona, String langCode) {
    final gen = ++_generation;
    final next = _queue.then((_) => _speak(text, persona, langCode, gen));
    _queue = next.catchError((_) {});
    return next;
  }

  Future<void> _speak(String text, VoicePersona persona, String langCode, int gen) async {
    if (!_ready) await _init();
    if (gen != _generation) return;
    try {
      await _haltPlayback();
      await _configure(persona, langCode);
      if (persona.fx != VoiceFx.none && _fxUsable) {
        if (await _speakWithFx(text, persona.fx, gen)) return;
        if (gen != _generation) return;
      }
      await _tts.speak(text);
    } catch (e) {
      debugPrint('TTS speak failed: $e');
    }
  }

  Future<void> _configure(VoicePersona persona, String langCode) async {
    await _tts.setLanguage(_locales[langCode] ?? 'en-US');
    final salt = voicePersonas.indexOf(persona);
    final voice = pickVoice(_voices, persona.wish, langCode, salt: salt < 0 ? 0 : salt);
    if (voice != null) {
      try {
        await _tts.setVoice(voice.toSetVoice());
      } catch (e) {
        debugPrint('TTS setVoice($voice) failed: $e');
      }
    }
    await _tts.setPitch(persona.pitch.clamp(0.5, 2.0));
    await _tts.setSpeechRate(persona.rate.clamp(0.1, 1.0));
  }

  /// Renders [text] to WAV, applies [fx] off the UI isolate and plays it.
  Future<bool> _speakWithFx(String text, VoiceFx fx, int gen) async {
    try {
      _dir ??= (await getTemporaryDirectory()).path;
      final slot = _clip++ % 4;
      final raw = File('$_dir/ow_voice_raw_$slot.wav');
      final out = File('$_dir/ow_voice_fx_$slot.wav');
      if (await raw.exists()) await raw.delete();

      final rendered = await _render(text, raw).timeout(_renderTimeout, onTimeout: () => false);
      if (!rendered) {
        _fxUsable = false;
        return false;
      }
      final processed = await compute(renderFxWav, (await raw.readAsBytes(), fx));
      if (processed == null) {
        _fxUsable = false;
        return false;
      }
      if (gen != _generation) return true; // superseded; drop silently
      await out.writeAsBytes(processed, flush: true);
      final player = _player ??= await _makePlayer();
      await player.play(DeviceFileSource(out.path, mimeType: 'audio/wav'));
      return true;
    } catch (e) {
      debugPrint('Voice effect failed, speaking plainly: $e');
      _fxUsable = false;
      return false;
    }
  }

  Future<bool> _render(String text, File file) async {
    final r = await _tts.synthesizeToFile(text, file.path, true);
    if (_isAndroid) return r == 1 && await file.exists();
    // iOS writes buffers asynchronously: wait until the file stops growing.
    var last = -1;
    var stable = 0;
    for (var i = 0; i < 60; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 60));
      final len = await file.exists() ? await file.length() : 0;
      if (len > 1024 && len == last) {
        if (++stable >= 3) return true;
      } else {
        stable = 0;
      }
      last = len;
    }
    return false;
  }

  Future<AudioPlayer> _makePlayer() async {
    final p = AudioPlayer(playerId: 'overworld-voice');
    await p.setReleaseMode(ReleaseMode.stop);
    await p.setAudioContext(
      AudioContext(
        android: const AudioContextAndroid(
          contentType: AndroidContentType.speech,
          usageType: AndroidUsageType.assistanceNavigationGuidance,
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: const {AVAudioSessionOptions.duckOthers, AVAudioSessionOptions.interruptSpokenAudioAndMixWithOthers},
        ),
      ),
    );
    return p;
  }

  Future<void> _haltPlayback() async {
    try {
      await _tts.stop();
    } catch (_) {}
    try {
      await _player?.stop();
    } catch (_) {}
  }

  @override
  Future<void> stop() async {
    _generation++;
    await _haltPlayback();
  }
}
