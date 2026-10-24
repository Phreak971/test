import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'voice.dart';

/// Speaks guidance with the selected persona, ducking other audio.
abstract class Speaker {
  Future<void> speak(String text, VoicePersona persona, String langCode);
  Future<void> stop();
}

class TtsSpeaker implements Speaker {
  TtsSpeaker() : _tts = FlutterTts() {
    unawaited(_init());
  }

  final FlutterTts _tts;
  bool _ready = false;

  static const _locales = {
    'en': 'en-US',
    'de': 'de-DE',
    'fr': 'fr-FR',
    'it': 'it-IT',
    'es': 'es-ES',
    'tr': 'tr-TR',
  };

  Future<void> _init() async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        await _tts.setSharedInstance(true);
        await _tts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [
            IosTextToSpeechAudioCategoryOptions.duckOthers,
            IosTextToSpeechAudioCategoryOptions.interruptSpokenAudioAndMixWithOthers,
          ],
          IosTextToSpeechAudioMode.voicePrompt,
        );
      }
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await _tts.setAudioAttributesForNavigation();
      }
      await _tts.awaitSpeakCompletion(false);
    } catch (e) {
      debugPrint('TTS init failed: $e');
    }
    _ready = true;
  }

  @override
  Future<void> speak(String text, VoicePersona persona, String langCode) async {
    if (!_ready) await _init();
    try {
      await _tts.setLanguage(_locales[langCode] ?? 'en-US');
      await _tts.setPitch(persona.pitch.clamp(0.5, 2.0));
      await _tts.setSpeechRate(persona.rate.clamp(0.1, 1.0));
      await _tts.speak(text);
    } catch (e) {
      debugPrint('TTS speak failed: $e');
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
