import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _arb(String name) =>
    jsonDecode(File('lib/l10n/$name').readAsStringSync()) as Map<String, Object?>;

void main() {
  test('every interface string exists in English and Chinese, with the same placeholders', () {
    final en = _arb('app_en.arb'), zh = _arb('app_zh.arb');
    Set<String> keys(Map<String, Object?> arb) => {
      for (final k in arb.keys)
        if (!k.startsWith('@')) k,
    };
    expect(keys(zh), keys(en));
    final placeholder = RegExp(r'\{(\w+)\}');
    for (final key in keys(en)) {
      final e = en[key]! as String, z = zh[key]! as String;
      expect(z.trim(), isNotEmpty, reason: key);
      Set<String> names(String s) => {for (final m in placeholder.allMatches(s)) m[1]!};
      expect(names(z), names(e), reason: '$key uses different placeholders');
    }
  });
}
