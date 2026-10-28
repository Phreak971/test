/// Picks an installed system TTS voice for each persona so characters differ
/// in gender and accent, not just pitch.
library;

enum VoiceGender { female, male, any }

/// A voice reported by the platform TTS engine.
class SystemVoice {
  const SystemVoice({required this.name, required this.locale, this.gender, this.quality, this.networkRequired = false, this.identifier});

  /// Parses flutter_tts `getVoices` entries (Android, iOS and web shapes).
  static SystemVoice? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final name = raw['name'];
    final locale = raw['locale'];
    if (name is! String || locale is! String || name.isEmpty || locale.isEmpty) return null;
    final g = raw['gender'];
    return SystemVoice(
      name: name,
      locale: locale.replaceAll('_', '-'),
      gender: g is String ? g.toLowerCase() : null,
      quality: raw['quality'] is String ? (raw['quality'] as String).toLowerCase() : null,
      networkRequired: raw['network_required'] == '1' || raw['network_required'] == true,
      identifier: raw['identifier'] is String ? raw['identifier'] as String : null,
    );
  }

  final String name;
  final String locale;
  final String? gender;
  final String? quality;
  final bool networkRequired;
  final String? identifier;

  String get lang => locale.split('-').first.toLowerCase();

  Map<String, String> toSetVoice() => {'name': name, 'locale': locale, 'identifier': ?identifier};

  @override
  String toString() => '$name ($locale)';
}

/// What a persona would like to sound like.
class VoiceWish {
  const VoiceWish({this.gender = VoiceGender.any, this.accents = const [], this.named = const []});

  final VoiceGender gender;

  /// Preferred English locales in order, e.g. `['en-GB', 'en-AU']`.
  final List<String> accents;

  /// Preferred voice names when installed (e.g. Apple's "Grandpa", "Zarvox").
  final List<String> named;
}

/// Apple's novelty voices: only used when a persona names one.
const _novelty = {
  'albert', 'bad news', 'bahh', 'bells', 'boing', 'bubbles', 'cellos', 'good news', 'jester', 'organ', //
  'superstar', 'trinoids', 'whisper', 'wobble', 'zarvox', 'deranged', 'hysterical', 'pipe organ', 'junior', 'ralph', 'kathy', 'princess',
};

/// Google TTS voice codes (`en-gb-x-rjs-local`) whose gender is known.
const _googleGender = <String, VoiceGender>{
  // en-US
  'iob': VoiceGender.female, 'iog': VoiceGender.female, 'iol': VoiceGender.male, 'iom': VoiceGender.male,
  'sfg': VoiceGender.female, 'tpc': VoiceGender.female, 'tpd': VoiceGender.male, 'tpf': VoiceGender.female,
  // en-GB
  'gba': VoiceGender.female, 'gbb': VoiceGender.male, 'gbc': VoiceGender.female, 'gbd': VoiceGender.male,
  'gbg': VoiceGender.female, 'rjs': VoiceGender.male, 'fis': VoiceGender.female,
  // en-AU
  'afh': VoiceGender.female, 'aua': VoiceGender.female, 'aub': VoiceGender.male, 'auc': VoiceGender.female, 'aud': VoiceGender.male,
  // en-IN
  'ahp': VoiceGender.female, 'cxx': VoiceGender.female, 'ene': VoiceGender.female, 'end': VoiceGender.male,
  // de-DE
  'dea': VoiceGender.female, 'deb': VoiceGender.female, 'deg': VoiceGender.male, 'nfh': VoiceGender.female,
  // fr-FR
  'fra': VoiceGender.female, 'frb': VoiceGender.male, 'frc': VoiceGender.female, 'frd': VoiceGender.male, 'vlf': VoiceGender.female,
  // es-ES
  'eea': VoiceGender.female, 'eec': VoiceGender.female, 'eed': VoiceGender.male, 'eee': VoiceGender.female, 'eef': VoiceGender.male,
  'ana': VoiceGender.female,
  // it-IT
  'itb': VoiceGender.female, 'itc': VoiceGender.male, 'itd': VoiceGender.male, 'kda': VoiceGender.female,
  // tr-TR
  'cfs': VoiceGender.female, 'efu': VoiceGender.female, 'mfm': VoiceGender.male, 'ama': VoiceGender.female, 'tmc': VoiceGender.male,
};

/// Common Apple / Microsoft / Samsung voice names by gender.
const _namedMale = {
  'daniel',
  'arthur',
  'aaron',
  'fred',
  'rishi',
  'oliver',
  'gordon',
  'lee',
  'tom',
  'alex',
  'eddy',
  'reed',
  'rocko',
  'grandpa',
  'thomas',
  'nicolas',
  'yannick',
  'markus',
  'martin',
  'jorge',
  'diego',
  'luca',
  'yelda',
  'david',
  'mark',
  'george',
  'james',
  'ryan',
  'guy',
  'ralph',
  'albert',
  'junior',
};
const _namedFemale = {
  'samantha',
  'karen',
  'moira',
  'tessa',
  'serena',
  'kate',
  'martha',
  'catherine',
  'nicky',
  'allison',
  'ava',
  'susan',
  'victoria',
  'zoe',
  'fiona',
  'veena',
  'flo',
  'sandy',
  'shelley',
  'grandma',
  'amelie',
  'audrey',
  'anna',
  'helena',
  'petra',
  'monica',
  'paulina',
  'alice',
  'federica',
  'zira',
  'hazel',
  'aria',
  'jenny',
  'libby',
  'sonia',
  'kathy',
  'princess',
};

VoiceGender? genderOf(SystemVoice v) {
  final g = v.gender;
  if (g != null) {
    if (g.contains('female')) return VoiceGender.female;
    if (g.contains('male')) return VoiceGender.male;
  }
  final n = v.name.toLowerCase();
  final google = RegExp(r'-x-([a-z]{3})(-|$)').firstMatch(n);
  if (google != null) return _googleGender[google.group(1)];
  final samsung = RegExp(r'smt([fm])\d').firstMatch(n);
  if (samsung != null) return samsung.group(1) == 'f' ? VoiceGender.female : VoiceGender.male;
  if (n.contains('female')) return VoiceGender.female;
  if (n.contains('male')) return VoiceGender.male;
  for (final word in n.split(RegExp(r'[^a-z]+'))) {
    if (_namedMale.contains(word)) return VoiceGender.male;
    if (_namedFemale.contains(word)) return VoiceGender.female;
  }
  return null;
}

String _baseName(SystemVoice v) {
  // iOS: "Daniel", "Daniel (Enhanced)"; identifiers carry the same name.
  return v.name.toLowerCase().replaceAll(RegExp(r'\s*\(.*\)'), '').trim();
}

bool _isNovelty(SystemVoice v) => _novelty.contains(_baseName(v)) || (v.identifier?.contains('speech.synthesis.voice') ?? false);

/// Scores [v] for [wish] in [lang]; null when unusable.
double? scoreVoice(SystemVoice v, VoiceWish wish, String lang) {
  if (v.lang != lang) return null;
  final base = _baseName(v);
  final named = wish.named.indexWhere((n) => n.toLowerCase() == base);
  if (_isNovelty(v) && named < 0) return null;
  var s = 0.0;
  if (named >= 0) s += 40 - named * 2;
  if (lang == 'en' && wish.accents.isNotEmpty) {
    final i = wish.accents.indexWhere((a) => a.toLowerCase() == v.locale.toLowerCase());
    s += i < 0 ? 0 : 12 - i * 3;
  }
  final g = genderOf(v);
  if (wish.gender != VoiceGender.any) {
    if (g == wish.gender) {
      s += 10;
    } else if (g != null) {
      s -= 10;
    }
  }
  final q = v.quality ?? '';
  if (q.contains('premium')) s += 3;
  if (q.contains('enhanced') || q.contains('high')) s += 2;
  // Offline voices start instantly and work without signal.
  if (v.networkRequired || v.name.toLowerCase().contains('network')) s -= 4;
  return s;
}

/// Best voice for a persona. [salt] spreads personas with similar wishes
/// across equally good voices so they don't all share one.
SystemVoice? pickVoice(List<SystemVoice> voices, VoiceWish wish, String lang, {int salt = 0}) {
  final scored = <(SystemVoice, double)>[];
  for (final v in voices) {
    final s = scoreVoice(v, wish, lang);
    if (s != null) scored.add((v, s));
  }
  if (scored.isEmpty) return null;
  scored.sort((a, b) {
    final c = b.$2.compareTo(a.$2);
    return c != 0 ? c : a.$1.name.compareTo(b.$1.name);
  });
  final best = scored.first.$2;
  final top = scored.where((e) => e.$2 >= best - 1.5).toList();
  return top[salt.abs() % top.length].$1;
}
