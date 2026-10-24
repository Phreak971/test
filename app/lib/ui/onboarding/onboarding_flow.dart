import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';

import '../../l10n/app_localizations.dart';
import '../../nav/voice.dart';
import '../../state/location.dart';
import '../../state/nav_controller.dart';
import '../../state/providers.dart';
import '../../themes/icon_painter.dart';
import '../../themes/theme_catalog.dart';
import '../hud.dart';
import '../paywall/paywall_screen.dart';
import '../settings/voice_screen.dart';
import '../themes/theme_picker_screen.dart';
import '../themes/theme_swatch.dart';

/// First-run flow: intro → genres → source → rating → car → location →
/// pick a world → paywall. Calls [onFinished] at the end.
class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  final _pages = PageController();
  int _page = 0;
  final _genres = <String>{};
  String? _heardFrom;
  bool _speaking = false;

  static const _stepCount = 6;

  void _next() {
    HapticFeedback.selectionClick();
    if (_page < _stepCount - 1) {
      _pages.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
    } else {
      _pickWorld();
    }
  }

  void _pickWorld() {
    // Suggest the first theme matching a chosen genre.
    final suggestion = themeCatalog.where((t) => _genres.contains(t.genre) && !t.isPremium).firstOrNull ??
        themeCatalog.where((t) => _genres.contains(t.genre)).firstOrNull;
    if (suggestion != null && ref.read(themeUnlockedProvider(suggestion.id))) {
      ref.read(settingsProvider.notifier).selectTheme(suggestion.id);
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ThemePickerScreen(
        onboarding: true,
        onDone: () {
          final premium = ref.read(entitlementProvider).premium;
          if (premium) {
            _finish();
            return;
          }
          Navigator.of(context).push(MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => PaywallScreen(onClose: _finish),
          ));
        },
      ),
    ));
  }

  void _finish() {
    ref.read(settingsProvider.notifier).completeOnboarding(genres: _genres.toList(), heardFrom: _heardFrom);
    Navigator.of(context).popUntil((r) => r.isFirst);
    widget.onFinished();
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final hud = ref.watch(hudProvider);
    final isIOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

    final steps = <Widget>[
      _Step(
        hud: hud,
        art: const _HeroArt(),
        title: l.obGetStartedTitle,
        body: l.obGetStartedBody,
        primary: l.obStart,
        onPrimary: _next,
      ),
      _Step(
        hud: hud,
        title: l.obGenresTitle,
        body: l.obGenresBody,
        primary: l.next,
        onPrimary: _next,
        secondary: l.skip,
        onSecondary: _next,
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final t in themeCatalog)
              FilterChip(
                selected: _genres.contains(t.genre),
                label: Text(t.genre),
                labelStyle: TextStyle(color: _genres.contains(t.genre) ? hud.onAccent : hud.text, fontWeight: FontWeight.w600),
                selectedColor: hud.accent,
                checkmarkColor: hud.onAccent,
                backgroundColor: hud.text.withValues(alpha: 0.07),
                side: BorderSide(color: hud.text.withValues(alpha: 0.15)),
                materialTapTargetSize: MaterialTapTargetSize.padded,
                onSelected: (v) => setState(() => v ? _genres.add(t.genre) : _genres.remove(t.genre)),
              ),
          ],
        ),
      ),
      _Step(
        hud: hud,
        title: l.obHeardTitle,
        primary: l.next,
        onPrimary: _next,
        secondary: l.skip,
        onSecondary: _next,
        content: Column(
          children: [
            for (final (id, label, icon) in [
              ('store', l.obHeardStore, Icons.storefront_rounded),
              ('tiktok', l.obHeardTikTok, Icons.music_note_rounded),
              ('youtube', l.obHeardYouTube, Icons.play_circle_rounded),
              ('instagram', l.obHeardInstagram, Icons.camera_alt_rounded),
              ('facebook', l.obHeardFacebook, Icons.thumb_up_rounded),
              ('google', l.obHeardGoogle, Icons.search_rounded),
              ('friend', l.obHeardFriend, Icons.people_rounded),
              ('other', l.obHeardOther, Icons.more_horiz_rounded),
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Material(
                  color: _heardFrom == id ? hud.accent.withValues(alpha: 0.18) : hud.text.withValues(alpha: 0.05),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: _heardFrom == id ? hud.accent : Colors.transparent, width: 2),
                  ),
                  child: ListTile(
                    minTileHeight: 50,
                    leading: Icon(icon, color: hud.accent),
                    title: Text(label, style: TextStyle(color: hud.text, fontWeight: FontWeight.w600)),
                    selected: _heardFrom == id,
                    onTap: () => setState(() => _heardFrom = id),
                  ),
                ),
              ),
          ],
        ),
      ),
      _Step(
        hud: hud,
        art: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [for (var i = 0; i < 5; i++) Icon(Icons.star_rounded, color: const Color(0xFFFFC83D), size: 52)],
        ),
        title: l.obRatingTitle,
        body: l.obRatingBody,
        primary: l.obRateNow,
        onPrimary: () async {
          try {
            final r = InAppReview.instance;
            if (await r.isAvailable()) await r.requestReview();
          } catch (_) {}
          _next();
        },
        secondary: l.obNotNow,
        onSecondary: _next,
      ),
      _Step(
        hud: hud,
        art: SizedBox(
          height: 90,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final p in voicePersonas.skip(1).take(5))
                Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: PersonaAvatar(persona: p, size: 56)),
            ],
          ),
        ),
        title: l.obCarTitle,
        body: isIOS ? l.obCarBodyIos : l.obCarBodyAndroid,
        primary: l.next,
        onPrimary: () {
          ref.read(speakerProvider).stop();
          _next();
        },
        secondary: _speaking ? l.obStopVoice : l.obListenVoice,
        secondaryIcon: _speaking ? Icons.stop_rounded : Icons.graphic_eq_rounded,
        onSecondary: () {
          final speaker = ref.read(speakerProvider);
          if (_speaking) {
            speaker.stop();
            setState(() => _speaking = false);
            return;
          }
          final persona = personaById('getaway');
          final lang = Localizations.localeOf(context).languageCode;
          speaker.speak(samplePhrase(persona, lang), persona, lang);
          setState(() => _speaking = true);
          Future<void>.delayed(const Duration(seconds: 4), () {
            if (mounted) setState(() => _speaking = false);
          });
        },
      ),
      _Step(
        hud: hud,
        art: Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(shape: BoxShape.circle, color: hud.accent.withValues(alpha: 0.18)),
          child: Icon(Icons.my_location_rounded, color: hud.accent, size: 56),
        ),
        title: l.obLocationTitle,
        body: l.obLocationBody,
        primary: l.obAllowLocation,
        onPrimary: () async {
          await ref.read(locationProvider.notifier).request();
          _next();
        },
        secondary: l.obSkipLocation,
        onSecondary: _next,
      ),
    ];

    return Theme(
      data: buildAppTheme(hud),
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: Semantics(
                  label: '${_page + 1} / $_stepCount',
                  child: Row(
                    children: [
                      for (var i = 0; i < _stepCount; i++)
                        Expanded(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            height: 5,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: i <= _page ? hud.accent : hud.text.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pages,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (p) => setState(() => _page = p),
                  children: steps,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.hud,
    required this.title,
    required this.primary,
    required this.onPrimary,
    this.body,
    this.art,
    this.content,
    this.secondary,
    this.secondaryIcon,
    this.onSecondary,
  });

  final Hud hud;
  final String title;
  final String? body;
  final Widget? art;
  final Widget? content;
  final String primary;
  final VoidCallback onPrimary;
  final String? secondary;
  final IconData? secondaryIcon;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  if (art != null) ...[const SizedBox(height: 12), art!, const SizedBox(height: 24)],
                  Semantics(header: true, child: Text(title, style: displayStyle(hud, 30), textAlign: TextAlign.center)),
                  if (body != null) ...[
                    const SizedBox(height: 10),
                    Text(body!, style: TextStyle(color: hud.muted, fontSize: 16, height: 1.4), textAlign: TextAlign.center),
                  ],
                  if (content != null) ...[const SizedBox(height: 20), content!],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          PrimaryButton(hud: hud, label: primary, onPressed: onPrimary),
          if (secondary != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              style: TextButton.styleFrom(minimumSize: const Size(48, 48), foregroundColor: hud.muted),
              onPressed: onSecondary,
              icon: secondaryIcon == null ? const SizedBox.shrink() : Icon(secondaryIcon),
              label: Text(secondary!, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Globe of theme swatches orbited by painted POI badges.
class _HeroArt extends ConsumerWidget {
  const _HeroArt();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hud = ref.watch(hudProvider);
    return ExcludeSemantics(
      child: SizedBox(
        width: 280,
        height: 280,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: hud.accent.withValues(alpha: 0.55), blurRadius: 50, spreadRadius: 4)]),
              child: ClipOval(
                child: GridView.count(
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 3,
                  children: [for (final t in themeCatalog.take(9)) ThemeSwatch(theme: t, variant: t.baseVariant)],
                ),
              ),
            ),
            for (final (i, id) in ['food', 'fuel', 'coffee', 'hotel', 'gym', 'bar'].indexed)
              Transform.translate(
                offset: Offset(125 * math.cos(i * math.pi / 3 - math.pi / 2), 125 * math.sin(i * math.pi / 3 - math.pi / 2)),
                child: _Badge(glyph: poiGlyphs[id]!, color: Color(themeCatalog[(i * 2) % themeCatalog.length].base.accent)),
              ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.glyph, required this.color});

  final IconData glyph;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.black,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 12)],
      ),
      child: Icon(glyph, color: color, size: 26),
    );
  }
}
