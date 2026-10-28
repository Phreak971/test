import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:overworld/nav/voice.dart';
import 'package:overworld/nav/voice_fx.dart';
import 'package:overworld/nav/voice_select.dart';

/// A one-second vowel-ish test tone (fundamental + harmonics).
Pcm _tone({int sr = 22050, double seconds = 1}) {
  final n = (sr * seconds).round();
  final x = Float32List(n);
  for (var i = 0; i < n; i++) {
    final t = i / sr;
    x[i] = 0.5 * math.sin(2 * math.pi * 140 * t) + 0.25 * math.sin(2 * math.pi * 280 * t) + 0.1 * math.sin(2 * math.pi * 1200 * t);
  }
  return Pcm(x, sr);
}

Uint8List _wav({
  required int format,
  required int bits,
  int channels = 1,
  int sr = 16000,
  int frames = 100,
  bool zeroDataSize = false,
  bool extraChunk = false,
}) {
  final bytesPer = bits ~/ 8;
  final data = frames * channels * bytesPer;
  final fmtSize = format == 0xFFFE ? 40 : 16;
  final extra = extraChunk ? 8 + 5 + 1 : 0; // odd-sized chunk + pad byte
  final b = ByteData(12 + 8 + fmtSize + extra + 8 + data);
  var o = 0;
  void tag(String s) {
    for (final c in s.codeUnits) {
      b.setUint8(o++, c);
    }
  }

  tag('RIFF');
  b.setUint32(o, b.lengthInBytes - 8, Endian.little);
  o += 4;
  tag('WAVE');
  tag('fmt ');
  b.setUint32(o, fmtSize, Endian.little);
  o += 4;
  b.setUint16(o, format, Endian.little);
  b.setUint16(o + 2, channels, Endian.little);
  b.setUint32(o + 4, sr, Endian.little);
  b.setUint32(o + 8, sr * channels * bytesPer, Endian.little);
  b.setUint16(o + 12, channels * bytesPer, Endian.little);
  b.setUint16(o + 14, bits, Endian.little);
  if (format == 0xFFFE) {
    b.setUint16(o + 16, 22, Endian.little);
    b.setUint16(o + 24, 3, Endian.little); // float sub-format
  }
  o += fmtSize;
  if (extraChunk) {
    tag('LIST');
    b.setUint32(o, 5, Endian.little);
    o += 4 + 5 + 1;
  }
  tag('data');
  b.setUint32(o, zeroDataSize ? 0 : data, Endian.little);
  o += 4;
  for (var i = 0; i < frames * channels; i++) {
    final v = 0.5 * math.sin(i / 5);
    final f = format == 1 ? 1 : (format == 2 ? 0 : 3);
    if (f == 0) {
      // Unsupported codec: leave the bytes zeroed.
    } else if (f == 3) {
      b.setFloat32(o, v, Endian.little);
    } else if (bits == 16) {
      b.setInt16(o, (v * 32767).round(), Endian.little);
    } else if (bits == 24) {
      final s = (v * 8388607).round();
      b.setUint8(o, s & 0xFF);
      b.setUint8(o + 1, (s >> 8) & 0xFF);
      b.setUint8(o + 2, (s >> 16) & 0xFF);
    } else if (bits == 8) {
      b.setUint8(o, (v * 127 + 128).round());
    }
    o += bytesPer;
  }
  return b.buffer.asUint8List();
}

void main() {
  group('WAV decoding', () {
    test('16-bit PCM roundtrips through encodeWav', () {
      final pcm = _tone(seconds: 0.2);
      final back = decodeWav(encodeWav(pcm))!;
      expect(back.sampleRate, pcm.sampleRate);
      expect(back.samples.length, pcm.samples.length);
      for (var i = 0; i < 500; i++) {
        expect(back.samples[i], closeTo(pcm.samples[i], 1 / 16000));
      }
    });

    for (final (format, bits) in [(1, 8), (1, 16), (1, 24), (3, 32), (0xFFFE, 32)]) {
      test('decodes format $format / $bits-bit, stereo, with extra chunks', () {
        final pcm = decodeWav(_wav(format: format, bits: bits, channels: 2, extraChunk: true))!;
        expect(pcm.samples.length, 100);
        // Frame 5 averages interleaved samples 10 and 11.
        expect(pcm.samples[5], closeTo(0.25 * (math.sin(10 / 5) + math.sin(11 / 5)), 0.02));
      });
    }

    test('tolerates an unfinalised data size (iOS writer)', () {
      expect(decodeWav(_wav(format: 3, bits: 32, zeroDataSize: true))!.samples.length, 100);
    });

    test('rejects non-WAV and unsupported data', () {
      expect(decodeWav(Uint8List.fromList(List.filled(64, 7))), isNull);
      expect(decodeWav(Uint8List(4)), isNull);
      expect(decodeWav(_wav(format: 2, bits: 16)), isNull); // ADPCM
    });
  });

  group('effects', () {
    for (final fx in VoiceFx.values) {
      test('$fx produces finite, normalised audio', () {
        final input = _tone();
        final out = applyFx(input, fx);
        expect(out.sampleRate, input.sampleRate);
        expect(out.samples.length, greaterThanOrEqualTo(input.samples.length));
        var peak = 0.0;
        for (final v in out.samples) {
          expect(v.isFinite, isTrue);
          peak = math.max(peak, v.abs());
        }
        if (fx != VoiceFx.none) expect(peak, closeTo(0.9, 0.01));
      });
    }

    test('effects really change the sound', () {
      final input = _tone();
      double diff(Pcm a, Pcm b) {
        var s = 0.0;
        for (var i = 0; i < input.samples.length; i++) {
          s += (a.samples[i] / 0.9 - b.samples[i] / 0.9).abs();
        }
        return s / input.samples.length;
      }

      final plain = applyFx(input, VoiceFx.none);
      final normalisedPlain = Pcm(Float32List.fromList([for (final v in plain.samples) v * 0.9 / 0.85]), plain.sampleRate);
      for (final fx in VoiceFx.values.where((f) => f != VoiceFx.none)) {
        expect(diff(applyFx(input, fx), normalisedPlain), greaterThan(0.02), reason: '$fx');
      }
    });

    test('reverb and breath effects add a tail', () {
      final input = _tone();
      expect(applyFx(input, VoiceFx.hall).seconds, greaterThan(input.seconds + 1));
      expect(applyFx(input, VoiceFx.darkHelmet).seconds, greaterThan(applyFx(input, VoiceFx.helmet).seconds + 1.5));
    });

    test('renderFxWav handles bad input', () {
      expect(renderFxWav((Uint8List(10), VoiceFx.robot)), isNull);
      expect(decodeWav(renderFxWav((encodeWav(_tone(seconds: 0.1)), VoiceFx.radio))!), isNotNull);
    });
  });

  group('voice selection', () {
    final android = [
      for (final n in [
        'en-us-x-iob-local',
        'en-us-x-iol-local',
        'en-us-x-tpd-network',
        'en-gb-x-gba-local',
        'en-gb-x-rjs-local',
        'en-au-x-aub-local',
      ])
        SystemVoice(
          name: n,
          locale: n.substring(0, 5).replaceRange(3, 5, n.substring(3, 5).toUpperCase()),
          networkRequired: n.endsWith('network'),
        ),
      const SystemVoice(name: 'de-de-x-deg-local', locale: 'de-DE'),
      const SystemVoice(name: 'de-de-x-dea-local', locale: 'de-DE'),
    ];
    final ios = [
      const SystemVoice(name: 'Samantha', locale: 'en-US', gender: 'female'),
      const SystemVoice(name: 'Daniel', locale: 'en-GB', gender: 'male'),
      const SystemVoice(name: 'Grandpa', locale: 'en-GB', gender: 'male'),
      const SystemVoice(name: 'Zarvox', locale: 'en-US', identifier: 'com.apple.speech.synthesis.voice.Zarvox'),
      const SystemVoice(name: 'Karen', locale: 'en-AU', gender: 'female'),
    ];

    test('parses flutter_tts maps', () {
      final v = SystemVoice.fromMap({'name': 'Daniel', 'locale': 'en_GB', 'gender': 'Male', 'quality': 'enhanced'})!;
      expect(v.locale, 'en-GB');
      expect(genderOf(v), VoiceGender.male);
      expect(SystemVoice.fromMap({'name': 1}), isNull);
      expect(SystemVoice.fromMap('x'), isNull);
    });

    test('gender comes from Google codes, Samsung codes and names', () {
      expect(genderOf(const SystemVoice(name: 'en-gb-x-rjs-local', locale: 'en-GB')), VoiceGender.male);
      expect(genderOf(const SystemVoice(name: 'en-us-x-tpc-network', locale: 'en-US')), VoiceGender.female);
      expect(genderOf(const SystemVoice(name: 'en-US-SMTf00', locale: 'en-US')), VoiceGender.female);
      expect(genderOf(const SystemVoice(name: 'Microsoft George - English', locale: 'en-GB')), VoiceGender.male);
      expect(genderOf(const SystemVoice(name: 'en-us-x-zzz-local', locale: 'en-US')), isNull);
    });

    test('matches gender and accent on Android', () {
      final dark = pickVoice(android, personaById('darklord').wish, 'en')!;
      expect(genderOf(dark), VoiceGender.male);
      final elf = pickVoice(android, personaById('elvenqueen').wish, 'en')!;
      expect(elf.name, 'en-gb-x-gba-local');
      final captain = pickVoice(android, personaById('captain').wish, 'en')!;
      expect(captain.locale, 'en-AU');
      // German user: still a male voice for a male character.
      expect(pickVoice(android, personaById('dwarflord').wish, 'de')!.name, 'de-de-x-deg-local');
    });

    test('prefers offline voices and skips other languages', () {
      final v = pickVoice(android, const VoiceWish(gender: VoiceGender.male, accents: ['en-US']), 'en')!;
      expect(v.networkRequired, isFalse);
      expect(pickVoice(android, const VoiceWish(), 'tr'), isNull);
    });

    test('named iOS voices win; novelty voices only when asked for', () {
      expect(pickVoice(ios, personaById('greywizard').wish, 'en')!.name, 'Grandpa');
      expect(pickVoice(ios, personaById('shipai').wish, 'en')!.name, 'Zarvox');
      for (final p in voicePersonas.where((p) => !p.wish.named.contains('Zarvox'))) {
        expect(pickVoice(ios, p.wish, 'en')!.name, isNot('Zarvox'), reason: p.id);
      }
    });

    test('salt spreads equally good voices', () {
      final picks = {for (var s = 0; s < 4; s++) pickVoice(android, const VoiceWish(gender: VoiceGender.male), 'en', salt: s)!.name};
      expect(picks.length, greaterThan(1));
    });
  });

  test('every persona has a unique id and a distinct sound profile', () {
    expect(voicePersonas.map((p) => p.id).toSet().length, voicePersonas.length);
    expect(voicePersonas.length, greaterThanOrEqualTo(19));
    final profiles = {for (final p in voicePersonas) '${p.pitch}/${p.rate}/${p.fx}/${p.wish.gender}'};
    expect(profiles.length, voicePersonas.length);
    for (final p in voicePersonas) {
      expect(p.pitch, inInclusiveRange(0.5, 2.0));
      expect(p.rate, inInclusiveRange(0.3, 0.7));
    }
  });
}
