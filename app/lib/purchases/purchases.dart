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
  const Plan({required this.id, required this.period, required this.price, this.rawPrice, this.currency, this.hasTrial = false});

  final String id;
  final PlanPeriod period;
  final String price;
  final double? rawPrice;
  final String? currency;
  final bool hasTrial;
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
    _sub = _iap.purchaseStream.listen(_onPurchases, onError: (Object e) {
      _pending?.complete(PurchaseOutcome.failed);
      _pending = null;
    });
  }

  final InAppPurchase _iap;
  late final StreamSubscription<List<PurchaseDetails>> _sub;
  final _ent = StreamController<Entitlement>.broadcast();
  final _products = <String, ProductDetails>{};
  Completer<PurchaseOutcome>? _pending;
  bool _restoring = false;
  bool _restoredAny = false;

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
    final plans = res.productDetails
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
    final ok = await _iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: product));
    if (!ok) {
      _pending = null;
      return PurchaseOutcome.failed;
    }
    return c.future.timeout(const Duration(minutes: 5), onTimeout: () => PurchaseOutcome.pending);
  }

  @override
  Future<PurchaseOutcome> restore() async {
    if (!await available) return PurchaseOutcome.unavailable;
    _restoring = true;
    _restoredAny = false;
    await _iap.restorePurchases();
    // Restored purchases arrive on the stream; give the store a moment.
    await Future<void>.delayed(const Duration(seconds: 3));
    _restoring = false;
    return _restoredAny ? PurchaseOutcome.restored : PurchaseOutcome.nothingToRestore;
  }

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final p in list) {
      switch (p.status) {
        case PurchaseStatus.pending:
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (ProductIds.all.contains(p.productID)) {
            _ent.add(Entitlement(premium: true, lifetime: p.productID == ProductIds.lifetime));
            if (p.status == PurchaseStatus.restored || _restoring) _restoredAny = true;
            _pending?.complete(p.status == PurchaseStatus.restored ? PurchaseOutcome.restored : PurchaseOutcome.purchased);
            _pending = null;
          }
        case PurchaseStatus.error:
          _pending?.complete(PurchaseOutcome.failed);
          _pending = null;
        case PurchaseStatus.canceled:
          _pending?.complete(PurchaseOutcome.cancelled);
          _pending = null;
      }
      if (p.pendingCompletePurchase) await _iap.completePurchase(p);
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
        Plan(id: ProductIds.yearly, period: PlanPeriod.yearly, price: '\$24.99', rawPrice: 24.99, currency: 'USD', hasTrial: true),
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

PurchaseService createPurchaseService() =>
    (kIsWeb || _fakeStore) ? FakePurchaseService() : StorePurchaseService();
