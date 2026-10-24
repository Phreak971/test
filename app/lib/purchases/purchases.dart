import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Store product ids. Configure the same ids in App Store Connect / Play Console.
abstract final class ProductIds {
  static const weekly = 'overworld.premium.weekly';
  static const monthly = 'overworld.premium.monthly';
  static const yearly = 'overworld.premium.yearly';
  static const lifetime = 'overworld.unlock_all';

  static const subscriptions = {weekly, monthly, yearly};
  static const all = {weekly, monthly, yearly, lifetime};
}

enum PlanPeriod { weekly, monthly, yearly, lifetime }

class Plan {
  const Plan({required this.id, required this.period, required this.price, this.rawPrice, this.currency, this.trialDays});

  final String id;
  final PlanPeriod period;
  final String price;
  final double? rawPrice;
  final String? currency;

  /// Free-trial length when the store reports one (introductory offer).
  final int? trialDays;

  bool get hasTrial => (trialDays ?? 0) > 0;
}

enum PurchaseOutcome { purchased, restored, cancelled, pending, failed, nothingToRestore, unavailable }

class Entitlement {
  const Entitlement({this.premium = false, this.lifetime = false});

  final bool premium;
  final bool lifetime;

  @override
  bool operator ==(Object other) => other is Entitlement && other.premium == premium && other.lifetime == lifetime;

  @override
  int get hashCode => Object.hash(premium, lifetime);
}

abstract class PurchaseService {
  Stream<Entitlement> get entitlements;
  Future<bool> get available;
  Future<List<Plan>> loadPlans();
  Future<PurchaseOutcome> buy(Plan plan);
  Future<PurchaseOutcome> restore();
  void dispose();
}

PlanPeriod _periodFor(String id) => switch (id) {
  ProductIds.weekly => PlanPeriod.weekly,
  ProductIds.monthly => PlanPeriod.monthly,
  ProductIds.yearly => PlanPeriod.yearly,
  _ => PlanPeriod.lifetime,
};

/// StoreKit / Play Billing via `in_app_purchase`.
///
/// Note: production subscription expiry should be verified server-side
/// (App Store Server API / Play Developer API). Here entitlement is granted
/// from purchase/restore events and cached locally.
class StorePurchaseService implements PurchaseService {
  StorePurchaseService({InAppPurchase? iap}) : _iap = iap ?? InAppPurchase.instance {
    _sub = _iap.purchaseStream.listen(_onPurchases, onError: (Object e) => _completePending(PurchaseOutcome.failed));
  }

  final InAppPurchase _iap;
  late final StreamSubscription<List<PurchaseDetails>> _sub;
  final _ent = StreamController<Entitlement>.broadcast();
  final _products = <String, ProductDetails>{};
  Completer<PurchaseOutcome>? _pending;
  String? _pendingProduct;
  bool _restoring = false;
  bool _restoredAny = false;
  int _restoreEvents = 0;
  int _seenRestoreEvents = 0;
  int _quietTicks = 0;

  @override
  Stream<Entitlement> get entitlements => _ent.stream;

  @override
  Future<bool> get available => _iap.isAvailable();

  @override
  Future<List<Plan>> loadPlans() async {
    if (!await available) return const [];
    final res = await _iap.queryProductDetails(ProductIds.all);
    for (final p in res.productDetails) {
      _products[p.id] = p;
    }
    final plans =
        res.productDetails
            .map((p) => Plan(id: p.id, period: _periodFor(p.id), price: p.price, rawPrice: p.rawPrice, currency: p.currencyCode))
            .toList()
          ..sort((a, b) => a.period.index.compareTo(b.period.index));
    return plans;
  }

  @override
  Future<PurchaseOutcome> buy(Plan plan) async {
    final product = _products[plan.id];
    if (product == null) return PurchaseOutcome.unavailable;
    _pending?.complete(PurchaseOutcome.cancelled);
    final c = _pending = Completer<PurchaseOutcome>();
    _pendingProduct = plan.id;
    try {
      final ok = await _iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: product));
      if (!ok) {
        _clearPending();
        return PurchaseOutcome.failed;
      }
    } catch (_) {
      // e.g. PlatformException: product already owned / store busy.
      _clearPending();
      return PurchaseOutcome.failed;
    }
    return c.future.timeout(
      const Duration(minutes: 5),
      onTimeout: () {
        _clearPending();
        return PurchaseOutcome.pending;
      },
    );
  }

  void _clearPending() {
    _pending = null;
    _pendingProduct = null;
  }

  void _completePending(PurchaseOutcome o) {
    final c = _pending;
    _clearPending();
    if (c != null && !c.isCompleted) c.complete(o);
  }

  @override
  Future<PurchaseOutcome> restore() async {
    if (!await available) return PurchaseOutcome.unavailable;
    _restoring = true;
    _restoredAny = false;
    _restoreEvents = 0;
    _seenRestoreEvents = 0;
    _quietTicks = 0;
    try {
      await _iap.restorePurchases();
      // Restored purchases trickle in on the stream. Finish 1.5 s after the
      // last one, give up after 8 s with none, never wait beyond 15 s.
      // Count ticks rather than reading the clock so fake-time tests work.
      const tick = Duration(milliseconds: 250);
      var elapsed = 0;
      while (true) {
        await Future<void>.delayed(tick);
        elapsed++;
        if (_restoreEvents != _seenRestoreEvents) {
          _seenRestoreEvents = _restoreEvents;
          _quietTicks = 0;
        } else {
          _quietTicks++;
        }
        if (_restoreEvents > 0 && _quietTicks >= 6) break; // 1.5 s quiet
        if (_restoreEvents == 0 && elapsed >= 32) break; // 8 s, nothing
        if (elapsed >= 60) break; // 15 s cap
      }
    } catch (_) {
      return PurchaseOutcome.failed;
    } finally {
      _restoring = false;
    }
    return _restoredAny ? PurchaseOutcome.restored : PurchaseOutcome.nothingToRestore;
  }

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final p in list) {
      final matchesPending = _pendingProduct == null || p.productID == _pendingProduct;
      switch (p.status) {
        case PurchaseStatus.pending:
          // Ask to Buy / slow payment: tell the paywall now instead of
          // spinning for minutes.
          if (matchesPending) _completePending(PurchaseOutcome.pending);
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (ProductIds.all.contains(p.productID)) {
            _ent.add(Entitlement(premium: true, lifetime: p.productID == ProductIds.lifetime));
            if (p.status == PurchaseStatus.restored || _restoring) {
              _restoredAny = true;
              _restoreEvents++;
            }
            if (_pending != null && p.productID == _pendingProduct) {
              _completePending(p.status == PurchaseStatus.restored ? PurchaseOutcome.restored : PurchaseOutcome.purchased);
            }
          }
        case PurchaseStatus.error:
          if (matchesPending) _completePending(PurchaseOutcome.failed);
        case PurchaseStatus.canceled:
          if (matchesPending) _completePending(PurchaseOutcome.cancelled);
      }
      if (p.pendingCompletePurchase) {
        try {
          await _iap.completePurchase(p);
        } catch (_) {
          // The store will redeliver; keep processing the rest of the batch.
        }
      }
    }
  }

  @override
  void dispose() {
    _sub.cancel();
    _ent.close();
  }
}

/// In-memory store for web, tests and QA builds (`--dart-define=FAKE_STORE=true`).
class FakePurchaseService implements PurchaseService {
  FakePurchaseService({this.restorable = false});

  final _ent = StreamController<Entitlement>.broadcast();

  /// Whether [restore] finds a previous purchase.
  bool restorable;

  @override
  Stream<Entitlement> get entitlements => _ent.stream;

  @override
  Future<bool> get available async => true;

  @override
  Future<List<Plan>> loadPlans() async => const [
    Plan(id: ProductIds.weekly, period: PlanPeriod.weekly, price: '\$4.99', rawPrice: 4.99, currency: 'USD'),
    Plan(id: ProductIds.monthly, period: PlanPeriod.monthly, price: '\$7.99', rawPrice: 7.99, currency: 'USD'),
    Plan(id: ProductIds.yearly, period: PlanPeriod.yearly, price: '\$24.99', rawPrice: 24.99, currency: 'USD', trialDays: 3),
    Plan(id: ProductIds.lifetime, period: PlanPeriod.lifetime, price: '\$39.99', rawPrice: 39.99, currency: 'USD'),
  ];

  @override
  Future<PurchaseOutcome> buy(Plan plan) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    _ent.add(Entitlement(premium: true, lifetime: plan.period == PlanPeriod.lifetime));
    return PurchaseOutcome.purchased;
  }

  @override
  Future<PurchaseOutcome> restore() async {
    if (!restorable) return PurchaseOutcome.nothingToRestore;
    _ent.add(const Entitlement(premium: true));
    return PurchaseOutcome.restored;
  }

  @override
  void dispose() => _ent.close();
}

const _fakeStore = bool.fromEnvironment('FAKE_STORE');

PurchaseService createPurchaseService() => (kIsWeb || _fakeStore) ? FakePurchaseService() : StorePurchaseService();
