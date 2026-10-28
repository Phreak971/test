// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class LEn extends L {
  LEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Overworld';

  @override
  String get tagline => 'Your world, game-styled.';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Cancel';

  @override
  String get close => 'Close';

  @override
  String get done => 'Done';

  @override
  String get save => 'Save';

  @override
  String get saveChanges => 'Save changes';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get retry => 'Try again';

  @override
  String get next => 'Next';

  @override
  String get skip => 'Skip';

  @override
  String get continueLabel => 'Continue';

  @override
  String get loading => 'Loading…';

  @override
  String get unknownLocation => 'Unknown location';

  @override
  String get somethingWrong => 'Something went wrong';

  @override
  String get obGetStartedTitle => 'Turn your city into a game map';

  @override
  String get obGetStartedBody => 'Pick a world, drop in, and navigate real streets in style.';

  @override
  String get obStart => 'Get started';

  @override
  String get obGenresTitle => 'What do you love to play?';

  @override
  String get obGenresBody => 'Pick a few and we\'ll suggest worlds you\'ll like.';

  @override
  String get obHeardTitle => 'How did you find us?';

  @override
  String get obHeardStore => 'App store';

  @override
  String get obHeardTikTok => 'TikTok';

  @override
  String get obHeardYouTube => 'YouTube';

  @override
  String get obHeardInstagram => 'Instagram';

  @override
  String get obHeardFacebook => 'Facebook';

  @override
  String get obHeardGoogle => 'Google';

  @override
  String get obHeardFriend => 'A friend';

  @override
  String get obHeardOther => 'Other';

  @override
  String get obRatingTitle => 'Enjoying the ride?';

  @override
  String get obRatingBody => 'A quick rating helps other players find Overworld.';

  @override
  String get obRateNow => 'Rate Overworld';

  @override
  String get obNotNow => 'Not now';

  @override
  String get obCarTitle => 'Take it on the road';

  @override
  String get obCarBodyIos => 'Navigate on CarPlay with a character voice of your choice.';

  @override
  String get obCarBodyAndroid => 'Navigate on Android Auto with a character voice of your choice.';

  @override
  String get obListenVoice => 'Listen';

  @override
  String get obStopVoice => 'Stop';

  @override
  String get obLocationTitle => 'Ready to go';

  @override
  String get obLocationBody =>
      'Overworld uses your location to show where you are and to guide you. It stays on your device and is never sold.';

  @override
  String get obAllowLocation => 'Allow location';

  @override
  String get obSkipLocation => 'Continue without location';

  @override
  String get mapSelectTitle => 'Choose your world';

  @override
  String get mapSelectStart => 'Start exploring';

  @override
  String get variantLight => 'LIGHT';

  @override
  String get variantDark => 'DARK';

  @override
  String get railSearch => 'Search';

  @override
  String get railChangeMap => 'Change map';

  @override
  String get railNearby => 'Find nearby';

  @override
  String get railSaved => 'Saved places';

  @override
  String get railHome => 'Go home';

  @override
  String get railRecenter => 'Show my location';

  @override
  String get railSettings => 'Settings';

  @override
  String get railCompass => 'Reset to north';

  @override
  String get railAppearance => 'Toggle light or dark';

  @override
  String get setHomeFirst => 'Save a place as Home first';

  @override
  String get searchHint => 'Search places or addresses';

  @override
  String get recent => 'Recent';

  @override
  String get clearHistory => 'Clear';

  @override
  String get findNearby => 'Find nearby';

  @override
  String get noResultsTitle => 'No results';

  @override
  String get noResultsBody => 'Try searching for something else.';

  @override
  String get searchUnavailable => 'Search is unavailable right now.';

  @override
  String get nearbyEmpty => 'Nothing found nearby';

  @override
  String get catRestaurant => 'Restaurants';

  @override
  String get catFastFood => 'Fast food';

  @override
  String get catCafe => 'Coffee shops';

  @override
  String get catFuel => 'Gas stations';

  @override
  String get catCharging => 'Charging stations';

  @override
  String get catParking => 'Parking';

  @override
  String get catHotel => 'Hotels';

  @override
  String get catSupermarket => 'Supermarkets';

  @override
  String get catPharmacy => 'Pharmacies';

  @override
  String get catHospital => 'Hospitals';

  @override
  String get catSubway => 'Subway stations';

  @override
  String get catBank => 'Banks';

  @override
  String get getDirections => 'Get directions';

  @override
  String get savePlace => 'Save';

  @override
  String get savedLabel => 'Saved';

  @override
  String get call => 'Call';

  @override
  String get website => 'Website';

  @override
  String get share => 'Share';

  @override
  String get pinnedLocation => 'Pinned location';

  @override
  String distanceAway(String distance) {
    return '$distance away';
  }

  @override
  String get setAsHome => 'Set as home';

  @override
  String get editorNewTitle => 'Save location';

  @override
  String get editorEditTitle => 'Edit location';

  @override
  String get nameLabel => 'Name';

  @override
  String get namePlaceholder => 'Home, work, best burger…';

  @override
  String get iconLabel => 'Icon';

  @override
  String get homeToggle => 'This is my home';

  @override
  String get deletePlace => 'Delete location';

  @override
  String deleteConfirm(String name) {
    return 'Delete “$name”?';
  }

  @override
  String get savedTitle => 'Saved places';

  @override
  String get savedEmptyTitle => 'No saved places yet';

  @override
  String get savedEmptyBody => 'Long-press the map or save a search result to keep it here.';

  @override
  String get routeTitle => 'Route';

  @override
  String get fromMyLocation => 'My location';

  @override
  String get startNow => 'Start now';

  @override
  String get endRoute => 'End route';

  @override
  String get arrival => 'Arrival';

  @override
  String get routeError => 'Couldn\'t find a route there.';

  @override
  String get needLocationForRoute => 'Turn on location to get directions.';

  @override
  String get thenLabel => 'Then';

  @override
  String get rerouting => 'Rerouting…';

  @override
  String get arrivedTitle => 'You\'ve arrived';

  @override
  String get arrivedBody => 'Quest complete.';

  @override
  String get mute => 'Mute voice';

  @override
  String get unmute => 'Unmute voice';

  @override
  String get minShort => 'min';

  @override
  String get hourShort => 'h';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get sectionMap => 'Map';

  @override
  String get sectionNavigation => 'Navigation';

  @override
  String get sectionApp => 'App';

  @override
  String get sectionSupport => 'Support';

  @override
  String get sectionLegal => 'Legal';

  @override
  String get appearance => 'Appearance';

  @override
  String get appearanceAuto => 'Map default';

  @override
  String get appearanceLight => 'Light';

  @override
  String get appearanceDark => 'Dark';

  @override
  String get appIcon => 'App icon';

  @override
  String get distanceUnits => 'Distance units';

  @override
  String get kilometers => 'Kilometers';

  @override
  String get miles => 'Miles';

  @override
  String get voice => 'Navigation voice';

  @override
  String get carSettingsIos => 'CarPlay';

  @override
  String get carSettingsAndroid => 'Android Auto';

  @override
  String get rateUs => 'Rate us';

  @override
  String get shareApp => 'Share Overworld';

  @override
  String get community => 'Join the community';

  @override
  String get contactUs => 'Contact us';

  @override
  String get privacy => 'Privacy policy';

  @override
  String get terms => 'Terms of use';

  @override
  String get cleanData => 'Clean my data';

  @override
  String get cleanDataTitle => 'Clean my data?';

  @override
  String get cleanDataBody => 'This deletes saved places, search history and preferences on this device.';

  @override
  String get cleanDataConfirm => 'Delete data';

  @override
  String get dataCleaned => 'Your data was deleted';

  @override
  String get unitChanged => 'Distance unit changed';

  @override
  String versionLabel(String version) {
    return 'Version $version';
  }

  @override
  String get shareText => 'I\'m exploring my city as a game map with Overworld!';

  @override
  String get carTitle => 'Car display';

  @override
  String get carLightStyle => 'Light map style';

  @override
  String get carDarkStyle => 'Dark map style';

  @override
  String get carAlwaysDark => 'Always prefer dark mode';

  @override
  String get currentlyActive => 'Currently active';

  @override
  String get carUpdated => 'Car map style updated';

  @override
  String get appIconTitle => 'App icon';

  @override
  String get iconChanged => 'App icon changed';

  @override
  String get iconFailed => 'Couldn\'t change the app icon';

  @override
  String get iconUnsupported => 'Your device doesn\'t support changing the icon';

  @override
  String get voiceTitle => 'Navigation voice';

  @override
  String get voicePreview => 'Preview';

  @override
  String get contactTitle => 'Contact us';

  @override
  String get contactEmail => 'Your email';

  @override
  String get contactEmailHint => 'you@example.com';

  @override
  String get contactMessage => 'Message';

  @override
  String get contactMessageHint => 'Tell us what\'s up…';

  @override
  String get contactSend => 'Send';

  @override
  String get contactErrorEmpty => 'Please fill in both fields.';

  @override
  String get contactErrorEmail => 'Please enter a valid email address.';

  @override
  String get contactSentTitle => 'Thanks for reaching out!';

  @override
  String get contactSentBody => 'Your message is ready in your mail app. We\'ll get back to you soon.';

  @override
  String get updateTitle => 'Update required';

  @override
  String get updateBody => 'Please update to the latest version to keep using Overworld.';

  @override
  String get updateCta => 'Update now';

  @override
  String get locationOff => 'Location services are off';

  @override
  String get locationDenied => 'Location access is off';

  @override
  String get openSettings => 'Open Settings';

  @override
  String get currentLocationNotFound => 'Couldn\'t find your current location.';

  @override
  String get addedToSaved => 'Added to saved places';

  @override
  String get placeUpdated => 'Location updated';

  @override
  String get placeDeleted => 'Location deleted';

  @override
  String get homeSet => 'Home location set';

  @override
  String get themeTaglinePalmMetro => 'Sun-bleached radar of a crime-capital city';

  @override
  String get themeGenrePalmMetro => 'Open-world crime';

  @override
  String get themeTaglineBattleIsle => 'Candy-bright island, drop in anywhere';

  @override
  String get themeGenreBattleIsle => 'Battle royale';

  @override
  String get themeTaglineDesertState => 'Retro radar across a sunburnt state';

  @override
  String get themeGenreDesertState => 'Retro crime';

  @override
  String get themeTaglineFrontier => 'Hand-inked trails on weathered parchment';

  @override
  String get themeGenreFrontier => 'Western';

  @override
  String get themeTaglineNeonSprawl => 'Rain-slick megacity in electric yellow';

  @override
  String get themeGenreNeonSprawl => 'Cyberpunk';

  @override
  String get themeTaglineBlockland => 'A world built one cube at a time';

  @override
  String get themeGenreBlockland => 'Sandbox';

  @override
  String get themeTaglineWasteland => 'Green phosphor field terminal';

  @override
  String get themeGenreWasteland => 'Post-apocalyptic';

  @override
  String get themeTaglineAshenRealm => 'Gilded runes over a fallen kingdom';

  @override
  String get themeGenreAshenRealm => 'Dark fantasy';

  @override
  String get themeTaglineNorthernSaga => 'Frost-bitten cartography of the far north';

  @override
  String get themeGenreNorthernSaga => 'Epic fantasy';

  @override
  String get themeTaglineHuntersChart => 'A monster slayer\'s worn travel map';

  @override
  String get themeGenreHuntersChart => 'Fantasy RPG';

  @override
  String get themeTaglineTacticalOps => 'Gridded recon map for the drop zone';

  @override
  String get themeGenreTacticalOps => 'Military shooter';

  @override
  String get themeTaglineRuneStone => 'Carved teal stone of the old gods\' realms';

  @override
  String get themeGenreRuneStone => 'Mythic action';

  @override
  String get themeTaglineShadowParchment => 'An assassin\'s annotated city plan';

  @override
  String get themeGenreShadowParchment => 'Stealth adventure';

  @override
  String get themeTaglineStreetRacer => 'Midnight streets lit in neon trails';

  @override
  String get themeGenreStreetRacer => 'Racing';

  @override
  String get themeTaglineOvergrown => 'Nature reclaims the quiet city';

  @override
  String get themeGenreOvergrown => 'Survival';

  @override
  String get voiceTaglineClassic => 'Clear, calm directions';

  @override
  String get voiceTaglineGetaway => 'Keeps it cool under pressure';

  @override
  String get voiceTaglineRanger => 'Dusty trails, steady hands';

  @override
  String get voiceTaglineBuilder => 'Every road is a crafting recipe';

  @override
  String get voiceTaglineHerald => 'Announces every turn with fanfare';

  @override
  String get voiceTaglineShipai => 'Precise. Synthetic. Slightly smug.';

  @override
  String get voiceTaglineSergeant => 'No slacking at intersections';

  @override
  String get voiceTaglineCaptain => 'Charts the seas and the streets';

  @override
  String get placeIconStar => 'Star';

  @override
  String get placeIconHome => 'Home';

  @override
  String get placeIconWork => 'Work';

  @override
  String get placeIconFood => 'Food';

  @override
  String get placeIconCoffee => 'Coffee';

  @override
  String get placeIconBar => 'Bar';

  @override
  String get placeIconShop => 'Shop';

  @override
  String get placeIconGym => 'Gym';

  @override
  String get placeIconHeart => 'Favorite';

  @override
  String get placeIconFlag => 'Flag';

  @override
  String get placeIconCar => 'Car';

  @override
  String get placeIconSchool => 'School';

  @override
  String get voiceGuidance => 'Voice guidance';

  @override
  String get stateOn => 'On';

  @override
  String get stateOff => 'Off';

  @override
  String get railMore => 'More';

  @override
  String get back => 'Back';

  @override
  String get locationDeniedBody => 'Turn on location for Overworld in Settings to see yourself on the map and get directions.';

  @override
  String stepOf(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get clearText => 'Clear text';

  @override
  String get mapAppearance => 'Map appearance';

  @override
  String resultsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count results', one: '1 result', zero: 'No results');
    return '$_temp0';
  }

  @override
  String get homeLocked => 'Home uses the house icon';

  @override
  String get selectedLabel => 'Selected';

  @override
  String get showOnMap => 'Show on map';

  @override
  String get freeBannerTitle => 'Free & open source';

  @override
  String get freeBannerBody => 'Every map, voice and feature. No ads, no paywalls.';
}
