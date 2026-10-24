import 'dart:math' as math;

import '../core/units.dart';
import '../data/models.dart';
import 'navigation_engine.dart';

/// An original voice character. Phrase packs give each persona its own way of
/// speaking; pitch/rate shape the on-device TTS voice.
class VoicePersona {
  const VoicePersona({
    required this.id,
    required this.name,
    required this.tagline,
    required this.pitch,
    required this.rate,
    required this.emoji,
    required this.accent,
    this.isPremium = true,
    this.pack,
  });

  final String id;
  final String name;
  final String tagline;
  final double pitch;
  final double rate;

  /// Avatar glyph drawn on a coloured disc (no likenesses).
  final String emoji;
  final int accent;
  final bool isPremium;

  /// English flavour lines. Null = plain guidance in every language.
  final PhrasePack? pack;
}

/// Templates use {dir} (e.g. "turn left"), {dist} (e.g. "300 meters"),
/// {street} (may be empty; templates that need it have a fallback).
class PhrasePack {
  const PhrasePack({
    required this.prepare,
    required this.approach,
    required this.now,
    required this.arrive,
    required this.reroute,
    required this.sample,
  });

  final List<String> prepare;
  final List<String> approach;
  final List<String> now;
  final List<String> arrive;
  final List<String> reroute;
  final String sample;
}

const voicePersonas = <VoicePersona>[
  VoicePersona(
    id: 'classic',
    name: 'Navigator',
    tagline: 'Clear, calm directions',
    pitch: 1.0,
    rate: 0.5,
    emoji: '🧭',
    accent: 0xFF3D7BFF,
    isPremium: false,
  ),
  VoicePersona(
    id: 'getaway',
    name: 'Getaway Driver',
    tagline: 'Keeps it cool under pressure',
    pitch: 0.85,
    rate: 0.55,
    emoji: '🕶️',
    accent: 0xFF00C2A8,
    pack: PhrasePack(
      prepare: ['Stay cool. {dist} out, we {dir}.', 'Easy does it. In {dist}, {dir}.'],
      approach: ['Heads up, {dir} in {dist}.', 'Get ready, {dir} coming up in {dist}.'],
      now: ['Now! {dir}!', 'Hit it, {dir} right here.'],
      arrive: ['We made it. Clean getaway.', 'Destination reached. Nobody saw a thing.'],
      reroute: ['Change of plans. Finding another way out.'],
      sample: 'Stay cool. Three hundred meters out, we take a left.',
    ),
  ),
  VoicePersona(
    id: 'ranger',
    name: 'Frontier Ranger',
    tagline: 'Dusty trails, steady hands',
    pitch: 0.75,
    rate: 0.42,
    emoji: '🤠',
    accent: 0xFFC9853B,
    pack: PhrasePack(
      prepare: ['Keep ridin\' partner. In {dist}, {dir}.', 'Long trail ahead. {dist}, then {dir}.'],
      approach: ['Whoa there. {dir} in {dist}.', 'Mind the trail, {dir} in {dist}.'],
      now: ['{dir} right here, partner.', 'Pull the reins, {dir} now.'],
      arrive: ['End of the trail. We\'re here.', 'Hitch your horse, we\'ve arrived.'],
      reroute: ['Lost the trail. Scoutin\' a new path.'],
      sample: 'Whoa there, partner. Take a left up ahead.',
    ),
  ),
  VoicePersona(
    id: 'builder',
    name: 'Block Builder',
    tagline: 'Every road is a crafting recipe',
    pitch: 1.25,
    rate: 0.52,
    emoji: '🧱',
    accent: 0xFF6BBF3A,
    pack: PhrasePack(
      prepare: ['Mining ahead for {dist}, then {dir}.', 'Path crafted! In {dist}, {dir}.'],
      approach: ['Block break incoming. {dir} in {dist}.', '{dir} in {dist}. Don\'t fall in the lava.'],
      now: ['{dir}! Now now now!', 'Place your block. {dir}!'],
      arrive: ['Achievement unlocked: You have arrived!', 'Spawn point reached.'],
      reroute: ['Oops, wrong biome. Re-crafting the path.'],
      sample: 'Achievement unlocked! Take a left in three hundred blocks.',
    ),
  ),
  VoicePersona(
    id: 'herald',
    name: 'Royal Herald',
    tagline: 'Announces every turn with fanfare',
    pitch: 1.05,
    rate: 0.44,
    emoji: '👑',
    accent: 0xFFB38B2D,
    pack: PhrasePack(
      prepare: ['Hear ye! In {dist}, thou shalt {dir}.', 'The road continues for {dist}. Then, {dir}.'],
      approach: ['By royal decree, {dir} in {dist}.', 'Prepare thyself. {dir} in {dist}.'],
      now: ['{dir}, noble traveller!', 'Now, {dir}!'],
      arrive: ['The quest is complete. Thou hast arrived.', 'Behold, thy destination!'],
      reroute: ['The path is lost! I shall chart another.'],
      sample: 'Hear ye, hear ye! In three hundred meters, thou shalt turn left.',
    ),
  ),
  VoicePersona(
    id: 'shipai',
    name: 'Ship AI',
    tagline: 'Precise. Synthetic. Slightly smug.',
    pitch: 1.35,
    rate: 0.5,
    emoji: '🤖',
    accent: 0xFF19E3FF,
    pack: PhrasePack(
      prepare: ['Trajectory locked. {dir} in {dist}.', 'Cruising. Next vector change in {dist}: {dir}.'],
      approach: ['Course correction in {dist}. {dir}.', 'Alert. {dir} in {dist}.'],
      now: ['Execute: {dir}.', '{dir}. Now.'],
      arrive: ['Docking complete. You have arrived.', 'Destination achieved. Efficiency: acceptable.'],
      reroute: ['Deviation detected. Recalculating trajectory.'],
      sample: 'Course correction in three hundred meters. Turn left.',
    ),
  ),
  VoicePersona(
    id: 'sergeant',
    name: 'Drill Sergeant',
    tagline: 'No slacking at intersections',
    pitch: 0.8,
    rate: 0.6,
    emoji: '🎖️',
    accent: 0xFF7A8B3E,
    pack: PhrasePack(
      prepare: ['Eyes forward! {dist}, then {dir}!', 'March on for {dist}, then {dir}!'],
      approach: ['Look sharp! {dir} in {dist}!', 'On my mark, {dir} in {dist}!'],
      now: ['{dir}! Move move move!', 'Now, soldier! {dir}!'],
      arrive: ['Objective secured! At ease.', 'Mission complete, soldier.'],
      reroute: ['Off course! Regroup, new route incoming!'],
      sample: 'Look sharp, soldier! Turn left in three hundred meters!',
    ),
  ),
  VoicePersona(
    id: 'captain',
    name: 'Sky Captain',
    tagline: 'Charts the seas and the streets',
    pitch: 0.9,
    rate: 0.46,
    emoji: '🏴‍☠️',
    accent: 0xFF2F5D8A,
    pack: PhrasePack(
      prepare: ['Steady as she goes. {dist}, then {dir}.', 'Full sail for {dist}, then {dir}.'],
      approach: ['Land ho! {dir} in {dist}.', 'Hard about soon. {dir} in {dist}.'],
      now: ['{dir}, ye landlubber!', 'Now! {dir}!'],
      arrive: ['Drop anchor, we be here!', 'Treasure found. Ye have arrived.'],
      reroute: ['Blown off course! Plotting a new heading.'],
      sample: 'Land ho! Take a left in three hundred meters.',
    ),
  ),
];

VoicePersona personaById(String? id) => voicePersonas.firstWhere((p) => p.id == id, orElse: () => voicePersonas.first);

/// Plain guidance phrases for each supported language.
class _Lang {
  const _Lang({
    required this.dirs,
    required this.roundabout,
    required this.inDist,
    required this.continueFor,
    required this.now,
    required this.arrive,
    required this.reroute,
    required this.onto,
    required this.units,
  });

  final Map<ManeuverKind, String> dirs;
  final String Function(int? exit) roundabout;
  final String inDist; // "In {dist}, {dir}"
  final String continueFor; // "Continue for {dist}, then {dir}"
  final String now; // "{dir}"
  final String arrive;
  final String reroute;
  final String onto; // " onto {street}"
  final Map<String, String> units; // m, km, ft, mi spoken
}

String _ord(int n) {
  const words = {
    1: 'first',
    2: 'second',
    3: 'third',
    4: 'fourth',
    5: 'fifth',
    6: 'sixth',
    7: 'seventh',
    8: 'eighth',
    9: 'ninth',
    10: 'tenth',
  };
  final w = words[n];
  if (w != null) return w;
  final teen = n % 100 >= 11 && n % 100 <= 13;
  final suffix = teen
      ? 'th'
      : switch (n % 10) {
          1 => 'st',
          2 => 'nd',
          3 => 'rd',
          _ => 'th',
        };
  return '$n$suffix';
}

final _langs = <String, _Lang>{
  'en': _Lang(
    dirs: {
      ManeuverKind.depart: 'head out',
      ManeuverKind.straight: 'continue straight',
      ManeuverKind.slightLeft: 'bear left',
      ManeuverKind.left: 'turn left',
      ManeuverKind.sharpLeft: 'make a sharp left',
      ManeuverKind.slightRight: 'bear right',
      ManeuverKind.right: 'turn right',
      ManeuverKind.sharpRight: 'make a sharp right',
      ManeuverKind.uturn: 'make a U-turn',
      ManeuverKind.merge: 'merge',
      ManeuverKind.fork: 'keep at the fork',
      ManeuverKind.rampLeft: 'take the ramp on the left',
      ManeuverKind.rampRight: 'take the ramp on the right',
      ManeuverKind.arrive: 'arrive',
    },
    roundabout: (e) => e == null ? 'take the roundabout' : 'at the roundabout, take the ${_ord(e)} exit',
    inDist: 'In {dist}, {dir}',
    continueFor: 'Continue for {dist}, then {dir}',
    now: '{dir}',
    arrive: 'You have arrived at your destination',
    reroute: 'Rerouting',
    onto: ' onto {street}',
    units: {'m': 'meters', 'km': 'kilometers', 'ft': 'feet', 'mi': 'miles'},
  ),
  'de': _Lang(
    dirs: {
      ManeuverKind.depart: 'losfahren',
      ManeuverKind.straight: 'geradeaus weiterfahren',
      ManeuverKind.slightLeft: 'leicht links halten',
      ManeuverKind.left: 'links abbiegen',
      ManeuverKind.sharpLeft: 'scharf links abbiegen',
      ManeuverKind.slightRight: 'leicht rechts halten',
      ManeuverKind.right: 'rechts abbiegen',
      ManeuverKind.sharpRight: 'scharf rechts abbiegen',
      ManeuverKind.uturn: 'wenden',
      ManeuverKind.merge: 'einfädeln',
      ManeuverKind.fork: 'an der Gabelung halten',
      ManeuverKind.rampLeft: 'die Ausfahrt links nehmen',
      ManeuverKind.rampRight: 'die Ausfahrt rechts nehmen',
      ManeuverKind.arrive: 'ankommen',
    },
    roundabout: (e) => e == null ? 'in den Kreisverkehr fahren' : 'im Kreisverkehr die $e. Ausfahrt nehmen',
    inDist: 'In {dist} {dir}',
    continueFor: '{distNom} weiterfahren, dann {dir}',
    now: 'Jetzt {dir}',
    arrive: 'Sie haben Ihr Ziel erreicht',
    reroute: 'Route wird neu berechnet',
    onto: ' auf {street}',
    units: {'m': 'Metern', 'km': 'Kilometern', 'ft': 'Fuß', 'mi': 'Meilen'},
  ),
  'fr': _Lang(
    dirs: {
      ManeuverKind.depart: 'partez',
      ManeuverKind.straight: 'continuez tout droit',
      ManeuverKind.slightLeft: 'serrez à gauche',
      ManeuverKind.left: 'tournez à gauche',
      ManeuverKind.sharpLeft: 'tournez franchement à gauche',
      ManeuverKind.slightRight: 'serrez à droite',
      ManeuverKind.right: 'tournez à droite',
      ManeuverKind.sharpRight: 'tournez franchement à droite',
      ManeuverKind.uturn: 'faites demi-tour',
      ManeuverKind.merge: 'insérez-vous',
      ManeuverKind.fork: 'restez sur la bifurcation',
      ManeuverKind.rampLeft: 'prenez la bretelle à gauche',
      ManeuverKind.rampRight: 'prenez la bretelle à droite',
      ManeuverKind.arrive: 'arrivez',
    },
    roundabout: (e) => e == null ? 'prenez le rond-point' : 'au rond-point, prenez la ${e == 1 ? '1re' : '${e}e'} sortie',
    inDist: 'Dans {dist}, {dir}',
    continueFor: 'Continuez sur {dist}, puis {dir}',
    now: '{dir} maintenant',
    arrive: 'Vous êtes arrivé à destination',
    reroute: 'Recalcul de l\'itinéraire',
    onto: ' sur {street}',
    units: {'m': 'mètres', 'km': 'kilomètres', 'ft': 'pieds', 'mi': 'miles'},
  ),
  'es': _Lang(
    dirs: {
      ManeuverKind.depart: 'sal',
      ManeuverKind.straight: 'sigue recto',
      ManeuverKind.slightLeft: 'mantente a la izquierda',
      ManeuverKind.left: 'gira a la izquierda',
      ManeuverKind.sharpLeft: 'gira bruscamente a la izquierda',
      ManeuverKind.slightRight: 'mantente a la derecha',
      ManeuverKind.right: 'gira a la derecha',
      ManeuverKind.sharpRight: 'gira bruscamente a la derecha',
      ManeuverKind.uturn: 'cambia de sentido',
      ManeuverKind.merge: 'incorpórate',
      ManeuverKind.fork: 'mantente en la bifurcación',
      ManeuverKind.rampLeft: 'toma la salida a la izquierda',
      ManeuverKind.rampRight: 'toma la salida a la derecha',
      ManeuverKind.arrive: 'llega',
    },
    roundabout: (e) => e == null ? 'entra en la rotonda' : 'en la rotonda, toma la salida $e',
    inDist: 'En {dist}, {dir}',
    continueFor: 'Continúa {dist} y luego {dir}',
    now: '{dir} ahora',
    arrive: 'Has llegado a tu destino',
    reroute: 'Recalculando la ruta',
    onto: ' hacia {street}',
    units: {'m': 'metros', 'km': 'kilómetros', 'ft': 'pies', 'mi': 'millas'},
  ),
  'it': _Lang(
    dirs: {
      ManeuverKind.depart: 'parti',
      ManeuverKind.straight: 'prosegui dritto',
      ManeuverKind.slightLeft: 'tieni la sinistra',
      ManeuverKind.left: 'svolta a sinistra',
      ManeuverKind.sharpLeft: 'svolta decisamente a sinistra',
      ManeuverKind.slightRight: 'tieni la destra',
      ManeuverKind.right: 'svolta a destra',
      ManeuverKind.sharpRight: 'svolta decisamente a destra',
      ManeuverKind.uturn: 'fai inversione',
      ManeuverKind.merge: 'immettiti',
      ManeuverKind.fork: 'tieniti al bivio',
      ManeuverKind.rampLeft: 'prendi la rampa a sinistra',
      ManeuverKind.rampRight: 'prendi la rampa a destra',
      ManeuverKind.arrive: 'arriva',
    },
    roundabout: (e) => e == null ? 'entra nella rotonda' : 'alla rotonda, prendi la uscita numero $e',
    inDist: 'Tra {dist}, {dir}',
    continueFor: 'Prosegui per {dist}, poi {dir}',
    now: 'Ora {dir}',
    arrive: 'Sei arrivato a destinazione',
    reroute: 'Ricalcolo del percorso',
    onto: ' su {street}',
    units: {'m': 'metri', 'km': 'chilometri', 'ft': 'piedi', 'mi': 'miglia'},
  ),
  'tr': _Lang(
    dirs: {
      ManeuverKind.depart: 'yola çıkın',
      ManeuverKind.straight: 'düz devam edin',
      ManeuverKind.slightLeft: 'hafif sola yönelin',
      ManeuverKind.left: 'sola dönün',
      ManeuverKind.sharpLeft: 'keskin sola dönün',
      ManeuverKind.slightRight: 'hafif sağa yönelin',
      ManeuverKind.right: 'sağa dönün',
      ManeuverKind.sharpRight: 'keskin sağa dönün',
      ManeuverKind.uturn: 'U dönüşü yapın',
      ManeuverKind.merge: 'yola katılın',
      ManeuverKind.fork: 'yol ayrımında devam edin',
      ManeuverKind.rampLeft: 'soldaki rampayı kullanın',
      ManeuverKind.rampRight: 'sağdaki rampayı kullanın',
      ManeuverKind.arrive: 'varın',
    },
    roundabout: (e) => e == null ? 'döner kavşağa girin' : 'döner kavşaktan $e. çıkışı kullanın',
    inDist: '{dist} sonra {dir}',
    continueFor: '{dist} devam edin, ardından {dir}',
    now: 'Şimdi {dir}',
    arrive: 'Varış noktanıza ulaştınız',
    reroute: 'Rota yeniden hesaplanıyor',
    onto: ', {street} yönüne',
    units: {'m': 'metre', 'km': 'kilometre', 'ft': 'fit', 'mi': 'mil'},
  ),
};

/// Unit words where a template needs a different grammatical case
/// (German: "In 300 Metern" but "300 Meter weiterfahren").
const _nominativeUnits = {
  'de': {'m': 'Meter', 'km': 'Kilometer', 'ft': 'Fuß', 'mi': 'Meilen'},
};

String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Builds the sentence spoken for [cue].
String phraseFor(VoiceCue cue, VoicePersona persona, DistanceUnit unit, String langCode, {int seed = 0}) {
  final lang = _langs[langCode] ?? _langs['en']!;
  final step = cue.step;
  var dir = step.kind == ManeuverKind.roundabout
      ? lang.roundabout(step.roundaboutExit)
      : (lang.dirs[step.kind] ?? lang.dirs[ManeuverKind.straight]!);
  final parts = formatDistanceParts(cue.distanceM, unit);
  // Spoken numbers use the language's decimal separator.
  final value = langCode == 'en' ? parts.value : parts.value.replaceAll('.', ',');
  final dist = '$value ${lang.units[parts.unit] ?? parts.unit}';
  final distNom = '$value ${_nominativeUnits[langCode]?[parts.unit] ?? lang.units[parts.unit] ?? parts.unit}';
  final pack = langCode == 'en' ? persona.pack : null;
  final rnd = math.Random(seed + cue.stepIndex * 7 + cue.stage.index);
  String pick(List<String> xs) => xs[rnd.nextInt(xs.length)];

  if (cue.stage == CueStage.arrive) {
    return pack != null ? pick(pack.arrive) : lang.arrive;
  }
  if (pack == null && step.streetName.isNotEmpty && cue.stage != CueStage.prepare) {
    dir += lang.onto.replaceAll('{street}', step.streetName);
  }
  final template = switch (cue.stage) {
    CueStage.prepare => pack != null ? pick(pack.prepare) : lang.continueFor,
    CueStage.approach => pack != null ? pick(pack.approach) : lang.inDist,
    CueStage.now => pack != null ? pick(pack.now) : lang.now,
    CueStage.arrive => lang.arrive,
  };
  return _capitalize(template.replaceAll('{dir}', dir).replaceAll('{distNom}', distNom).replaceAll('{dist}', dist));
}

String reroutePhrase(VoicePersona persona, String langCode) {
  final pack = langCode == 'en' ? persona.pack : null;
  return pack?.reroute.first ?? (_langs[langCode] ?? _langs['en']!).reroute;
}

String samplePhrase(VoicePersona persona, String langCode) {
  if (langCode == 'en' && persona.pack != null) return persona.pack!.sample;
  final lang = _langs[langCode] ?? _langs['en']!;
  return _capitalize(lang.inDist.replaceAll('{dist}', '300 ${lang.units['m']}').replaceAll('{dir}', lang.dirs[ManeuverKind.left]!));
}
