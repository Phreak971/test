/// App-wide links and identifiers. Override at build time with
/// `--dart-define=KEY=value` without code changes.
abstract final class AppConfig {
  static final privacyUrl = Uri.parse(const String.fromEnvironment('PRIVACY_URL', defaultValue: 'https://overworld.app/privacy'));
  static final termsUrl = Uri.parse(const String.fromEnvironment('TERMS_URL', defaultValue: 'https://overworld.app/terms'));
  static final communityUrl = Uri.parse(const String.fromEnvironment('COMMUNITY_URL', defaultValue: 'https://overworld.app/community'));
  static const supportEmail = String.fromEnvironment('SUPPORT_EMAIL', defaultValue: 'support@overworld.app');

  /// Store listing ids for "Rate us" / "Update now".
  static const appStoreId = String.fromEnvironment('APP_STORE_ID', defaultValue: '');
  static const androidPackage = 'app.overworld.maps';

  static final playStoreUrl = Uri.parse('https://play.google.com/store/apps/details?id=$androidPackage');
  static Uri get appStoreUrl => Uri.parse(appStoreId.isEmpty ? 'https://apps.apple.com/' : 'https://apps.apple.com/app/id$appStoreId');
}
