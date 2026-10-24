import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:overworld/themes/map_theme.dart';
import 'package:overworld/themes/theme_catalog.dart';
import 'package:overworld/ui/hud.dart';

void main() {
  for (final t in themeCatalog) {
    for (final v in MapVariant.values) {
      test('HUD tokens are legible for ${t.id}/${v.name}', () {
        final h = Hud.of(t, v);
        final bg = h.panelOpaque.toARGB32();
        expect(contrastRatio(h.text.toARGB32(), bg), greaterThanOrEqualTo(4.5), reason: 'text');
        expect(contrastRatio(h.muted.toARGB32(), bg), greaterThanOrEqualTo(4.5), reason: 'muted');
        expect(contrastRatio(h.accentText.toARGB32(), bg), greaterThanOrEqualTo(4.5), reason: 'accent text');
        expect(contrastRatio(h.danger.toARGB32(), bg), greaterThanOrEqualTo(4.5), reason: 'danger');
        expect(contrastRatio(h.onAccent.toARGB32(), h.accent.toARGB32()), greaterThanOrEqualTo(4.5), reason: 'onAccent');
        expect(h.panel.a, greaterThanOrEqualTo(0.97));
      });
    }
  }

  test('onAccent picks the higher-contrast option', () {
    final h = Hud(panel: Colors.black, text: Colors.white, accent: const Color(0xFFFF8A1F), radius: 4, isDark: true);
    expect(h.onAccent, Colors.black);
  });
}
