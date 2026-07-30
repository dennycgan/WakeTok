import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/l10n/locale_resolution.dart';

void main() {
  const en = Locale('en');
  const zhHans = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans');

  test('T1 en / en_US → en', () {
    expect(resolveAppLocale(const <Locale>[Locale('en')]), en);
    expect(resolveAppLocale(const <Locale>[Locale('en', 'US')]), en);
  });

  test('T2 zh / zh_Hans / zh_CN → zh_Hans', () {
    expect(resolveAppLocale(const <Locale>[Locale('zh')]), zhHans);
    expect(resolveAppLocale(const <Locale>[zhHans]), zhHans);
    expect(resolveAppLocale(const <Locale>[Locale('zh', 'CN')]), zhHans);
  });

  test('T3 zh_Hant / zh_TW / zh_HK → zh_Hans', () {
    expect(
      resolveAppLocale(
        const <Locale>[
          Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
        ],
      ),
      zhHans,
    );
    expect(resolveAppLocale(const <Locale>[Locale('zh', 'TW')]), zhHans);
    expect(resolveAppLocale(const <Locale>[Locale('zh', 'HK')]), zhHans);
  });

  test('T4 non-zh → en', () {
    expect(resolveAppLocale(const <Locale>[Locale('ja')]), en);
    expect(resolveAppLocale(const <Locale>[Locale('fr')]), en);
  });

  test('T5 preferred [ja, zh_Hans] → en (first only; do not scan)', () {
    expect(
      resolveAppLocale(
        const <Locale>[
          Locale('ja'),
          Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
        ],
      ),
      en,
    );
  });

  test('T6 null / empty → en', () {
    expect(resolveAppLocale(null), en);
    expect(resolveAppLocale(const <Locale>[]), en);
  });
}
