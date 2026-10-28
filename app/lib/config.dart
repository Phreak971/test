/// App-wide links and identifiers. Override at build time with
/// `--dart-define=KEY=value` without code changes.
abstract final class AppConfig {
  /// Project website (GitHub Pages from the repo's `docs/` folder).
  static const siteUrl = String.fromEnvironment('SITE_URL', defaultValue: 'https://phreak971.github.io/test/');

  static final privacyUrl = Uri.parse(const String.fromEnvironment('PRIVACY_URL', defaultValue: '${siteUrl}privacy/'));
  static final termsUrl = Uri.parse(const String.fromEnvironment('TERMS_URL', defaultValue: '${siteUrl}terms/'));
  static final communityUrl = Uri.parse(const String.fromEnvironment('COMMUNITY_URL', defaultValue: 'https://github.com/Phreak971/test'));

  /// Landing page for shared places; it opens the app when installed.
  static final shareBaseUrl = Uri.parse(const String.fromEnvironment('SHARE_BASE_URL', defaultValue: '${siteUrl}p/'));
  static const supportEmail = String.fromEnvironment('SUPPORT_EMAIL', defaultValue: 'support@overworld.app');

  /// Store listing ids for "Rate us" / "Update now".
  static const appStoreId = String.fromEnvironment('APP_STORE_ID', defaultValue: '');
  static const androidPackage = 'app.overworld.maps';

  static final playStoreUrl = Uri.parse('https://play.google.com/store/apps/details?id=$androidPackage');
  static Uri get appStoreUrl => Uri.parse(appStoreId.isEmpty ? 'https://apps.apple.com/' : 'https://apps.apple.com/app/id$appStoreId');
}
