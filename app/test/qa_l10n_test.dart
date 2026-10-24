// QA: locale coverage and fallbacks.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:overworld/l10n/app_localizations.dart';

void main() {
  test('every ARB has exactly the template keys and no empty values', () {
    Map<String, dynamic> load(String code) => jsonDecode(File('lib/l10n/app_$code.arb').readAsStringSync()) as Map<String, dynamic>;
    final en = load('en');
    final keys = en.keys.where((k) => !k.startsWith('@')).toSet();
    for (final code in ['de', 'es', 'fr', 'it', 'tr']) {
      final m = load(code);
      final k = m.keys.where((k) => !k.startsWith('@')).toSet();
      expect(keys.difference(k), isEmpty, reason: '$code missing');
      expect(k.difference(keys), isEmpty, reason: '$code extra');
      for (final key in k) {
        expect((m[key] as String).trim(), isNotEmpty, reason: '$code.$key');
        // Placeholders match the template.
        // ICU plural/select messages: only the argument name is a placeholder;
        // words inside the branches are translated text.
        Set<String?> names(String v) {
          final icu = RegExp(r'^\{(\w+),\s*(plural|select)').firstMatch(v);
          if (icu != null) return {icu[1]};
          return RegExp(r'\{(\w+)').allMatches(v).map((x) => x[1]).toSet();
        }

        final ph = names(en[key] as String);
        final ph2 = names(m[key] as String);
        expect(ph2, ph, reason: '$code.$key placeholders');
      }
    }
  });

  test('every supported locale loads; region variants resolve to the language', () {
    for (final l in L.supportedLocales) {
      expect(lookupL(l).localeName, l.languageCode);
      expect(lookupL(Locale(l.languageCode, 'XX')).localeName, l.languageCode);
    }
  });

  test('unsupported device locales fall back to a supported locale (MaterialApp resolution)', () {
    for (final device in const [Locale('pt', 'BR'), Locale('zh'), Locale('ar')]) {
      final resolved = basicLocaleListResolution([device], L.supportedLocales);
      expect(L.supportedLocales, contains(resolved));
      expect(() => lookupL(resolved), returnsNormally);
    }
  });
}
