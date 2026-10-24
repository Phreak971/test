import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/units.dart';
import '../../data/models.dart';
import '../../l10n/app_localizations.dart';
import '../../state/nav_controller.dart';
import '../../state/providers.dart';
import '../hud.dart';

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
  return (use24 ? DateFormat.Hm() : DateFormat.jm()).format(at);
}

/// Bottom panel shown while previewing a route.
class RoutePreviewPanel extends ConsumerWidget {
  const RoutePreviewPanel({super.key, required this.state, required this.onClose});

  final NavPreview state;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final hud = ref.watch(hudProvider);
    final unit = ref.watch(settingsProvider.select((s) => s.unit));
    final r = state.route;

    Widget body;
    if (state.loading) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Center(child: CircularProgressIndicator(color: hud.accent)),
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
            SecondaryButton(hud: hud, label: l.retry, icon: Icons.refresh_rounded, onPressed: () => ref.read(navProvider.notifier).preview(state.dest)),
          ],
        ),
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_duration(context, r!.durationS), style: displayStyle(hud, 30, color: hud.accent)),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(formatDistance(r.distanceM, unit), style: TextStyle(color: hud.muted, fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('${l.arrival} ${_arrivalTime(context, r.durationS)}', style: TextStyle(color: hud.text, fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          PrimaryButton(
            hud: hud,
            label: l.startNow,
            icon: Icons.navigation_rounded,
            onPressed: () {
              HapticFeedback.mediumImpact();
              ref.read(navProvider.notifier).start();
            },
          ),
        ],
      );
    }

    return HudPanel(
      hud: hud,
      radius: hud.radius.clamp(12, 28),
      padding: const EdgeInsets.fromLTRB(18, 12, 10, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.routeTitle.toUpperCase(), style: displayStyle(hud, 12, weight: FontWeight.w600, color: hud.muted).copyWith(letterSpacing: 1.2)),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(text: l.fromMyLocation, style: TextStyle(color: hud.muted)),
                        const TextSpan(text: '  →  '),
                        TextSpan(text: state.dest.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      ]),
                      style: TextStyle(color: hud.text, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onClose,
                tooltip: l.close,
                icon: Icon(Icons.close_rounded, color: hud.muted),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(padding: const EdgeInsets.only(right: 8), child: body),
        ],
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

    return Semantics(
      liveRegion: true,
      label: '${parts.value} ${parts.unit} $street',
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
                ? Row(children: [
                    SizedBox(width: 26, height: 26, child: CircularProgressIndicator(color: hud.onAccent, strokeWidth: 3)),
                    const SizedBox(width: 14),
                    Text(l.rerouting, style: displayStyle(hud, 22, color: hud.onAccent)),
                  ])
                : Row(
                    children: [
                      Icon(maneuverIcon(step.kind), color: hud.onAccent, size: 52),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text.rich(
                              TextSpan(children: [
                                TextSpan(text: parts.value, style: displayStyle(hud, 32, color: hud.onAccent)),
                                TextSpan(text: ' ${parts.unit}', style: displayStyle(hud, 18, color: hud.onAccent)),
                              ]),
                            ),
                            if (street.isNotEmpty)
                              Text(street, style: TextStyle(color: hud.onAccent, fontSize: 18, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
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
                    Text('${l.thenLabel} ', style: TextStyle(color: hud.text, fontWeight: FontWeight.w600)),
                    Icon(maneuverIcon(p!.followingStep!.kind), color: hud.text, size: 22),
                  ],
                ),
              ),
            ),
        ],
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
                  Text(_arrivalTime(context, remS), style: displayStyle(hud, 26, color: hud.accent)),
                  Text(
                    '${_duration(context, remS)} · ${formatDistance(remM, settings.unit)}',
                    style: TextStyle(color: hud.muted, fontSize: 15, fontWeight: FontWeight.w600),
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
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: onEnd,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(hud.radius.clamp(6, 24))),
              ),
              child: Text(l.endRoute, style: displayStyle(hud, 16, color: Colors.white)),
            ),
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
          Icon(Icons.emoji_events_rounded, color: hud.accent, size: 44),
          const SizedBox(height: 6),
          Semantics(header: true, child: Text(l.arrivedTitle, style: displayStyle(hud, 24))),
          const SizedBox(height: 2),
          Text(dest.name, style: TextStyle(color: hud.muted, fontSize: 15), textAlign: TextAlign.center),
          Text(l.arrivedBody, style: TextStyle(color: hud.accent, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          PrimaryButton(hud: hud, label: l.done, onPressed: onDone),
        ],
      ),
    );
  }
}
