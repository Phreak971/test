import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config.dart';
import '../../core/units.dart';
import '../../l10n/app_localizations.dart';
import '../../nav/voice.dart';
import '../../state/providers.dart';
import '../../themes/map_theme.dart';
import '../home/places_sheets.dart';
import '../hud.dart';
import 'app_icon_screen.dart';
import 'car_settings_screen.dart';
import 'contact_screen.dart';
import 'voice_screen.dart';

const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');

bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

/// Android 12+ "Open by default" screen, where people allow this app to
/// open links from other map services.
Future<void> openLinkSettings() async {
  try {
    await const MethodChannel('overworld/system').invokeMethod<bool>('openLinkSettings');
  } on PlatformException catch (_) {
  } on MissingPluginException catch (_) {}
}

Future<void> openStoreReview() async {
  final review = InAppReview.instance;
  try {
    if (await review.isAvailable()) {
      await review.requestReview();
      return;
    }
  } catch (_) {}
  await launchUrl(_isIOS ? AppConfig.appStoreUrl : AppConfig.playStoreUrl, mode: LaunchMode.externalApplication);
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final hud = ref.watch(hudProvider);
    final s = ref.watch(settingsProvider);
    final active = ref.watch(activeThemeProvider);
    final notifier = ref.read(settingsProvider.notifier);

    // Wide controls (dropdown, segmented) move under the title when they
    // can't fit beside it: large text or a narrow screen.
    final mq = MediaQuery.of(context);
    final stacked = mq.textScaler.scale(16) > 20 || mq.size.width < 360;

    Widget tile(IconData icon, String title, {String? value, VoidCallback? onTap, Widget? trailing, Color? color}) => ListTile(
      minTileHeight: 56,
      leading: Icon(icon, color: color ?? hud.accentText),
      title: Text(
        title,
        style: TextStyle(color: color ?? hud.text, fontWeight: FontWeight.w600, fontSize: 16),
      ),
      subtitle: trailing != null && stacked ? Padding(padding: const EdgeInsets.only(top: 8), child: trailing) : null,
      trailing: trailing != null
          ? (stacked ? null : trailing)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (value != null)
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: mq.size.width * 0.35),
                    child: Text(
                      value,
                      style: TextStyle(color: hud.muted, fontSize: 15),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (onTap != null) Icon(Icons.chevron_right_rounded, color: hud.muted),
              ],
            ),
      onTap: onTap,
    );

    void push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

    return Theme(
      data: buildAppTheme(hud),
      child: Scaffold(
        appBar: AppBar(title: Text(l.settingsTitle)),
        body: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: _FreeBanner(hud: hud),
                ),
                HudSectionHeader(hud: hud, text: l.sectionMap),
                tile(
                  Icons.contrast_rounded,
                  l.appearance,
                  trailing: DropdownButton<int>(
                    isExpanded: stacked,
                    value: s.preferDark == null ? 0 : (s.preferDark! ? 2 : 1),
                    underline: const SizedBox.shrink(),
                    dropdownColor: hud.panel.withValues(alpha: 1),
                    style: TextStyle(color: hud.text, fontSize: 15),
                    items: [
                      DropdownMenuItem(value: 0, child: Text(l.appearanceAuto)),
                      DropdownMenuItem(value: 1, child: Text(l.appearanceLight)),
                      DropdownMenuItem(value: 2, child: Text(l.appearanceDark)),
                    ],
                    onChanged: (v) {
                      final base = active.theme.baseVariant == MapVariant.dark;
                      final wantDark = v == 2;
                      notifier.setPreferDark(v == 0 || wantDark == base ? null : wantDark);
                    },
                  ),
                ),
                tile(
                  Icons.straighten_rounded,
                  l.distanceUnits,
                  trailing: SegmentedButton<DistanceUnit>(
                    showSelectedIcon: false,
                    expandedInsets: stacked ? EdgeInsets.zero : null,
                    segments: [
                      ButtonSegment(value: DistanceUnit.metric, label: Text(l.kilometers)),
                      ButtonSegment(value: DistanceUnit.imperial, label: Text(l.miles)),
                    ],
                    selected: {s.unit},
                    onSelectionChanged: (v) {
                      notifier.setUnit(v.first);
                      ref.read(toastProvider.notifier).show(l.unitChanged);
                    },
                  ),
                ),
                tile(Icons.apps_rounded, l.appIcon, onTap: () => push(const AppIconScreen())),
                HudSectionHeader(hud: hud, text: l.sectionNavigation),
                tile(Icons.record_voice_over_rounded, l.voice, value: personaById(s.voiceId).name, onTap: () => push(const VoiceScreen())),
                tile(
                  Icons.directions_car_rounded,
                  _isIOS ? l.carSettingsIos : l.carSettingsAndroid,
                  onTap: () => push(const CarSettingsScreen()),
                ),
                if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
                  ListTile(
                    minTileHeight: 56,
                    leading: Icon(Icons.link_rounded, color: hud.accentText),
                    title: Text(
                      l.openMapLinks,
                      style: TextStyle(color: hud.text, fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                    subtitle: Text(l.openMapLinksHint, style: TextStyle(color: hud.muted)),
                    trailing: Icon(Icons.open_in_new_rounded, color: hud.muted),
                    onTap: openLinkSettings,
                  ),
                HudSectionHeader(hud: hud, text: l.sectionSupport),
                tile(Icons.star_rounded, l.rateUs, onTap: openStoreReview),
                tile(
                  shareIcon,
                  l.shareApp,
                  onTap: () {
                    final box = context.findRenderObject() as RenderBox?;
                    SharePlus.instance.share(
                      ShareParams(
                        text: '${l.shareText}\n${_isIOS ? AppConfig.appStoreUrl : AppConfig.playStoreUrl}',
                        sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
                      ),
                    );
                  },
                ),
                tile(
                  Icons.groups_rounded,
                  l.community,
                  onTap: () => launchUrl(AppConfig.communityUrl, mode: LaunchMode.externalApplication),
                ),
                tile(Icons.mail_rounded, l.contactUs, onTap: () => push(const ContactScreen())),
                HudSectionHeader(hud: hud, text: l.sectionLegal),
                tile(Icons.privacy_tip_rounded, l.privacy, onTap: () => launchUrl(AppConfig.privacyUrl)),
                tile(Icons.description_rounded, l.terms, onTap: () => launchUrl(AppConfig.termsUrl)),
                tile(Icons.delete_forever_rounded, l.cleanData, color: const Color(0xFFE57373), onTap: () => _cleanData(context, ref)),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    l.versionLabel(appVersion),
                    style: TextStyle(color: hud.muted),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            const ToastHost(),
          ],
        ),
      ),
    );
  }

  Future<void> _cleanData(BuildContext context, WidgetRef ref) async {
    final l = L.of(context);
    final ok = await showAdaptiveDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog.adaptive(
        title: Text(l.cleanDataTitle),
        content: Text(l.cleanDataBody),
        actions: [
          adaptiveAction(ctx, label: l.cancel, onPressed: () => Navigator.of(ctx).pop(false)),
          adaptiveAction(ctx, label: l.cleanDataConfirm, destructive: true, onPressed: () => Navigator.of(ctx).pop(true)),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(localStoreProvider).clearUserData();
    ref.read(placesProvider.notifier).reload();
    ref.read(historyProvider.notifier).reload();
    // Keep the user inside the app rather than replaying onboarding.
    ref.read(settingsProvider.notifier)
      ..reload()
      ..completeOnboarding();
    ref.read(toastProvider.notifier).show(l.dataCleaned);
  }
}

class _FreeBanner extends StatelessWidget {
  const _FreeBanner({required this.hud});

  final Hud hud;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(hud.radius.clamp(10, 24)),
        gradient: LinearGradient(colors: [hud.accent, Color.lerp(hud.accent, Colors.black, 0.45)!]),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.favorite_rounded, color: hud.onAccent, size: 40),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.freeBannerTitle, style: displayStyle(hud, 20, color: hud.onAccent)),
                Text(l.freeBannerBody, style: TextStyle(color: hud.onAccent.withValues(alpha: 0.9))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
