// QA: StorePurchaseService stream/completer handling against a scripted
// in_app_purchase backend. `// BUG:` tests are expected to fail until fixed.
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:overworld/purchases/purchases.dart';

class FakeIap implements InAppPurchase {
  final stream = StreamController<List<PurchaseDetails>>.broadcast();
  final completed = <String>[];
  Object? buyThrows;
  Object? completeThrows;
  int restoreCalls = 0;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => stream.stream;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) async => ProductDetailsResponse(
    productDetails: [
      for (final id in identifiers) ProductDetails(id: id, title: id, description: id, price: r'$1', rawPrice: 1, currencyCode: 'USD'),
    ],
    notFoundIDs: const [],
  );

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    if (buyThrows != null) throw buyThrows!;
    return true;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    if (completeThrows != null) throw completeThrows!;
    completed.add(purchase.productID);
  }

  @override
  Future<void> restorePurchases({String? applicationUserName}) async => restoreCalls++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  void emit(String productId, PurchaseStatus status, {bool needsComplete = true}) {
    stream.add([
      PurchaseDetails(
        productID: productId,
        verificationData: PurchaseVerificationData(localVerificationData: '', serverVerificationData: '', source: 'test'),
        transactionDate: '0',
        status: status,
      )..pendingCompletePurchase = needsComplete,
    ]);
  }
}

Future<(FakeIap, StorePurchaseService, Map<String, Plan>)> _setup() async {
  final iap = FakeIap();
  final svc = StorePurchaseService(iap: iap);
  final plans = {for (final p in await svc.loadPlans()) p.id: p};
  return (iap, svc, plans);
}

void main() {
  testWidgets('purchase grants entitlement, completes the transaction and resolves purchased', (tester) async {
    final (iap, svc, plans) = await _setup();
    final ents = <Entitlement>[];
    final sub = svc.entitlements.listen(ents.add);
    final f = svc.buy(plans[ProductIds.lifetime]!);
    await tester.pump();
    iap.emit(ProductIds.lifetime, PurchaseStatus.purchased);
    await tester.pump();
    expect(await f, PurchaseOutcome.purchased);
    expect(ents, [const Entitlement(premium: true, lifetime: true)]);
    expect(iap.completed, [ProductIds.lifetime]);
    unawaited(sub.cancel());
    svc.dispose();
  });

  testWidgets('cancel and error events resolve the pending purchase', (tester) async {
    final (iap, svc, plans) = await _setup();
    var f = svc.buy(plans[ProductIds.yearly]!);
    await tester.pump();
    iap.emit(ProductIds.yearly, PurchaseStatus.canceled);
    await tester.pump();
    expect(await f, PurchaseOutcome.cancelled);
    f = svc.buy(plans[ProductIds.yearly]!);
    await tester.pump();
    iap.emit(ProductIds.yearly, PurchaseStatus.error);
    await tester.pump();
    expect(await f, PurchaseOutcome.failed);
    svc.dispose();
  });

  testWidgets('loadPlans sorts weekly..lifetime', (tester) async {
    final (_, svc, plans) = await _setup();
    expect((await svc.loadPlans()).map((p) => p.period), PlanPeriod.values);
    expect(plans, hasLength(4));
    svc.dispose();
  });

  // BUG (P1): PurchaseStatus.pending (Ask to Buy, slow card, cash payment)
  // is ignored, so buy() keeps the paywall spinner up for the full 5-minute
  // timeout before reporting `pending`.
  testWidgets('a pending transaction is reported promptly', (tester) async {
    final (iap, svc, plans) = await _setup();
    PurchaseOutcome? outcome;
    unawaited(svc.buy(plans[ProductIds.monthly]!).then((o) => outcome = o));
    await tester.pump();
    iap.emit(ProductIds.monthly, PurchaseStatus.pending, needsComplete: false);
    await tester.pump(const Duration(seconds: 5));
    final after5s = outcome;
    await tester.pump(const Duration(minutes: 5)); // drain the timeout timer
    expect(after5s, PurchaseOutcome.pending, reason: 'still waiting after 5 s (resolved only after 5 min as $outcome)');
    svc.dispose();
  });

  // BUG (P1): buyNonConsumable() can throw PlatformException (e.g. item
  // already owned / store busy). buy() lets it escape and leaves `_pending`
  // set; PaywallScreen._buy has no try/catch so `_busy` stays true forever
  // (spinner never stops) and the error is unhandled.
  testWidgets('a throwing store call resolves to failed instead of throwing', (tester) async {
    final (iap, svc, plans) = await _setup();
    iap.buyThrows = PlatformException(code: 'storekit_duplicate_product_object');
    Object? error;
    PurchaseOutcome? outcome;
    try {
      outcome = await svc.buy(plans[ProductIds.weekly]!);
    } catch (e) {
      error = e;
    }
    expect(error, isNull);
    expect(outcome, PurchaseOutcome.failed);
    svc.dispose();
  });

  // BUG (P1): restore() waits a fixed 3 s; restored transactions that arrive
  // later (slow network / large history, common on Play) still grant
  // premium in the background but the user is told "nothing to restore".
  testWidgets('restore that answers after 3 s is not reported as nothing-to-restore', (tester) async {
    final (iap, svc, _) = await _setup();
    final ents = <Entitlement>[];
    final sub = svc.entitlements.listen(ents.add);
    PurchaseOutcome? outcome;
    unawaited(svc.restore().then((o) => outcome = o));
    await tester.pump(const Duration(seconds: 4));
    iap.emit(ProductIds.yearly, PurchaseStatus.restored);
    await tester.pump(const Duration(seconds: 10));
    expect(ents, isNotEmpty, reason: 'premium was granted');
    expect(outcome, isNot(PurchaseOutcome.nothingToRestore), reason: 'but the user was told nothing was restored');
    unawaited(sub.cancel());
    svc.dispose();
  });

  // BUG (P2): any purchased/restored event completes the pending buy, even
  // for a different product (e.g. a subscription renewal or a restore that
  // lands while the user is buying Lifetime). The paywall shows "Congrats"
  // and closes although Lifetime was not bought.
  testWidgets('an unrelated product event does not complete the pending purchase', (tester) async {
    final (iap, svc, plans) = await _setup();
    PurchaseOutcome? outcome;
    unawaited(svc.buy(plans[ProductIds.lifetime]!).then((o) => outcome = o));
    await tester.pump();
    iap.emit(ProductIds.weekly, PurchaseStatus.purchased); // renewal
    await tester.pump();
    final early = outcome;
    iap.emit(ProductIds.lifetime, PurchaseStatus.canceled);
    await tester.pump(const Duration(minutes: 6));
    expect(early, isNull, reason: 'lifetime purchase reported as $early by a weekly renewal');
    svc.dispose();
  });

  // BUG (P2): _onPurchases is an async stream callback; if completePurchase
  // throws, the error is unhandled (zone error -> crash report) and the
  // remaining items in the same batch are never processed.
  testWidgets('a throwing completePurchase does not escape as an unhandled error', (tester) async {
    final iap = FakeIap()..completeThrows = PlatformException(code: 'billing_unavailable');
    final errors = <Object>[];
    await runZonedGuarded(() async {
      final svc2 = StorePurchaseService(iap: iap);
      iap.emit(ProductIds.weekly, PurchaseStatus.purchased);
      await tester.pump();
      svc2.dispose();
    }, (e, _) => errors.add(e));
    expect(errors, isEmpty);
  });
}
