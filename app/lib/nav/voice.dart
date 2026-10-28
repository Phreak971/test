import 'dart:math' as math;

import '../core/units.dart';
import '../data/models.dart';
import 'navigation_engine.dart';
import 'voice_fx.dart';
import 'voice_select.dart';

/// An original voice character. Phrase packs give each persona its own way of
/// speaking; [wish] picks a matching system voice, pitch/rate shape it and
/// [fx] post-processes it.
class VoicePersona {
  const VoicePersona({
    required this.id,
    required this.name,
    required this.tagline,
    required this.pitch,
    required this.rate,
    required this.emoji,
    required this.accent,
    this.wish = const VoiceWish(),
    this.fx = VoiceFx.none,
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
  final VoiceWish wish;
  final VoiceFx fx;

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
    wish: VoiceWish(gender: VoiceGender.female, accents: ['en-US', 'en-GB']),
  ),
  VoicePersona(
    id: 'getaway',
    name: 'Getaway Driver',
    tagline: 'Keeps it cool under pressure',
    pitch: 0.82,
    rate: 0.6,
    emoji: '🕶️',
    accent: 0xFF00C2A8,
    wish: VoiceWish(gender: VoiceGender.male, accents: ['en-US'], named: ['Reed', 'Aaron']),
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
    pitch: 0.7,
    rate: 0.4,
    emoji: '🤠',
    accent: 0xFFC9853B,
    wish: VoiceWish(gender: VoiceGender.male, accents: ['en-US', 'en-AU'], named: ['Rocko', 'Fred']),
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
    pitch: 1.4,
    rate: 0.56,
    emoji: '🧱',
    accent: 0xFF6BBF3A,
    wish: VoiceWish(gender: VoiceGender.male, accents: ['en-US', 'en-AU'], named: ['Junior', 'Eddy']),
    fx: VoiceFx.bitcrush,
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
    wish: VoiceWish(gender: VoiceGender.male, accents: ['en-GB', 'en-IE'], named: ['Arthur', 'Daniel']),
    fx: VoiceFx.hall,
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
    pitch: 1.12,
    rate: 0.5,
    emoji: '🛰️',
    accent: 0xFF19E3FF,
    wish: VoiceWish(gender: VoiceGender.female, accents: ['en-US', 'en-AU'], named: ['Trinoids', 'Zarvox']),
    fx: VoiceFx.robot,
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
    pitch: 0.78,
    rate: 0.64,
    emoji: '🎖️',
    accent: 0xFF7A8B3E,
    wish: VoiceWish(gender: VoiceGender.male, accents: ['en-US'], named: ['Ralph', 'Tom']),
    fx: VoiceFx.radio,
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
    pitch: 0.84,
    rate: 0.47,
    emoji: '🏴‍☠️',
    accent: 0xFF2F5D8A,
    wish: VoiceWish(gender: VoiceGender.male, accents: ['en-AU', 'en-GB', 'en-IE'], named: ['Lee', 'Gordon']),
    pack: PhrasePack(
      prepare: ['Steady as she goes. {dist}, then {dir}.', 'Full sail for {dist}, then {dir}.'],
      approach: ['Land ho! {dir} in {dist}.', 'Hard about soon. {dir} in {dist}.'],
      now: ['{dir}, ye landlubber!', 'Now! {dir}!'],
      arrive: ['Drop anchor, we be here!', 'Treasure found. Ye have arrived.'],
      reroute: ['Blown off course! Plotting a new heading.'],
      sample: 'Land ho! Take a left in three hundred meters.',
    ),
  ),

  // Space opera and high fantasy archetypes. Original characters: no names,
  // catchphrases or likenesses from any film or book.
  VoicePersona(
    id: 'darklord',
    name: 'Dark Lord',
    tagline: 'Commands the empire\'s roads. Breathes heavily.',
    pitch: 0.55,
    rate: 0.38,
    emoji: '🌑',
    accent: 0xFFD32F2F,
    wish: VoiceWish(gender: VoiceGender.male, accents: ['en-US', 'en-GB'], named: ['Rocko', 'Grandpa', 'Ralph']),
    fx: VoiceFx.darkHelmet,
    pack: PhrasePack(
      prepare: ['The road ahead is long. In {dist}, you will {dir}.', 'Continue for {dist}. Then {dir}. It is inevitable.'],
      approach: ['In {dist}, {dir}. Do not hesitate.', 'Prepare to {dir} in {dist}.'],
      now: ['{dir}. Now.', '{dir}. Do not fail me.'],
      arrive: ['You have arrived. Exactly as I planned.', 'The journey is complete. Impressive.'],
      reroute: ['You have strayed from the path. A new course is being set.'],
      sample: 'In three hundred meters, you will turn left. Do not fail me.',
    ),
  ),
  VoicePersona(
    id: 'starknight',
    name: 'Star Knight',
    tagline: 'A calm mentor who trusts your instincts',
    pitch: 0.86,
    rate: 0.43,
    emoji: '✨',
    accent: 0xFF42A5F5,
    wish: VoiceWish(gender: VoiceGender.male, accents: ['en-GB', 'en-IE', 'en-AU'], named: ['Daniel', 'Arthur', 'Oliver']),
    fx: VoiceFx.comms,
    pack: PhrasePack(
      prepare: ['Trust your instincts. In {dist}, {dir}.', 'Be patient. {dist}, then {dir}.'],
      approach: ['Stay focused. {dir} in {dist}.', 'Feel the road. {dir} in {dist}.'],
      now: ['{dir}, now.', 'Now. {dir}.'],
      arrive: ['You have arrived. You were ready all along.', 'Well done, young pilot. We are here.'],
      reroute: ['Let go of the old path. A new one reveals itself.'],
      sample: 'Stay focused, young pilot. In three hundred meters, turn left.',
    ),
  ),
  VoicePersona(
    id: 'swampsage',
    name: 'Swamp Sage',
    tagline: 'Ancient, tiny, speaks backwards',
    pitch: 1.6,
    rate: 0.36,
    emoji: '🌿',
    accent: 0xFF7CB342,
    wish: VoiceWish(gender: VoiceGender.male, accents: ['en-US', 'en-GB'], named: ['Grandpa', 'Albert']),
    fx: VoiceFx.cave,
    pack: PhrasePack(
      prepare: ['In {dist}, {dir} you will.', 'Far the road is. {dist}, then {dir}.'],
      approach: ['{dir} in {dist}, you must.', 'Close, the turn is. {dir} in {dist}.'],
      now: ['{dir}, now you must!', 'Now. {dir}, hmm.'],
      arrive: ['Arrived, you have. Hmm.', 'Here we are. Rest now, you may.'],
      reroute: ['Lost the path, we have. Find another, I will.'],
      sample: 'Turn left in three hundred meters, you must. Hmm.',
    ),
  ),
  VoicePersona(
    id: 'protodroid',
    name: 'Protocol Droid',
    tagline: 'Fluent in six million road signs. Worried.',
    pitch: 1.32,
    rate: 0.56,
    emoji: '🤖',
    accent: 0xFFFFC107,
    wish: VoiceWish(gender: VoiceGender.male, accents: ['en-GB', 'en-IE'], named: ['Daniel', 'Arthur']),
    fx: VoiceFx.droid,
    pack: PhrasePack(
      prepare: ['Oh my. In {dist}, we must {dir}.', 'Do drive carefully. {dist}, then {dir}.'],
      approach: ['Goodness! {dir} in {dist}.', 'The odds favour turning. {dir} in {dist}.'],
      now: ['{dir}! Oh, do hurry!', '{dir} now, if you please!'],
      arrive: ['Oh, thank goodness, we have arrived!', 'We have arrived. I knew we would. Mostly.'],
      reroute: ['Oh dear, we are off course! Recalculating at once.'],
      sample: 'Oh my! In three hundred meters, we must turn left.',
    ),
  ),
  VoicePersona(
    id: 'smuggler',
    name: 'Space Smuggler',
    tagline: 'Fastest ride in the sector. Mostly in one piece.',
    pitch: 0.92,
    rate: 0.6,
    emoji: '🚀',
    accent: 0xFFFF7043,
    wish: VoiceWish(gender: VoiceGender.male, accents: ['en-US'], named: ['Aaron', 'Reed']),
    pack: PhrasePack(
      prepare: ['Relax, I got this. {dist}, then {dir}.', 'Smooth flying for {dist}, then we {dir}.'],
      approach: ['Hang on. {dir} in {dist}.', 'Coming in hot, {dir} in {dist}.'],
      now: ['{dir}! Punch it!', 'Now, kid! {dir}!'],
      arrive: ['Told you she could make it. We\'re here.', 'Landed. Don\'t mention the scratches.'],
      reroute: ['Okay, new plan. I know a shortcut.'],
      sample: 'Hang on, kid. Three hundred meters, then we take a left.',
    ),
  ),
  VoicePersona(
    id: 'bountyhunter',
    name: 'Bounty Hunter',
    tagline: 'Few words. Never misses a turn.',
    pitch: 0.72,
    rate: 0.44,
    emoji: '🎯',
    accent: 0xFF8D9AA5,
    wish: VoiceWish(gender: VoiceGender.male, accents: ['en-US', 'en-AU'], named: ['Ralph', 'Rocko']),
    fx: VoiceFx.helmet,
    pack: PhrasePack(
      prepare: ['Target ahead. {dist}. Then {dir}.', '{dist}. Then {dir}.'],
      approach: ['{dir} in {dist}.', 'Tracking. {dir} in {dist}.'],
      now: ['{dir}.', 'Now. {dir}.'],
      arrive: ['Target reached.', 'We\'re here. Job done.'],
      reroute: ['Trail went cold. Tracking a new one.'],
      sample: 'Tracking. Turn left in three hundred meters.',
    ),
  ),
  VoicePersona(
    id: 'greywizard',
    name: 'Grey Wizard',
    tagline: 'Old, wise, and fond of long journeys',
    pitch: 0.68,
    rate: 0.4,
    emoji: '🧙',
    accent: 0xFF9E9E9E,
    wish: VoiceWish(gender: VoiceGender.male, accents: ['en-GB', 'en-IE'], named: ['Grandpa', 'Daniel', 'Arthur']),
    fx: VoiceFx.hall,
    pack: PhrasePack(
      prepare: ['Patience, traveller. In {dist}, {dir}.', 'The road winds on. {dist}, then {dir}.'],
      approach: ['Mark my words. {dir} in {dist}.', 'Heed me now. {dir} in {dist}.'],
      now: ['{dir}, and do not tarry!', '{dir}! Now!'],
      arrive: ['Your journey ends here, at last.', 'We have arrived, and not a moment late.'],
      reroute: ['We have wandered from the path. Let me find another way.'],
      sample: 'Patience, traveller. In three hundred meters, turn left, and do not tarry.',
    ),
  ),
  VoicePersona(
    id: 'elvenqueen',
    name: 'Elven Queen',
    tagline: 'Speaks from the silver woods',
    pitch: 1.1,
    rate: 0.4,
    emoji: '🧝',
    accent: 0xFFB2DFDB,
    wish: VoiceWish(gender: VoiceGender.female, accents: ['en-GB', 'en-IE', 'en-AU'], named: ['Kate', 'Serena', 'Moira']),
    fx: VoiceFx.ethereal,
    pack: PhrasePack(
      prepare: ['The road is long. In {dist}, {dir}.', 'Walk on beneath the stars. {dist}, then {dir}.'],
      approach: ['The way turns soon. {dir} in {dist}.', 'Listen. {dir} in {dist}.'],
      now: ['{dir}, now.', 'Here. {dir}.'],
      arrive: ['You have come, at last, to your journey\'s end.', 'Rest now. You have arrived.'],
      reroute: ['The path has shifted. Even so, a new way opens.'],
      sample: 'The road is long. In three hundred meters, turn left.',
    ),
  ),
  VoicePersona(
    id: 'dwarflord',
    name: 'Dwarf Lord',
    tagline: 'Gruff, loud, hates long detours',
    pitch: 0.62,
    rate: 0.56,
    emoji: '⛏️',
    accent: 0xFF8D6E63,
    wish: VoiceWish(gender: VoiceGender.male, accents: ['en-GB', 'en-IE', 'en-AU'], named: ['Gordon', 'Lee', 'Rocko']),
    fx: VoiceFx.cave,
    pack: PhrasePack(
      prepare: ['Keep marching, lad. {dist}, then {dir}.', 'Stone and road for {dist}. Then {dir}.'],
      approach: ['Ready your axe! {dir} in {dist}.', 'Oi! {dir} in {dist}.'],
      now: ['{dir}! By my beard, now!', 'Now, lad! {dir}!'],
      arrive: ['We\'re here! Fetch the ale!', 'Arrived, and not a moment too soon.'],
      reroute: ['Bah! Wrong tunnel. Digging a new route.'],
      sample: 'Oi! Turn left in three hundred meters, lad!',
    ),
  ),
  VoicePersona(
    id: 'halfling',
    name: 'Hillside Halfling',
    tagline: 'Cheerful, curious, always hungry',
    pitch: 1.3,
    rate: 0.5,
    emoji: '🍄',
    accent: 0xFF66BB6A,
    wish: VoiceWish(gender: VoiceGender.male, accents: ['en-GB', 'en-IE'], named: ['Oliver', 'Eddy']),
    pack: PhrasePack(
      prepare: ['What an adventure! In {dist}, {dir}.', 'A pleasant stroll for {dist}, then {dir}.'],
      approach: ['Ooh, {dir} in {dist}.', 'Nearly there! {dir} in {dist}.'],
      now: ['{dir}, right here!', 'Quick, {dir}!'],
      arrive: ['We made it! Time for second breakfast.', 'What a journey! And here we are!'],
      reroute: ['Oops, took a wrong turn at the mushrooms. New path!'],
      sample: 'What an adventure! In three hundred meters, turn left.',
    ),
  ),
  VoicePersona(
    id: 'archmage',
    name: 'Archmage Headmistress',
    tagline: 'Stern, brilliant, docks points for wrong turns',
    pitch: 0.94,
    rate: 0.46,
    emoji: '🪄',
    accent: 0xFF7E57C2,
    wish: VoiceWish(gender: VoiceGender.female, accents: ['en-GB', 'en-IE'], named: ['Grandma', 'Kate', 'Serena']),
    fx: VoiceFx.hall,
    pack: PhrasePack(
      prepare: ['Pay attention. In {dist}, {dir}.', 'Continue for {dist}, then {dir}. No dawdling.'],
      approach: ['{dir} in {dist}. I shan\'t repeat myself.', 'Wands ready. {dir} in {dist}.'],
      now: ['{dir}. Now, please.', '{dir}! Promptly!'],
      arrive: ['You have arrived. Ten points to you.', 'Destination reached. Adequate work.'],
      reroute: ['Five points off. Charting a new course.'],
      sample: 'Pay attention. In three hundred meters, turn left. I shan\'t repeat myself.',
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
