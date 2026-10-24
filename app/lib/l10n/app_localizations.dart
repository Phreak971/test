import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of L
/// returned by `L.of(context)`.
///
/// Applications need to include `L.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: L.localizationsDelegates,
///   supportedLocales: L.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the L.supportedLocales
/// property.
abstract class L {
  L(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static L of(BuildContext context) {
    return Localizations.of<L>(context, L)!;
  }

  static const LocalizationsDelegate<L> delegate = _LDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Overworld'**
  String get appName;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'Your world, game-styled.'**
  String get tagline;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get saveChanges;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @unknownLocation.
  ///
  /// In en, this message translates to:
  /// **'Unknown location'**
  String get unknownLocation;

  /// No description provided for @somethingWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get somethingWrong;

  /// No description provided for @obGetStartedTitle.
  ///
  /// In en, this message translates to:
  /// **'Turn your city into a game map'**
  String get obGetStartedTitle;

  /// No description provided for @obGetStartedBody.
  ///
  /// In en, this message translates to:
  /// **'Pick a world, drop in, and navigate real streets in style.'**
  String get obGetStartedBody;

  /// No description provided for @obStart.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get obStart;

  /// No description provided for @obGenresTitle.
  ///
  /// In en, this message translates to:
  /// **'What do you love to play?'**
  String get obGenresTitle;

  /// No description provided for @obGenresBody.
  ///
  /// In en, this message translates to:
  /// **'Pick a few and we\'ll suggest worlds you\'ll like.'**
  String get obGenresBody;

  /// No description provided for @obHeardTitle.
  ///
  /// In en, this message translates to:
  /// **'How did you find us?'**
  String get obHeardTitle;

  /// No description provided for @obHeardStore.
  ///
  /// In en, this message translates to:
  /// **'App store'**
  String get obHeardStore;

  /// No description provided for @obHeardTikTok.
  ///
  /// In en, this message translates to:
  /// **'TikTok'**
  String get obHeardTikTok;

  /// No description provided for @obHeardYouTube.
  ///
  /// In en, this message translates to:
  /// **'YouTube'**
  String get obHeardYouTube;

  /// No description provided for @obHeardInstagram.
  ///
  /// In en, this message translates to:
  /// **'Instagram'**
  String get obHeardInstagram;

  /// No description provided for @obHeardFacebook.
  ///
  /// In en, this message translates to:
  /// **'Facebook'**
  String get obHeardFacebook;

  /// No description provided for @obHeardGoogle.
  ///
  /// In en, this message translates to:
  /// **'Google'**
  String get obHeardGoogle;

  /// No description provided for @obHeardFriend.
  ///
  /// In en, this message translates to:
  /// **'A friend'**
  String get obHeardFriend;

  /// No description provided for @obHeardOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get obHeardOther;

  /// No description provided for @obRatingTitle.
  ///
  /// In en, this message translates to:
  /// **'Enjoying the ride?'**
  String get obRatingTitle;

  /// No description provided for @obRatingBody.
  ///
  /// In en, this message translates to:
  /// **'A quick rating helps other players find Overworld.'**
  String get obRatingBody;

  /// No description provided for @obRateNow.
  ///
  /// In en, this message translates to:
  /// **'Rate Overworld'**
  String get obRateNow;

  /// No description provided for @obNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get obNotNow;

  /// No description provided for @obCarTitle.
  ///
  /// In en, this message translates to:
  /// **'Take it on the road'**
  String get obCarTitle;

  /// No description provided for @obCarBodyIos.
  ///
  /// In en, this message translates to:
  /// **'Navigate on CarPlay with a character voice of your choice.'**
  String get obCarBodyIos;

  /// No description provided for @obCarBodyAndroid.
  ///
  /// In en, this message translates to:
  /// **'Navigate on Android Auto with a character voice of your choice.'**
  String get obCarBodyAndroid;

  /// No description provided for @obListenVoice.
  ///
  /// In en, this message translates to:
  /// **'Listen'**
  String get obListenVoice;

  /// No description provided for @obStopVoice.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get obStopVoice;

  /// No description provided for @obLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Ready to go'**
  String get obLocationTitle;

  /// No description provided for @obLocationBody.
  ///
  /// In en, this message translates to:
  /// **'Overworld uses your location to show where you are and to guide you. It stays on your device and is never sold.'**
  String get obLocationBody;

  /// No description provided for @obAllowLocation.
  ///
  /// In en, this message translates to:
  /// **'Allow location'**
  String get obAllowLocation;

  /// No description provided for @obSkipLocation.
  ///
  /// In en, this message translates to:
  /// **'Continue without location'**
  String get obSkipLocation;

  /// No description provided for @mapSelectTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your world'**
  String get mapSelectTitle;

  /// No description provided for @mapSelectStart.
  ///
  /// In en, this message translates to:
  /// **'Start exploring'**
  String get mapSelectStart;

  /// No description provided for @proBadge.
  ///
  /// In en, this message translates to:
  /// **'PRO'**
  String get proBadge;

  /// No description provided for @freeBadge.
  ///
  /// In en, this message translates to:
  /// **'FREE'**
  String get freeBadge;

  /// No description provided for @variantLight.
  ///
  /// In en, this message translates to:
  /// **'LIGHT'**
  String get variantLight;

  /// No description provided for @variantDark.
  ///
  /// In en, this message translates to:
  /// **'DARK'**
  String get variantDark;

  /// No description provided for @unlockAllMaps.
  ///
  /// In en, this message translates to:
  /// **'Unlock all maps'**
  String get unlockAllMaps;

  /// No description provided for @lockedTitle.
  ///
  /// In en, this message translates to:
  /// **'This map is locked'**
  String get lockedTitle;

  /// No description provided for @lockedBody.
  ///
  /// In en, this message translates to:
  /// **'Unlock {name} and every other world with Overworld Pro.'**
  String lockedBody(String name);

  /// No description provided for @lockedCta.
  ///
  /// In en, this message translates to:
  /// **'Unlock map'**
  String get lockedCta;

  /// No description provided for @lockedUseFree.
  ///
  /// In en, this message translates to:
  /// **'Use a free map'**
  String get lockedUseFree;

  /// No description provided for @railSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get railSearch;

  /// No description provided for @railChangeMap.
  ///
  /// In en, this message translates to:
  /// **'Change map'**
  String get railChangeMap;

  /// No description provided for @railNearby.
  ///
  /// In en, this message translates to:
  /// **'Find nearby'**
  String get railNearby;

  /// No description provided for @railSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved places'**
  String get railSaved;

  /// No description provided for @railHome.
  ///
  /// In en, this message translates to:
  /// **'Go home'**
  String get railHome;

  /// No description provided for @railRecenter.
  ///
  /// In en, this message translates to:
  /// **'Show my location'**
  String get railRecenter;

  /// No description provided for @railSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get railSettings;

  /// No description provided for @railCompass.
  ///
  /// In en, this message translates to:
  /// **'Reset to north'**
  String get railCompass;

  /// No description provided for @railAppearance.
  ///
  /// In en, this message translates to:
  /// **'Toggle light or dark'**
  String get railAppearance;

  /// No description provided for @setHomeFirst.
  ///
  /// In en, this message translates to:
  /// **'Save a place as Home first'**
  String get setHomeFirst;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search places or addresses'**
  String get searchHint;

  /// No description provided for @recent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get recent;

  /// No description provided for @clearHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearHistory;

  /// No description provided for @findNearby.
  ///
  /// In en, this message translates to:
  /// **'Find nearby'**
  String get findNearby;

  /// No description provided for @noResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get noResultsTitle;

  /// No description provided for @noResultsBody.
  ///
  /// In en, this message translates to:
  /// **'Try searching for something else.'**
  String get noResultsBody;

  /// No description provided for @searchUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Search is unavailable right now.'**
  String get searchUnavailable;

  /// No description provided for @nearbyEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing found nearby'**
  String get nearbyEmpty;

  /// No description provided for @catRestaurant.
  ///
  /// In en, this message translates to:
  /// **'Restaurants'**
  String get catRestaurant;

  /// No description provided for @catFastFood.
  ///
  /// In en, this message translates to:
  /// **'Fast food'**
  String get catFastFood;

  /// No description provided for @catCafe.
  ///
  /// In en, this message translates to:
  /// **'Coffee shops'**
  String get catCafe;

  /// No description provided for @catFuel.
  ///
  /// In en, this message translates to:
  /// **'Gas stations'**
  String get catFuel;

  /// No description provided for @catCharging.
  ///
  /// In en, this message translates to:
  /// **'Charging stations'**
  String get catCharging;

  /// No description provided for @catParking.
  ///
  /// In en, this message translates to:
  /// **'Parking'**
  String get catParking;

  /// No description provided for @catHotel.
  ///
  /// In en, this message translates to:
  /// **'Hotels'**
  String get catHotel;

  /// No description provided for @catSupermarket.
  ///
  /// In en, this message translates to:
  /// **'Supermarkets'**
  String get catSupermarket;

  /// No description provided for @catPharmacy.
  ///
  /// In en, this message translates to:
  /// **'Pharmacies'**
  String get catPharmacy;

  /// No description provided for @catHospital.
  ///
  /// In en, this message translates to:
  /// **'Hospitals'**
  String get catHospital;

  /// No description provided for @catSubway.
  ///
  /// In en, this message translates to:
  /// **'Subway stations'**
  String get catSubway;

  /// No description provided for @catBank.
  ///
  /// In en, this message translates to:
  /// **'Banks'**
  String get catBank;

  /// No description provided for @getDirections.
  ///
  /// In en, this message translates to:
  /// **'Get Directions'**
  String get getDirections;

  /// No description provided for @savePlace.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get savePlace;

  /// No description provided for @savedLabel.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get savedLabel;

  /// No description provided for @call.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get call;

  /// No description provided for @website.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get website;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @pinnedLocation.
  ///
  /// In en, this message translates to:
  /// **'Pinned location'**
  String get pinnedLocation;

  /// No description provided for @distanceAway.
  ///
  /// In en, this message translates to:
  /// **'{distance} away'**
  String distanceAway(String distance);

  /// No description provided for @setAsHome.
  ///
  /// In en, this message translates to:
  /// **'Set as home'**
  String get setAsHome;

  /// No description provided for @editorNewTitle.
  ///
  /// In en, this message translates to:
  /// **'Save location'**
  String get editorNewTitle;

  /// No description provided for @editorEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit location'**
  String get editorEditTitle;

  /// No description provided for @nameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get nameLabel;

  /// No description provided for @namePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Home, work, best burger…'**
  String get namePlaceholder;

  /// No description provided for @iconLabel.
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get iconLabel;

  /// No description provided for @homeToggle.
  ///
  /// In en, this message translates to:
  /// **'This is my home'**
  String get homeToggle;

  /// No description provided for @deletePlace.
  ///
  /// In en, this message translates to:
  /// **'Delete location'**
  String get deletePlace;

  /// No description provided for @deleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete “{name}”?'**
  String deleteConfirm(String name);

  /// No description provided for @savedTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved places'**
  String get savedTitle;

  /// No description provided for @savedEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No saved places yet'**
  String get savedEmptyTitle;

  /// No description provided for @savedEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Long-press the map or save a search result to keep it here.'**
  String get savedEmptyBody;

  /// No description provided for @routeTitle.
  ///
  /// In en, this message translates to:
  /// **'Route'**
  String get routeTitle;

  /// No description provided for @fromMyLocation.
  ///
  /// In en, this message translates to:
  /// **'My location'**
  String get fromMyLocation;

  /// No description provided for @startNow.
  ///
  /// In en, this message translates to:
  /// **'Start Now'**
  String get startNow;

  /// No description provided for @endRoute.
  ///
  /// In en, this message translates to:
  /// **'End Route'**
  String get endRoute;

  /// No description provided for @arrival.
  ///
  /// In en, this message translates to:
  /// **'Arrival'**
  String get arrival;

  /// No description provided for @routeError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t find a route there.'**
  String get routeError;

  /// No description provided for @needLocationForRoute.
  ///
  /// In en, this message translates to:
  /// **'Turn on location to get directions.'**
  String get needLocationForRoute;

  /// No description provided for @thenLabel.
  ///
  /// In en, this message translates to:
  /// **'Then'**
  String get thenLabel;

  /// No description provided for @rerouting.
  ///
  /// In en, this message translates to:
  /// **'Rerouting…'**
  String get rerouting;

  /// No description provided for @arrivedTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'ve arrived'**
  String get arrivedTitle;

  /// No description provided for @arrivedBody.
  ///
  /// In en, this message translates to:
  /// **'Quest complete.'**
  String get arrivedBody;

  /// No description provided for @mute.
  ///
  /// In en, this message translates to:
  /// **'Mute voice'**
  String get mute;

  /// No description provided for @unmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute voice'**
  String get unmute;

  /// No description provided for @minShort.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get minShort;

  /// No description provided for @hourShort.
  ///
  /// In en, this message translates to:
  /// **'h'**
  String get hourShort;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @premiumBannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Overworld Pro'**
  String get premiumBannerTitle;

  /// No description provided for @premiumBannerBody.
  ///
  /// In en, this message translates to:
  /// **'Unlock every map and voice.'**
  String get premiumBannerBody;

  /// No description provided for @premiumBannerCta.
  ///
  /// In en, this message translates to:
  /// **'Go Pro'**
  String get premiumBannerCta;

  /// No description provided for @proActive.
  ///
  /// In en, this message translates to:
  /// **'Pro is active. Thanks for your support!'**
  String get proActive;

  /// No description provided for @sectionMap.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get sectionMap;

  /// No description provided for @sectionNavigation.
  ///
  /// In en, this message translates to:
  /// **'Navigation'**
  String get sectionNavigation;

  /// No description provided for @sectionApp.
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get sectionApp;

  /// No description provided for @sectionSupport.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get sectionSupport;

  /// No description provided for @sectionLegal.
  ///
  /// In en, this message translates to:
  /// **'Legal'**
  String get sectionLegal;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @appearanceAuto.
  ///
  /// In en, this message translates to:
  /// **'Map default'**
  String get appearanceAuto;

  /// No description provided for @appearanceLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get appearanceLight;

  /// No description provided for @appearanceDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get appearanceDark;

  /// No description provided for @appIcon.
  ///
  /// In en, this message translates to:
  /// **'App icon'**
  String get appIcon;

  /// No description provided for @distanceUnits.
  ///
  /// In en, this message translates to:
  /// **'Distance units'**
  String get distanceUnits;

  /// No description provided for @kilometers.
  ///
  /// In en, this message translates to:
  /// **'Kilometers'**
  String get kilometers;

  /// No description provided for @miles.
  ///
  /// In en, this message translates to:
  /// **'Miles'**
  String get miles;

  /// No description provided for @voice.
  ///
  /// In en, this message translates to:
  /// **'Navigation voice'**
  String get voice;

  /// No description provided for @carSettingsIos.
  ///
  /// In en, this message translates to:
  /// **'CarPlay'**
  String get carSettingsIos;

  /// No description provided for @carSettingsAndroid.
  ///
  /// In en, this message translates to:
  /// **'Android Auto'**
  String get carSettingsAndroid;

  /// No description provided for @rateUs.
  ///
  /// In en, this message translates to:
  /// **'Rate us'**
  String get rateUs;

  /// No description provided for @shareApp.
  ///
  /// In en, this message translates to:
  /// **'Share Overworld'**
  String get shareApp;

  /// No description provided for @community.
  ///
  /// In en, this message translates to:
  /// **'Join the community'**
  String get community;

  /// No description provided for @contactUs.
  ///
  /// In en, this message translates to:
  /// **'Contact us'**
  String get contactUs;

  /// No description provided for @restorePurchases.
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get restorePurchases;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get privacy;

  /// No description provided for @terms.
  ///
  /// In en, this message translates to:
  /// **'Terms of use'**
  String get terms;

  /// No description provided for @cleanData.
  ///
  /// In en, this message translates to:
  /// **'Clean my data'**
  String get cleanData;

  /// No description provided for @cleanDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Clean my data?'**
  String get cleanDataTitle;

  /// No description provided for @cleanDataBody.
  ///
  /// In en, this message translates to:
  /// **'This deletes saved places, search history and preferences on this device. Purchases are not affected.'**
  String get cleanDataBody;

  /// No description provided for @cleanDataConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete data'**
  String get cleanDataConfirm;

  /// No description provided for @dataCleaned.
  ///
  /// In en, this message translates to:
  /// **'Your data was deleted'**
  String get dataCleaned;

  /// No description provided for @unitChanged.
  ///
  /// In en, this message translates to:
  /// **'Distance unit changed'**
  String get unitChanged;

  /// No description provided for @versionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String versionLabel(String version);

  /// No description provided for @shareText.
  ///
  /// In en, this message translates to:
  /// **'I\'m exploring my city as a game map with Overworld!'**
  String get shareText;

  /// No description provided for @carTitle.
  ///
  /// In en, this message translates to:
  /// **'Car display'**
  String get carTitle;

  /// No description provided for @carLightStyle.
  ///
  /// In en, this message translates to:
  /// **'Light map style'**
  String get carLightStyle;

  /// No description provided for @carDarkStyle.
  ///
  /// In en, this message translates to:
  /// **'Dark map style'**
  String get carDarkStyle;

  /// No description provided for @carAlwaysDark.
  ///
  /// In en, this message translates to:
  /// **'Always prefer dark mode'**
  String get carAlwaysDark;

  /// No description provided for @currentlyActive.
  ///
  /// In en, this message translates to:
  /// **'Currently active'**
  String get currentlyActive;

  /// No description provided for @carUpdated.
  ///
  /// In en, this message translates to:
  /// **'Car map style updated'**
  String get carUpdated;

  /// No description provided for @appIconTitle.
  ///
  /// In en, this message translates to:
  /// **'App icon'**
  String get appIconTitle;

  /// No description provided for @iconChanged.
  ///
  /// In en, this message translates to:
  /// **'App icon changed'**
  String get iconChanged;

  /// No description provided for @iconFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t change the app icon'**
  String get iconFailed;

  /// No description provided for @iconUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Your device doesn\'t support changing the icon'**
  String get iconUnsupported;

  /// No description provided for @voiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Navigation voice'**
  String get voiceTitle;

  /// No description provided for @voicePreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get voicePreview;

  /// No description provided for @contactTitle.
  ///
  /// In en, this message translates to:
  /// **'Contact us'**
  String get contactTitle;

  /// No description provided for @contactEmail.
  ///
  /// In en, this message translates to:
  /// **'Your email'**
  String get contactEmail;

  /// No description provided for @contactEmailHint.
  ///
  /// In en, this message translates to:
  /// **'you@example.com'**
  String get contactEmailHint;

  /// No description provided for @contactMessage.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get contactMessage;

  /// No description provided for @contactMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Tell us what\'s up…'**
  String get contactMessageHint;

  /// No description provided for @contactSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get contactSend;

  /// No description provided for @contactErrorEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please fill in both fields.'**
  String get contactErrorEmpty;

  /// No description provided for @contactErrorEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address.'**
  String get contactErrorEmail;

  /// No description provided for @contactSentTitle.
  ///
  /// In en, this message translates to:
  /// **'Thanks for reaching out!'**
  String get contactSentTitle;

  /// No description provided for @contactSentBody.
  ///
  /// In en, this message translates to:
  /// **'Your message is ready in your mail app. We\'ll get back to you soon.'**
  String get contactSentBody;

  /// No description provided for @paywallTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock every world'**
  String get paywallTitle;

  /// No description provided for @paywallFeatureMaps.
  ///
  /// In en, this message translates to:
  /// **'All 15 game-styled maps'**
  String get paywallFeatureMaps;

  /// No description provided for @paywallFeatureVoices.
  ///
  /// In en, this message translates to:
  /// **'Every character voice'**
  String get paywallFeatureVoices;

  /// No description provided for @paywallFeatureCar.
  ///
  /// In en, this message translates to:
  /// **'CarPlay & Android Auto'**
  String get paywallFeatureCar;

  /// No description provided for @paywallFeatureUpdates.
  ///
  /// In en, this message translates to:
  /// **'New worlds as they drop'**
  String get paywallFeatureUpdates;

  /// No description provided for @planWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get planWeekly;

  /// No description provided for @planMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get planMonthly;

  /// No description provided for @planYearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get planYearly;

  /// No description provided for @planLifetime.
  ///
  /// In en, this message translates to:
  /// **'Lifetime'**
  String get planLifetime;

  /// No description provided for @bestValue.
  ///
  /// In en, this message translates to:
  /// **'Best value'**
  String get bestValue;

  /// No description provided for @freeTrial.
  ///
  /// In en, this message translates to:
  /// **'Free trial'**
  String get freeTrial;

  /// No description provided for @oneTimePurchase.
  ///
  /// In en, this message translates to:
  /// **'One-time purchase'**
  String get oneTimePurchase;

  /// No description provided for @billedWeekly.
  ///
  /// In en, this message translates to:
  /// **'Billed weekly'**
  String get billedWeekly;

  /// No description provided for @billedMonthly.
  ///
  /// In en, this message translates to:
  /// **'Billed monthly'**
  String get billedMonthly;

  /// No description provided for @billedYearly.
  ///
  /// In en, this message translates to:
  /// **'Billed yearly'**
  String get billedYearly;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @purchaseSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Pro!'**
  String get purchaseSuccessTitle;

  /// No description provided for @purchaseSuccessBody.
  ///
  /// In en, this message translates to:
  /// **'Every map and voice is now unlocked.'**
  String get purchaseSuccessBody;

  /// No description provided for @purchaseFailed.
  ///
  /// In en, this message translates to:
  /// **'The purchase didn\'t go through. Please try again.'**
  String get purchaseFailed;

  /// No description provided for @purchasePending.
  ///
  /// In en, this message translates to:
  /// **'Your purchase is pending approval.'**
  String get purchasePending;

  /// No description provided for @restoreNone.
  ///
  /// In en, this message translates to:
  /// **'No previous purchases were found.'**
  String get restoreNone;

  /// No description provided for @restoreDone.
  ///
  /// In en, this message translates to:
  /// **'Purchases restored'**
  String get restoreDone;

  /// No description provided for @storeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The store isn\'t available right now.'**
  String get storeUnavailable;

  /// No description provided for @autoRenew.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions renew automatically unless cancelled at least 24 hours before the end of the period. Manage them in your account settings.'**
  String get autoRenew;

  /// No description provided for @updateTitle.
  ///
  /// In en, this message translates to:
  /// **'Update required'**
  String get updateTitle;

  /// No description provided for @updateBody.
  ///
  /// In en, this message translates to:
  /// **'Please update to the latest version to keep using Overworld.'**
  String get updateBody;

  /// No description provided for @updateCta.
  ///
  /// In en, this message translates to:
  /// **'Update now'**
  String get updateCta;

  /// No description provided for @locationOff.
  ///
  /// In en, this message translates to:
  /// **'Location services are off'**
  String get locationOff;

  /// No description provided for @locationDenied.
  ///
  /// In en, this message translates to:
  /// **'Location access is off'**
  String get locationDenied;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get openSettings;

  /// No description provided for @currentLocationNotFound.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t find your current location.'**
  String get currentLocationNotFound;

  /// No description provided for @addedToSaved.
  ///
  /// In en, this message translates to:
  /// **'Added to saved places'**
  String get addedToSaved;

  /// No description provided for @placeUpdated.
  ///
  /// In en, this message translates to:
  /// **'Location updated'**
  String get placeUpdated;

  /// No description provided for @placeDeleted.
  ///
  /// In en, this message translates to:
  /// **'Location deleted'**
  String get placeDeleted;

  /// No description provided for @homeSet.
  ///
  /// In en, this message translates to:
  /// **'Home location set'**
  String get homeSet;
}

class _LDelegate extends LocalizationsDelegate<L> {
  const _LDelegate();

  @override
  Future<L> load(Locale locale) {
    return SynchronousFuture<L>(lookupL(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_LDelegate old) => false;
}

L lookupL(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return LEn();
  }

  throw FlutterError(
    'L.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
