// Localised display text for catalog content (themes, voices, icons).
// Keeps ids stable in code while user-facing strings come from ARB files.

import '../data/models.dart';
import 'app_localizations.dart';

String themeTagline(L l, String id) => switch (id) {
  'palm_metro' => l.themeTaglinePalmMetro,
  'battle_isle' => l.themeTaglineBattleIsle,
  'desert_state' => l.themeTaglineDesertState,
  'frontier' => l.themeTaglineFrontier,
  'neon_sprawl' => l.themeTaglineNeonSprawl,
  'blockland' => l.themeTaglineBlockland,
  'wasteland' => l.themeTaglineWasteland,
  'ashen_realm' => l.themeTaglineAshenRealm,
  'northern_saga' => l.themeTaglineNorthernSaga,
  'hunters_chart' => l.themeTaglineHuntersChart,
  'tactical_ops' => l.themeTaglineTacticalOps,
  'rune_stone' => l.themeTaglineRuneStone,
  'shadow_parchment' => l.themeTaglineShadowParchment,
  'street_racer' => l.themeTaglineStreetRacer,
  'overgrown' => l.themeTaglineOvergrown,
  _ => '',
};

String themeGenre(L l, String id) => switch (id) {
  'palm_metro' => l.themeGenrePalmMetro,
  'battle_isle' => l.themeGenreBattleIsle,
  'desert_state' => l.themeGenreDesertState,
  'frontier' => l.themeGenreFrontier,
  'neon_sprawl' => l.themeGenreNeonSprawl,
  'blockland' => l.themeGenreBlockland,
  'wasteland' => l.themeGenreWasteland,
  'ashen_realm' => l.themeGenreAshenRealm,
  'northern_saga' => l.themeGenreNorthernSaga,
  'hunters_chart' => l.themeGenreHuntersChart,
  'tactical_ops' => l.themeGenreTacticalOps,
  'rune_stone' => l.themeGenreRuneStone,
  'shadow_parchment' => l.themeGenreShadowParchment,
  'street_racer' => l.themeGenreStreetRacer,
  'overgrown' => l.themeGenreOvergrown,
  _ => '',
};

String voiceTagline(L l, String id) => switch (id) {
  'classic' => l.voiceTaglineClassic,
  'getaway' => l.voiceTaglineGetaway,
  'ranger' => l.voiceTaglineRanger,
  'builder' => l.voiceTaglineBuilder,
  'herald' => l.voiceTaglineHerald,
  'shipai' => l.voiceTaglineShipai,
  'sergeant' => l.voiceTaglineSergeant,
  'captain' => l.voiceTaglineCaptain,
  _ => '',
};

String placeIconLabel(L l, PlaceIcon i) => switch (i) {
  PlaceIcon.star => l.placeIconStar,
  PlaceIcon.home => l.placeIconHome,
  PlaceIcon.work => l.placeIconWork,
  PlaceIcon.food => l.placeIconFood,
  PlaceIcon.coffee => l.placeIconCoffee,
  PlaceIcon.bar => l.placeIconBar,
  PlaceIcon.shop => l.placeIconShop,
  PlaceIcon.gym => l.placeIconGym,
  PlaceIcon.heart => l.placeIconHeart,
  PlaceIcon.flag => l.placeIconFlag,
  PlaceIcon.car => l.placeIconCar,
  PlaceIcon.school => l.placeIconSchool,
};
