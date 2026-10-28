import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:overworld/core/geo.dart';
import 'package:overworld/core/map_link.dart';
import 'package:overworld/ui/hud.dart';
import 'package:overworld/ui/home/map_chrome.dart';
import 'package:overworld/ui/home/place_panel.dart';

import 'helpers.dart';

void main() {
  Future<void> pumpSheet(WidgetTester tester, {required VoidCallback onDismiss}) async {
    final env = await makeEnv();
    final c = await pumpApp(
      tester,
      env,
      Builder(
        builder: (context) => Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: MapSheet(
              hud: ProviderScope.containerOf(context).read(hudProvider),
              header: const SizedBox(height: 80, child: Text('HEADER')),
              details: const SizedBox(height: 200, child: Text('DETAILS')),
              onDismiss: onDismiss,
            ),
          ),
        ),
      ),
    );
    expect(c, isNotNull);
  }

  testWidgets('drag up expands, drag down collapses, then dismisses', (tester) async {
    var dismissed = 0;
    await pumpSheet(tester, onDismiss: () => dismissed++);
    expect(find.text('DETAILS'), findsNothing);

    await tester.drag(find.text('HEADER'), const Offset(0, -120));
    await tester.pumpAndSettle();
    expect(find.text('DETAILS'), findsOneWidget);

    await tester.drag(find.text('HEADER'), const Offset(0, 120));
    await tester.pumpAndSettle();
    expect(find.text('DETAILS'), findsNothing);
    expect(dismissed, 0);

    await tester.drag(find.text('HEADER'), const Offset(0, 120));
    await tester.pumpAndSettle();
    expect(dismissed, 1);
  });

  testWidgets('grabber toggles details and is labelled for screen readers', (tester) async {
    await pumpSheet(tester, onDismiss: () {});
    final handle = tester.ensureSemantics();
    await tester.tap(find.bySemanticsLabel('Show more'));
    await tester.pumpAndSettle();
    expect(find.text('DETAILS'), findsOneWidget);
    expect(find.bySemanticsLabel('Show less'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('place sheet offers the Maps-style actions', (tester) async {
    final env = await makeEnv();
    var dirs = 0, starts = 0;
    await pumpApp(
      tester,
      env,
      Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: PlacePanel(
            place: samplePlace,
            onClose: () {},
            onDirections: () => dirs++,
            onStart: () => starts++,
            onSave: () {},
            onEdit: (_) {},
          ),
        ),
      ),
    );
    for (final label in ['Directions', 'Start', 'Save', 'Share']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    await tester.tap(find.text('Directions'));
    await tester.tap(find.text('Start'));
    expect((dirs, starts), (1, 1));
    // Coordinates are in the expanded details.
    await tester.drag(find.text(samplePlace.name), const Offset(0, -150));
    await tester.pumpAndSettle();
    expect(find.text('Coordinates'), findsOneWidget);
  });

  testWidgets('share as: every option returns a link that points back to the place', (tester) async {
    final env = await makeEnv();
    String? picked;
    await pumpApp(
      tester,
      env,
      Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () async => picked = await Navigator.of(
                context,
              ).push<String>(MaterialPageRoute(builder: (_) => Scaffold(body: ShareAsSheet(place: samplePlace)))),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    for (final label in ['Overworld link', 'Google Maps link', 'Apple Maps link', 'OpenStreetMap link', 'Coordinates only']) {
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      final g = MapLinks.findInText(picked!);
      expect(g?.point, isNotNull, reason: label);
      expect(distanceM(g!.point!, samplePlace.location), lessThan(2), reason: label);
    }
  });
}

