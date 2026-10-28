import 'dart:math' as math;
import 'dart:typed_data';

/// Character effect applied to synthesized speech. Each one turns the same
/// system voice into something recognisably different (helmet, droid, cave…).
enum VoiceFx {
  none,

  /// Strong ring modulation and grit: a synthetic ship computer.
  robot,

  /// Light, high ring modulation: a fussy protocol droid.
  droid,

  /// Narrow band-pass, clipping and hiss: a field radio / megaphone.
  radio,

  /// Gentler band-pass: a starship comm channel.
  comms,

  /// Muffled, metallic mask resonance.
  helmet,

  /// [helmet] plus a mechanical breath after each line.
  darkHelmet,

  /// Short, dense rock reverb: halls under the mountain.
  cave,

  /// Long, bright reverb: a throne room or wizard's tower.
  hall,

  /// Chorus plus long shimmering reverb: an elven voice.
  ethereal,

  /// Reduced sample rate and bit depth: an 8-bit game character.
  bitcrush,
}

/// Mono audio as floats in [-1, 1].
class Pcm {
  Pcm(this.samples, this.sampleRate);

  final Float32List samples;
  final int sampleRate;

  double get seconds => samples.length / sampleRate;
}

// ---------------------------------------------------------------------------
// WAV I/O

/// Decodes a RIFF/WAVE file (PCM 8/16/24/32-bit, float 32/64, extensible) to
/// mono. Tolerates unfinalised headers (data size 0 or past EOF), which some
/// platform writers leave behind. Returns null when the bytes aren't WAV.
Pcm? decodeWav(Uint8List bytes) {
  if (bytes.length < 12) return null;
  final d = ByteData.sublistView(bytes);
  String tag(int o) => String.fromCharCodes(bytes.sublist(o, o + 4));
  if (tag(0) != 'RIFF' || tag(8) != 'WAVE') return null;

  int? format, channels, rate, bits;
  var off = 12;
  while (off + 8 <= bytes.length) {
    final id = tag(off);
    var size = d.getUint32(off + 4, Endian.little);
    final body = off + 8;
    if (id == 'fmt ' && body + 16 <= bytes.length) {
      format = d.getUint16(body, Endian.little);
      channels = d.getUint16(body + 2, Endian.little);
      rate = d.getUint32(body + 4, Endian.little);
      bits = d.getUint16(body + 14, Endian.little);
      if (format == 0xFFFE && size >= 26 && body + 26 <= bytes.length) {
        format = d.getUint16(body + 24, Endian.little); // sub-format GUID
      }
    } else if (id == 'data') {
      if (format == null || channels == null || rate == null || bits == null) return null;
      if (size == 0 || size == 0xFFFFFFFF || body + size > bytes.length) size = bytes.length - body;
      return _decodeData(d, body, size, format, channels, rate, bits);
    }
    off = body + size + (size.isOdd ? 1 : 0);
  }
  return null;
}

Pcm? _decodeData(ByteData d, int start, int size, int format, int channels, int rate, int bits) {
  if (channels < 1 || rate < 1000 || rate > 384000) return null;
  final bytesPer = bits ~/ 8;
  if (bytesPer < 1) return null;
  final frame = bytesPer * channels;
  final frames = size ~/ frame;
  final out = Float32List(frames);
  double sample(int o) {
    if (format == 3) {
      return bits == 64 ? d.getFloat64(o, Endian.little) : d.getFloat32(o, Endian.little);
    }
    if (format != 1) return double.nan;
    return switch (bits) {
      8 => (d.getUint8(o) - 128) / 128.0,
      16 => d.getInt16(o, Endian.little) / 32768.0,
      24 => (((d.getUint8(o + 2) << 24) | (d.getUint8(o + 1) << 16) | (d.getUint8(o) << 8)).toSigned(32)) / 2147483648.0,
      32 => d.getInt32(o, Endian.little) / 2147483648.0,
      _ => double.nan,
    };
  }

  if ((format != 1 && format != 3) || (format == 3 && bits != 32 && bits != 64)) return null;
  if (format == 1 && ![8, 16, 24, 32].contains(bits)) return null;
  for (var i = 0; i < frames; i++) {
    var acc = 0.0;
    final base = start + i * frame;
    for (var c = 0; c < channels; c++) {
      acc += sample(base + c * bytesPer);
    }
    final v = acc / channels;
    out[i] = v.isFinite ? v.clamp(-1.0, 1.0) : 0;
  }
  return Pcm(out, rate);
}

/// Encodes mono 16-bit PCM WAV.
Uint8List encodeWav(Pcm pcm) {
  final n = pcm.samples.length;
  final b = ByteData(44 + n * 2);
  void tag(int o, String s) {
    for (var i = 0; i < 4; i++) {
      b.setUint8(o + i, s.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  b.setUint32(4, 36 + n * 2, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  b.setUint32(16, 16, Endian.little);
  b.setUint16(20, 1, Endian.little);
  b.setUint16(22, 1, Endian.little);
  b.setUint32(24, pcm.sampleRate, Endian.little);
  b.setUint32(28, pcm.sampleRate * 2, Endian.little);
  b.setUint16(32, 2, Endian.little);
  b.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  b.setUint32(40, n * 2, Endian.little);
  for (var i = 0; i < n; i++) {
    b.setInt16(44 + i * 2, (pcm.samples[i].clamp(-1.0, 1.0) * 32767).round(), Endian.little);
  }
  return b.buffer.asUint8List();
}

/// Isolate entry point: WAV in, processed WAV out (null if undecodable).
Uint8List? renderFxWav((Uint8List, VoiceFx) args) {
  final pcm = decodeWav(args.$1);
  if (pcm == null || pcm.samples.isEmpty) return null;
  return encodeWav(applyFx(pcm, args.$2));
}

// ---------------------------------------------------------------------------
// Effects

Pcm applyFx(Pcm input, VoiceFx fx) {
  if (fx == VoiceFx.none) return input;
  final sr = input.sampleRate;
  var x = input.samples;
  switch (fx) {
    case VoiceFx.none:
      break;
    case VoiceFx.robot:
      x = _ringMod(x, sr, 58, 0.85);
      x = _comb(x, sr, 0.006, 0.45);
      x = _softClip(x, 1.8);
      x = _mix(x, _reverb(_pad(x, sr, 0.3), sr, room: 0.35, damp: 0.5), 0.15);
    case VoiceFx.droid:
      x = _ringMod(x, sr, 140, 0.32);
      x = _biquad(x, sr, _Filter.highpass, 260, 0.7);
      x = _comb(x, sr, 0.0025, 0.3);
    case VoiceFx.radio:
      x = _biquad(x, sr, _Filter.highpass, 420, 0.9);
      x = _biquad(x, sr, _Filter.lowpass, 2900, 0.9);
      x = _softClip(x, 3.5);
      x = _addNoise(x, 0.006, 11);
    case VoiceFx.comms:
      x = _biquad(x, sr, _Filter.highpass, 300, 0.7);
      x = _biquad(x, sr, _Filter.lowpass, 3600, 0.7);
      x = _softClip(x, 1.6);
      x = _addNoise(x, 0.005, 5);
    case VoiceFx.helmet:
    case VoiceFx.darkHelmet:
      x = _biquad(x, sr, _Filter.lowpass, 2400, 1.1);
      x = _biquad(x, sr, _Filter.peak, 520, 1.4, gainDb: 6);
      x = _comb(x, sr, 0.0042, 0.55);
      x = _softClip(x, 1.4);
      x = _mix(x, _reverb(_pad(x, sr, 0.25), sr, room: 0.3, damp: 0.7), 0.12);
      if (fx == VoiceFx.darkHelmet) x = _concat(_normalize(x, 0.9), _breath(sr, 7, _rms(x) * 0.9 / _peak(x)));
    case VoiceFx.cave:
      x = _mix(_pad(x, sr, 0.9), _reverb(_pad(x, sr, 0.9), sr, room: 0.72, damp: 0.55), 0.38);
    case VoiceFx.hall:
      x = _mix(_pad(x, sr, 1.4), _reverb(_pad(x, sr, 1.4), sr, room: 0.84, damp: 0.3), 0.34);
    case VoiceFx.ethereal:
      x = _chorus(x, sr);
      x = _mix(_pad(x, sr, 1.6), _reverb(_pad(x, sr, 1.6), sr, room: 0.88, damp: 0.2), 0.45);
    case VoiceFx.bitcrush:
      x = _crush(x, sr, 8000, 7);
      x = _biquad(x, sr, _Filter.highpass, 180, 0.7);
      x = _biquad(x, sr, _Filter.lowpass, 5200, 0.7);
  }
  return Pcm(_normalize(x, 0.9), sr);
}

Float32List _pad(Float32List x, int sr, double seconds) {
  final out = Float32List(x.length + (seconds * sr).round());
  out.setAll(0, x);
  return out;
}

Float32List _concat(Float32List a, Float32List b) {
  final out = Float32List(a.length + b.length);
  out.setAll(0, a);
  out.setAll(a.length, b);
  return out;
}

/// Mixes [wet] into [dry] (lengths may differ; result takes the longer).
Float32List _mix(Float32List dry, Float32List wet, double amount) {
  final n = math.max(dry.length, wet.length);
  final out = Float32List(n);
  for (var i = 0; i < n; i++) {
    final a = i < dry.length ? dry[i] : 0.0;
    final b = i < wet.length ? wet[i] : 0.0;
    out[i] = a * (1 - amount * 0.5) + b * amount;
  }
  return out;
}

Float32List _ringMod(Float32List x, int sr, double hz, double depth) {
  final out = Float32List(x.length);
  final w = 2 * math.pi * hz / sr;
  for (var i = 0; i < x.length; i++) {
    out[i] = x[i] * ((1 - depth) + depth * math.sin(w * i));
  }
  return out;
}

/// Feedback comb: metallic resonance at 1/delay Hz.
Float32List _comb(Float32List x, int sr, double delayS, double g) {
  final d = math.max(1, (delayS * sr).round());
  final out = Float32List(x.length);
  for (var i = 0; i < x.length; i++) {
    out[i] = x[i] + (i >= d ? g * out[i - d] : 0);
  }
  return out;
}

Float32List _softClip(Float32List x, double drive) {
  final out = Float32List(x.length);
  final norm = _tanh(drive);
  for (var i = 0; i < x.length; i++) {
    out[i] = _tanh(drive * x[i]) / norm;
  }
  return out;
}

double _tanh(double v) {
  if (v > 20) return 1;
  if (v < -20) return -1;
  final e = math.exp(2 * v);
  return (e - 1) / (e + 1);
}

/// Deterministic noise so tests and repeated prompts are stable.
Float32List _addNoise(Float32List x, double level, int seed) {
  final r = math.Random(seed);
  final out = Float32List(x.length);
  for (var i = 0; i < x.length; i++) {
    out[i] = x[i] + (r.nextDouble() * 2 - 1) * level;
  }
  return out;
}

Float32List _crush(Float32List x, int sr, int targetRate, int bits) {
  final hold = math.max(1, (sr / targetRate).round());
  final levels = math.pow(2, bits - 1).toDouble();
  final out = Float32List(x.length);
  var held = 0.0;
  for (var i = 0; i < x.length; i++) {
    if (i % hold == 0) held = (x[i] * levels).round() / levels;
    out[i] = held;
  }
  return out;
}

/// Slow modulated delay doubled under the dry voice.
Float32List _chorus(Float32List x, int sr) {
  final out = Float32List(x.length);
  final base = 0.018 * sr, depth = 0.006 * sr;
  for (var i = 0; i < x.length; i++) {
    final d = base + depth * math.sin(2 * math.pi * 0.7 * i / sr);
    final pos = i - d;
    var delayed = 0.0;
    if (pos >= 0) {
      final j = pos.floor();
      final f = pos - j;
      delayed = x[j] * (1 - f) + (j + 1 < x.length ? x[j + 1] : 0) * f;
    }
    out[i] = x[i] * 0.75 + delayed * 0.55;
  }
  return out;
}

/// Schroeder reverb: four damped parallel combs into two all-passes.
/// [room] 0..1 sets decay; [damp] 0..1 darkens the tail.
Float32List _reverb(Float32List x, int sr, {required double room, required double damp}) {
  const combMs = [29.7, 37.1, 41.1, 43.7];
  const allpassMs = [5.0, 1.7];
  final fb = 0.7 + 0.28 * room;
  final out = Float32List(x.length);
  for (final ms in combMs) {
    final d = math.max(1, (ms * (0.6 + room) * sr / 1000).round());
    final buf = Float32List(d);
    var idx = 0;
    var lp = 0.0;
    for (var i = 0; i < x.length; i++) {
      final y = buf[idx];
      lp = y * (1 - damp) + lp * damp;
      buf[idx] = x[i] + lp * fb;
      idx = (idx + 1) % d;
      out[i] += y * 0.25;
    }
  }
  var y = out;
  for (final ms in allpassMs) {
    final d = math.max(1, (ms * sr / 1000).round());
    final buf = Float32List(d);
    var idx = 0;
    final next = Float32List(y.length);
    for (var i = 0; i < y.length; i++) {
      final b = buf[idx];
      final v = y[i] + b * 0.5;
      buf[idx] = v;
      next[i] = b - v * 0.5;
      idx = (idx + 1) % d;
    }
    y = next;
  }
  return y;
}

/// Mechanical breath: filtered noise, an inhale then a longer exhale.
Float32List _breath(int sr, int seed, double speechRms) {
  final r = math.Random(seed);
  final gap = (0.22 * sr).round();
  final inhale = (0.75 * sr).round();
  final pause = (0.12 * sr).round();
  final exhale = (0.95 * sr).round();
  final out = Float32List(gap + inhale + pause + exhale);
  void segment(int start, int len, double hz, double level) {
    final noise = Float32List(len);
    for (var i = 0; i < len; i++) {
      noise[i] = r.nextDouble() * 2 - 1;
    }
    final band = _biquad(_biquad(noise, sr, _Filter.bandpass, hz, 1.2), sr, _Filter.lowpass, hz * 2.2, 0.7);
    for (var i = 0; i < len; i++) {
      final t = i / len;
      // Fast attack, long tail, like a respirator valve.
      final env = math.sin(math.pi * math.pow(t, 0.6)) * level;
      out[start + i] = band[i] * env;
    }
  }

  segment(gap, inhale, 900, 1);
  segment(gap + inhale + pause, exhale, 600, 1.2);
  // Sit well behind the voice: about a third of the speech level.
  final k = speechRms * 0.35 / math.max(_rms(out), 1e-9);
  for (var i = 0; i < out.length; i++) {
    out[i] *= k;
  }
  return out;
}

enum _Filter { lowpass, highpass, bandpass, peak }

/// RBJ cookbook biquad.
Float32List _biquad(Float32List x, int sr, _Filter type, double hz, double q, {double gainDb = 0}) {
  final w0 = 2 * math.pi * math.min(hz, sr * 0.45) / sr;
  final cw = math.cos(w0), sw = math.sin(w0);
  final alpha = sw / (2 * q);
  final a = math.pow(10, gainDb / 40).toDouble();
  double b0, b1, b2, a0, a1, a2;
  switch (type) {
    case _Filter.lowpass:
      b0 = (1 - cw) / 2;
      b1 = 1 - cw;
      b2 = (1 - cw) / 2;
      a0 = 1 + alpha;
      a1 = -2 * cw;
      a2 = 1 - alpha;
    case _Filter.highpass:
      b0 = (1 + cw) / 2;
      b1 = -(1 + cw);
      b2 = (1 + cw) / 2;
      a0 = 1 + alpha;
      a1 = -2 * cw;
      a2 = 1 - alpha;
    case _Filter.bandpass:
      b0 = alpha;
      b1 = 0;
      b2 = -alpha;
      a0 = 1 + alpha;
      a1 = -2 * cw;
      a2 = 1 - alpha;
    case _Filter.peak:
      b0 = 1 + alpha * a;
      b1 = -2 * cw;
      b2 = 1 - alpha * a;
      a0 = 1 + alpha / a;
      a1 = -2 * cw;
      a2 = 1 - alpha / a;
  }
  final out = Float32List(x.length);
  var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0;
  for (var i = 0; i < x.length; i++) {
    final x0 = x[i];
    final y0 = (b0 * x0 + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2) / a0;
    out[i] = y0;
    x2 = x1;
    x1 = x0;
    y2 = y1;
    y1 = y0;
  }
  return out;
}

double _peak(Float32List x) {
  var m = 1e-9;
  for (final v in x) {
    if (v.abs() > m) m = v.abs();
  }
  return m;
}

double _rms(Float32List x) {
  if (x.isEmpty) return 0;
  var s = 0.0;
  for (final v in x) {
    s += v * v;
  }
  return math.sqrt(s / x.length);
}

Float32List _normalize(Float32List x, double peak) {
  var max = 0.0;
  for (final v in x) {
    final a = v.abs();
    if (a.isFinite && a > max) max = a;
  }
  final out = Float32List(x.length);
  final k = max < 1e-6 ? 0.0 : peak / max;
  for (var i = 0; i < x.length; i++) {
    final v = x[i] * k;
    out[i] = v.isFinite ? v.clamp(-1.0, 1.0) : 0;
  }
  return out;
}
