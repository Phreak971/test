import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config.dart';
import '../../l10n/app_localizations.dart';
import '../../purchases/purchases.dart';
import '../../state/providers.dart';
import '../../themes/theme_catalog.dart';
import '../home/places_sheets.dart' show adaptiveAction;
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
    PurchaseOutcome outcome;
    try {
      outcome = await ref.read(purchaseServiceProvider).buy(plan);
    } catch (_) {
      outcome = PurchaseOutcome.failed;
    }
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
            actions: [adaptiveAction(ctx, label: l.continueLabel, isDefault: true, onPressed: () => Navigator.of(ctx).pop())],
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
    PlanPeriod.yearly => p.hasTrial ? l.trialTerms(p.trialDays!, p.price) : l.billedYearly,
    PlanPeriod.lifetime => l.oneTimePurchase,
  };

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final hud = ref.watch(hudProvider);
    final plansAsync = ref.watch(plansProvider);
    final premium = ref.watch(entitlementProvider).premium;
    final mq = MediaQuery.of(context);

    final plans = plansAsync.asData?.value ?? const <Plan>[];
    final selectedId = plans.isEmpty
        ? null
        : (_selectedId ?? plans.firstWhere((p) => p.period == PlanPeriod.yearly, orElse: () => plans.first).id);

    return Scaffold(
      backgroundColor: hud.panel.withValues(alpha: 1),
      body: Stack(
        children: [
          // Collage of theme swatches as the hero.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: mq.size.height * 0.3,
            child: ExcludeSemantics(
              child: ShaderMask(
                shaderCallback: (r) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white, Colors.transparent],
                  stops: [0.5, 1],
                ).createShader(r),
                blendMode: BlendMode.dstIn,
                child: GridView.count(
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 4,
                  children: [for (final t in themeCatalog.take(12)) ThemeSwatch(theme: t, variant: t.baseVariant)],
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
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: ListView(
                        // Content begins where the swatch hero has faded out.
                        padding: EdgeInsets.fromLTRB(20, mq.size.height * 0.3 - 72, 20, 8),
                        children: [
                          Semantics(
                            header: true,
                            child: Text(l.paywallTitle, style: displayStyle(hud, 32), textAlign: TextAlign.center),
                          ),
                          const SizedBox(height: 14),
                          for (final f in [
                            (Icons.map_rounded, l.paywallFeatureMaps),
                            (Icons.record_voice_over_rounded, l.paywallFeatureVoices),
                            (Icons.directions_car_rounded, l.paywallFeatureCar),
                            (Icons.auto_awesome_rounded, l.paywallFeatureUpdates),
                          ])
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: Row(
                                children: [
                                  Icon(f.$1, color: hud.accentText),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      f.$2,
                                      style: TextStyle(color: hud.text, fontSize: 16, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 14),
                          if (premium)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Text(
                                l.proActive,
                                style: displayStyle(hud, 18, color: hud.accentText),
                                textAlign: TextAlign.center,
                              ),
                            )
                          else
                            plansAsync.when(
                              loading: () => Padding(
                                padding: const EdgeInsets.all(24),
                                child: Center(child: CircularProgressIndicator(color: hud.accentText)),
                              ),
                              error: (_, _) => Text(
                                l.storeUnavailable,
                                style: TextStyle(color: hud.muted),
                                textAlign: TextAlign.center,
                              ),
                              data: (plans) => plans.isEmpty
                                  ? Text(
                                      l.storeUnavailable,
                                      style: TextStyle(color: hud.muted),
                                      textAlign: TextAlign.center,
                                    )
                                  : Column(
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
                                      ],
                                    ),
                            ),
                          const SizedBox(height: 6),
                          Text(
                            l.autoRenew,
                            style: TextStyle(color: hud.muted, fontSize: 11),
                            textAlign: TextAlign.center,
                          ),
                          Wrap(
                            alignment: WrapAlignment.center,
                            children: [
                              TextButton(onPressed: () => restorePurchases(context, ref), child: Text(l.restore)),
                              TextButton(onPressed: () => launchUrl(AppConfig.termsUrl), child: Text(l.terms)),
                              TextButton(onPressed: () => launchUrl(AppConfig.privacyUrl), child: Text(l.privacy)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Pinned call to action within thumb reach.
                if (!premium && selectedId != null)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                      child: PrimaryButton(
                        hud: hud,
                        busy: _busy,
                        label: plans.firstWhere((p) => p.id == selectedId).hasTrial ? l.startFreeTrial : l.continueLabel,
                        onPressed: () => _buy(plans.firstWhere((p) => p.id == selectedId)),
                      ),
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
  const _PlanTile({
    required this.hud,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.selected,
    required this.onTap,
    this.badge,
  });

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
        checked: selected,
        inMutuallyExclusiveGroup: true,
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
                Icon(
                  selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                  color: selected ? hud.accentText : hud.muted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(title, style: displayStyle(hud, 17)),
                          if (badge != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: hud.accent, borderRadius: BorderRadius.circular(4)),
                              child: Text(
                                badge!,
                                style: TextStyle(color: hud.onAccent, fontSize: 11, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ],
                      ),
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
