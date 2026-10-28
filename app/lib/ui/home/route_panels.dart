import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/units.dart';
import '../../data/models.dart';
import '../../l10n/app_localizations.dart';
import '../../nav/navigation_engine.dart';
import '../../nav/voice.dart';
import '../../state/nav_controller.dart';
import '../../state/providers.dart';
import '../hud.dart';
import 'map_chrome.dart';
import 'place_panel.dart';

IconData maneuverIcon(ManeuverKind k) => switch (k) {
  ManeuverKind.depart => Icons.navigation_rounded,
  ManeuverKind.arrive => Icons.flag_rounded,
  ManeuverKind.straight => Icons.straight_rounded,
  ManeuverKind.slightLeft => Icons.turn_slight_left_rounded,
  ManeuverKind.left => Icons.turn_left_rounded,
  ManeuverKind.sharpLeft => Icons.turn_sharp_left_rounded,
  ManeuverKind.slightRight => Icons.turn_slight_right_rounded,
  ManeuverKind.right => Icons.turn_right_rounded,
  ManeuverKind.sharpRight => Icons.turn_sharp_right_rounded,
  ManeuverKind.uturn => Icons.u_turn_left_rounded,
  ManeuverKind.roundabout => Icons.roundabout_right_rounded,
  ManeuverKind.merge => Icons.merge_rounded,
  ManeuverKind.fork => Icons.fork_right_rounded,
  ManeuverKind.rampLeft => Icons.ramp_left_rounded,
  ManeuverKind.rampRight => Icons.ramp_right_rounded,
};

String _duration(BuildContext context, double s) {
  final l = L.of(context);
  return formatDuration(s, h: l.hourShort, min: l.minShort);
}

String _arrivalTime(BuildContext context, double s) {
  final at = DateTime.now().add(Duration(seconds: s.round()));
  final use24 = MediaQuery.alwaysUse24HourFormatOf(context);
  final locale = Localizations.localeOf(context).toLanguageTag();
  return (use24 ? DateFormat.Hm(locale) : DateFormat.jm(locale)).format(at);
}

/// Bottom sheet while previewing a route: time, distance, arrival, Start,
/// and the turn-by-turn steps (drag up or tap Steps).
class RoutePreviewPanel extends ConsumerStatefulWidget {
  const RoutePreviewPanel({super.key, required this.state, required this.onClose});

  final NavPreview state;
  final VoidCallback onClose;

  @override
  ConsumerState<RoutePreviewPanel> createState() => _RoutePreviewPanelState();
}

class _RoutePreviewPanelState extends ConsumerState<RoutePreviewPanel> {
  final _steps = ValueNotifier(false);

  @override
  void dispose() {
    _steps.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final hud = ref.watch(hudProvider);
    final unit = ref.watch(settingsProvider.select((s) => s.unit));
    final state = widget.state;
    final r = state.route;

    Widget body;
    if (state.loading) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Center(child: CircularProgressIndicator(color: hud.accentText)),
      );
    } else if (state.error != null) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: [
            Text(
              state.error == 'no_location' ? l.needLocationForRoute : (state.error == 'no_route' ? l.routeError : l.somethingWrong),
              style: TextStyle(color: hud.text, fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            SecondaryButton(
              hud: hud,
              label: l.retry,
              icon: Icons.refresh_rounded,
              onPressed: () => ref.read(navProvider.notifier).preview(state.dest),
            ),
          ],
        ),
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            label:
                '${_duration(context, r!.durationS)}, ${formatDistance(r.distanceM, unit)}, ${l.arrival} ${_arrivalTime(context, r.durationS)}',
            excludeSemantics: true,
            child: Wrap(
              spacing: 12,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                Text(_duration(context, r.durationS), style: displayStyle(hud, 30, color: hud.accentText)),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    formatDistance(r.distanceM, unit),
                    style: TextStyle(color: hud.muted, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${l.arrival} ${_arrivalTime(context, r.durationS)}',
                    style: TextStyle(color: hud.text, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  hud: hud,
                  label: l.start,
                  icon: Icons.navigation_rounded,
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    ref.read(navProvider.notifier).start();
                  },
                ),
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder<bool>(
                valueListenable: _steps,
                builder: (_, open, _) => ActionPill(
                  hud: hud,
                  iconOnly: MediaQuery.sizeOf(context).width < 360 || MediaQuery.textScalerOf(context).scale(1) > 1.3,
                  icon: open ? Icons.expand_more_rounded : Icons.format_list_bulleted_rounded,
                  label: l.steps,
                  onTap: () => _steps.value = !open,
                ),
              ),
            ],
          ),
        ],
      );
    }

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 10, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  state.dest.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: hud.text, fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                onPressed: widget.onClose,
                tooltip: l.close,
                icon: Icon(Icons.close_rounded, color: hud.muted),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              ),
            ],
          ),
          Padding(padding: const EdgeInsets.only(right: 8), child: body),
        ],
      ),
    );

    final lang = Localizations.localeOf(context).languageCode;
    final details = r == null || state.loading || state.error != null
        ? null
        : Column(
            children: [
              Divider(height: 1, color: hud.text.withValues(alpha: 0.1)),
              for (var i = 1; i < r.steps.length; i++)
                ListTile(
                  minTileHeight: 56,
                  leading: Icon(maneuverIcon(r.steps[i].kind), color: hud.accentText, size: 28),
                  title: Text(
                    phraseFor(VoiceCue(step: r.steps[i], stage: CueStage.now, distanceM: 0, stepIndex: i), voicePersonas.first, unit, lang),
                    style: TextStyle(color: hud.text, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  subtitle: i + 1 < r.steps.length
                      ? Text(formatDistance(r.steps[i].distanceM, unit), style: TextStyle(color: hud.muted, fontSize: 13))
                      : null,
                ),
              const SizedBox(height: 8),
            ],
          );

    return MapSheet(hud: hud, header: header, details: details, expanded: _steps, onDismiss: widget.onClose);
  }
}

/// Top card while previewing: where the route starts and ends.
class RouteHeaderCard extends ConsumerWidget {
  const RouteHeaderCard({super.key, required this.dest, required this.onBack});

  final Place dest;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final hud = ref.watch(hudProvider);
    Widget line(Widget dot, String text, {bool strong = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 22, child: Center(child: dot)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: strong ? hud.text : hud.muted, fontSize: 15, fontWeight: strong ? FontWeight.w700 : FontWeight.w500),
            ),
          ),
        ],
      ),
    );
    return Material(
      color: hud.panelOpaque,
      elevation: 4,
      shadowColor: Colors.black54,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(hud.radius.clamp(12, 24).toDouble()),
        side: BorderSide(color: hud.text.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 14, 6),
        child: Row(
          children: [
            IconButton(
              onPressed: onBack,
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              icon: Icon(Icons.arrow_back_rounded, color: hud.text),
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  line(
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: hud.accent,
                        border: Border.all(color: hud.text, width: 2),
                      ),
                    ),
                    l.yourLocation,
                  ),
                  Divider(height: 1, indent: 32, color: hud.text.withValues(alpha: 0.12)),
                  line(Icon(Icons.place_rounded, color: hud.danger, size: 20), dest.name, strong: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Top banner: next maneuver.
class ManeuverBanner extends ConsumerWidget {
  const ManeuverBanner({super.key, required this.state});

  final NavActive state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final hud = ref.watch(hudProvider);
    final unit = ref.watch(settingsProvider.select((s) => s.unit));
    final p = state.progress;
    final step = p?.nextStep ?? (state.route.steps.length > 1 ? state.route.steps[1] : state.route.steps.first);
    final dist = p?.distanceToNextM ?? state.route.steps.first.distanceM;
    final parts = formatDistanceParts(dist, unit);
    final street = step.streetName.isNotEmpty ? step.streetName : (step.kind == ManeuverKind.arrive ? state.dest.name : '');
    final lang = Localizations.localeOf(context).languageCode;
    final stepIndex = (p?.currentStepIndex ?? 0) + 1;
    final spoken = state.rerouting
        ? l.rerouting
        : phraseFor(VoiceCue(step: step, stage: CueStage.approach, distanceM: dist, stepIndex: stepIndex), voicePersonas.first, unit, lang);

    // Announce once per maneuver (keyed by step), not on every distance tick.
    return KeyedSubtree(
      key: ValueKey('maneuver-$stepIndex-${state.rerouting}'),
      child: Semantics(
        liveRegion: true,
        label: spoken,
        excludeSemantics: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: hud.accent,
                borderRadius: BorderRadius.circular(hud.radius.clamp(10, 24)),
                boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 16, offset: Offset(0, 6))],
              ),
              padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
              child: state.rerouting
                  ? Row(
                      children: [
                        SizedBox(width: 26, height: 26, child: CircularProgressIndicator(color: hud.onAccent, strokeWidth: 3)),
                        const SizedBox(width: 14),
                        Flexible(
                          child: Text(
                            l.rerouting,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: displayStyle(hud, 22, color: hud.onAccent),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Icon(maneuverIcon(step.kind), color: hud.onAccent, size: 52),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: parts.value,
                                      style: displayStyle(hud, 32, color: hud.onAccent),
                                    ),
                                    TextSpan(
                                      text: ' ${parts.unit}',
                                      style: displayStyle(hud, 18, color: hud.onAccent),
                                    ),
                                  ],
                                ),
                              ),
                              if (street.isNotEmpty)
                                Text(
                                  street,
                                  style: TextStyle(color: hud.onAccent, fontSize: 18, fontWeight: FontWeight.w700),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
            if (p?.followingStep != null && !state.rerouting)
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(top: 6, left: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: hud.panel, borderRadius: BorderRadius.circular(hud.radius.clamp(8, 18))),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${l.thenLabel} ',
                        style: TextStyle(color: hud.text, fontWeight: FontWeight.w600),
                      ),
                      Icon(maneuverIcon(p!.followingStep!.kind), color: hud.text, size: 22),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Bottom bar during navigation: remaining time/distance/arrival, mute, end.
class NavBottomBar extends ConsumerWidget {
  const NavBottomBar({super.key, required this.state, required this.onEnd});

  final NavActive state;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final hud = ref.watch(hudProvider);
    final settings = ref.watch(settingsProvider);
    final p = state.progress;
    final remS = p?.remainingS ?? state.route.durationS;
    final remM = p?.remainingM ?? state.route.distanceM;

    return HudPanel(
      hud: hud,
      radius: hud.radius.clamp(12, 28),
      padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              label: '${_duration(context, remS)}, ${formatDistance(remM, settings.unit)}, ${l.arrival} ${_arrivalTime(context, remS)}',
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _arrivalTime(context, remS),
                      maxLines: 1,
                      softWrap: false,
                      style: displayStyle(hud, 26, color: hud.accentText),
                    ),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${_duration(context, remS)} · ${formatDistance(remM, settings.unit)}',
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(color: hud.muted, fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
          HudIconButton(
            hud: hud,
            icon: settings.voiceMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
            label: settings.voiceMuted ? l.unmute : l.mute,
            active: settings.voiceMuted,
            onPressed: () {
              final muted = !settings.voiceMuted;
              ref.read(settingsProvider.notifier).setVoiceMuted(muted);
              if (muted) ref.read(speakerProvider).stop();
            },
          ),
          const SizedBox(width: 8),
          LayoutBuilder(
            builder: (context, _) {
              final compact = MediaQuery.sizeOf(context).width < 360 || MediaQuery.textScalerOf(context).scale(1) > 1.3;
              final style = FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
                foregroundColor: Colors.white,
                minimumSize: const Size(48, 48),
                padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(hud.radius.clamp(6, 24))),
              );
              return Tooltip(
                message: l.endRoute,
                child: FilledButton(
                  onPressed: onEnd,
                  style: style,
                  child: compact
                      ? Semantics(label: l.endRoute, child: const Icon(Icons.close_rounded))
                      : Text(l.endRoute, maxLines: 1, style: displayStyle(hud, 16, color: Colors.white)),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Shown on arrival.
class ArrivedPanel extends ConsumerWidget {
  const ArrivedPanel({super.key, required this.dest, required this.onDone});

  final Place dest;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final hud = ref.watch(hudProvider);
    return HudPanel(
      hud: hud,
      radius: hud.radius.clamp(12, 28),
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events_rounded, color: hud.accentText, size: 44),
          const SizedBox(height: 6),
          Semantics(header: true, child: Text(l.arrivedTitle, style: displayStyle(hud, 24))),
          const SizedBox(height: 2),
          Text(
            dest.name,
            style: TextStyle(color: hud.muted, fontSize: 15),
            textAlign: TextAlign.center,
          ),
          Text(
            l.arrivedBody,
            style: TextStyle(color: hud.accentText, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          PrimaryButton(hud: hud, label: l.done, onPressed: onDone),
        ],
      ),
    );
  }
}
