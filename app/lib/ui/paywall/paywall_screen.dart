import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config.dart';
import '../../l10n/app_localizations.dart';
import '../../purchases/purchases.dart';
import '../../state/providers.dart';
import '../../themes/theme_catalog.dart';
import '../hud.dart';
import '../themes/theme_swatch.dart';

final plansProvider = FutureProvider.autoDispose<List<Plan>>((ref) => ref.read(purchaseServiceProvider).loadPlans());

/// Handles restore from any screen with consistent feedback.
Future<void> restorePurchases(BuildContext context, WidgetRef ref) async {
  final l = L.of(context);
  final toast = ref.read(toastProvider.notifier);
  final outcome = await ref.read(purchaseServiceProvider).restore();
  switch (outcome) {
    case PurchaseOutcome.restored:
      toast.show(l.restoreDone);
    case PurchaseOutcome.nothingToRestore:
      toast.show(l.restoreNone, kind: ToastKind.info);
    case PurchaseOutcome.unavailable:
      toast.show(l.storeUnavailable, kind: ToastKind.error);
    default:
      toast.show(l.somethingWrong, kind: ToastKind.error);
  }
}

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key, this.onClose});

  /// Used by onboarding to continue the flow instead of popping.
  final VoidCallback? onClose;

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  String? _selectedId;
  bool _busy = false;

  void _close() {
    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _buy(Plan plan) async {
    final l = L.of(context);
    setState(() => _busy = true);
    final outcome = await ref.read(purchaseServiceProvider).buy(plan);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (outcome) {
      case PurchaseOutcome.purchased:
      case PurchaseOutcome.restored:
        HapticFeedback.heavyImpact();
        await showAdaptiveDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog.adaptive(
            title: Text(l.purchaseSuccessTitle),
            content: Text(l.purchaseSuccessBody),
            actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(l.continueLabel))],
          ),
        );
        if (mounted) _close();
      case PurchaseOutcome.cancelled:
        break;
      case PurchaseOutcome.pending:
        ref.read(toastProvider.notifier).show(l.purchasePending, kind: ToastKind.info);
      case PurchaseOutcome.unavailable:
        ref.read(toastProvider.notifier).show(l.storeUnavailable, kind: ToastKind.error);
      case PurchaseOutcome.failed:
      case PurchaseOutcome.nothingToRestore:
        ref.read(toastProvider.notifier).show(l.purchaseFailed, kind: ToastKind.error);
    }
  }

  String _periodLabel(L l, PlanPeriod p) => switch (p) {
        PlanPeriod.weekly => l.planWeekly,
        PlanPeriod.monthly => l.planMonthly,
        PlanPeriod.yearly => l.planYearly,
        PlanPeriod.lifetime => l.planLifetime,
      };

  String _billing(L l, Plan p) => switch (p.period) {
        PlanPeriod.weekly => l.billedWeekly,
        PlanPeriod.monthly => l.billedMonthly,
        PlanPeriod.yearly => p.hasTrial ? '${l.freeTrial} · ${l.billedYearly}' : l.billedYearly,
        PlanPeriod.lifetime => l.oneTimePurchase,
      };

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final hud = ref.watch(hudProvider);
    final plansAsync = ref.watch(plansProvider);
    final premium = ref.watch(entitlementProvider).premium;
    final mq = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: hud.panel.withValues(alpha: 1),
      body: Stack(
        children: [
          // Collage of theme swatches as the hero.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: mq.size.height * 0.34,
            child: ExcludeSemantics(
              child: ShaderMask(
                shaderCallback: (r) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white, Colors.transparent],
                  stops: [0.55, 1],
                ).createShader(r),
                blendMode: BlendMode.dstIn,
                child: GridView.count(
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 4,
                  children: [
                    for (final t in themeCatalog.take(12)) ThemeSwatch(theme: t, variant: t.baseVariant),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: HudIconButton(hud: hud, icon: Icons.close_rounded, label: l.close, onPressed: _close),
                  ),
                ),
                const Spacer(),
                Expanded(
                  flex: 6,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      Semantics(header: true, child: Text(l.paywallTitle, style: displayStyle(hud, 32), textAlign: TextAlign.center)),
                      const SizedBox(height: 14),
                      for (final f in [
                        (Icons.map_rounded, l.paywallFeatureMaps),
                        (Icons.record_voice_over_rounded, l.paywallFeatureVoices),
                        (Icons.directions_car_rounded, l.paywallFeatureCar),
                        (Icons.auto_awesome_rounded, l.paywallFeatureUpdates),
                      ])
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(children: [
                            Icon(f.$1, color: hud.accent),
                            const SizedBox(width: 12),
                            Expanded(child: Text(f.$2, style: TextStyle(color: hud.text, fontSize: 16, fontWeight: FontWeight.w600))),
                          ]),
                        ),
                      const SizedBox(height: 14),
                      if (premium)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(l.proActive, style: displayStyle(hud, 18, color: hud.accent), textAlign: TextAlign.center),
                        )
                      else
                        plansAsync.when(
                          loading: () => Padding(padding: const EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: hud.accent))),
                          error: (_, _) => Text(l.storeUnavailable, style: TextStyle(color: hud.muted), textAlign: TextAlign.center),
                          data: (plans) {
                            if (plans.isEmpty) {
                              return Text(l.storeUnavailable, style: TextStyle(color: hud.muted), textAlign: TextAlign.center);
                            }
                            final selectedId = _selectedId ?? plans.firstWhere((p) => p.period == PlanPeriod.yearly, orElse: () => plans.first).id;
                            return Column(
                              children: [
                                for (final p in plans)
                                  _PlanTile(
                                    hud: hud,
                                    title: _periodLabel(l, p.period),
                                    subtitle: _billing(l, p),
                                    price: p.price,
                                    badge: p.period == PlanPeriod.yearly ? l.bestValue : null,
                                    selected: p.id == selectedId,
                                    onTap: () => setState(() => _selectedId = p.id),
                                  ),
                                const SizedBox(height: 12),
                                PrimaryButton(
                                  hud: hud,
                                  busy: _busy,
                                  label: l.continueLabel,
                                  onPressed: () => _buy(plans.firstWhere((p) => p.id == selectedId)),
                                ),
                              ],
                            );
                          },
                        ),
                      const SizedBox(height: 10),
                      Text(l.autoRenew, style: TextStyle(color: hud.muted, fontSize: 12), textAlign: TextAlign.center),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(onPressed: () => restorePurchases(context, ref), child: Text(l.restore)),
                          TextButton(onPressed: () => launchUrl(AppConfig.termsUrl), child: Text(l.terms)),
                          TextButton(onPressed: () => launchUrl(AppConfig.privacyUrl), child: Text(l.privacy)),
                        ],
                      ),
                      SizedBox(height: mq.padding.bottom),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const ToastHost(),
        ],
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({required this.hud, required this.title, required this.subtitle, required this.price, required this.selected, required this.onTap, this.badge});

  final Hud hud;
  final String title;
  final String subtitle;
  final String price;
  final String? badge;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Semantics(
        selected: selected,
        button: true,
        label: '$title, $price, $subtitle${badge != null ? ', $badge' : ''}',
        excludeSemantics: true,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: selected ? hud.accent.withValues(alpha: 0.14) : hud.text.withValues(alpha: 0.05),
              border: Border.all(color: selected ? hud.accent : hud.text.withValues(alpha: 0.14), width: selected ? 2 : 1),
            ),
            child: Row(
              children: [
                Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded, color: selected ? hud.accent : hud.muted),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(title, style: displayStyle(hud, 17)),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: hud.accent, borderRadius: BorderRadius.circular(4)),
                            child: Text(badge!, style: TextStyle(color: hud.onAccent, fontSize: 11, fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ]),
                      Text(subtitle, style: TextStyle(color: hud.muted, fontSize: 13)),
                    ],
                  ),
                ),
                Text(price, style: displayStyle(hud, 17)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

