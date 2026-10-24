import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:overworld/data/routing_service.dart';
import 'package:overworld/nav/navigation_engine.dart';
import 'package:overworld/state/nav_controller.dart';
import 'package:overworld/ui/home/place_panel.dart';
import 'package:overworld/ui/home/route_panels.dart';

import 'helpers.dart';

void main() {
  final route = parseOsrmRoute(jsonDecode(File('test/fixtures/osrm_berlin.json').readAsStringSync()) as Map<String, dynamic>);
  final progress = NavigationEngine(route).update(Fix(route.geometry.first, speedMps: 10));

  final panels = <String, Widget>{
    'place': PlacePanel(place: samplePlace, onClose: () {}, onDirections: () {}, onSave: () {}, onEdit: (_) {}),
    'preview': RoutePreviewPanel(
      state: NavPreview(dest: samplePlace, route: route),
      onClose: () {},
    ),
    'preview-error': RoutePreviewPanel(
      state: const NavPreview(dest: samplePlace, error: 'no_route'),
      onClose: () {},
    ),
    'navbar': NavBottomBar(
      state: NavActive(dest: samplePlace, route: route, progress: progress),
      onEnd: () {},
    ),
    'banner': ManeuverBanner(
      state: NavActive(dest: samplePlace, route: route, progress: progress),
    ),
    'banner-rerouting': ManeuverBanner(
      state: NavActive(dest: samplePlace, route: route, progress: progress, rerouting: true),
    ),
    'arrived': ArrivedPanel(dest: samplePlace, onDone: () {}),
  };

  for (final scale in [1.0, 1.3, 2.0]) {
    for (final size in const [Size(320, 568), Size(390, 844), Size(844, 390)]) {
      for (final e in panels.entries) {
        testWidgets('${e.key} fits at ${size.width.toInt()}x${size.height.toInt()} text x$scale', (tester) async {
          final env = await makeEnv();
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await pumpApp(
            tester,
            env,
            Scaffold(
              body: SafeArea(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(padding: const EdgeInsets.all(8), child: e.value),
                ),
              ),
            ),
            size: size,
            // Spinners never settle.
            settle: !e.key.contains('rerouting'),
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('maneuver banner announces the instruction once, with the direction', (tester) async {
    final env = await makeEnv();
    await pumpApp(
      tester,
      env,
      Scaffold(
        body: ManeuverBanner(
          state: NavActive(dest: samplePlace, route: route, progress: progress),
        ),
      ),
    );
    final handle = tester.ensureSemantics();
    final node = tester.getSemantics(find.byType(ManeuverBanner));
    final label = node.label;
    expect(label, isNot(isEmpty));
    expect(RegExp(r'turn|continue|bear|head|keep|take|merge|make|arrive', caseSensitive: false).hasMatch(label), isTrue, reason: label);
    handle.dispose();
  });
}
