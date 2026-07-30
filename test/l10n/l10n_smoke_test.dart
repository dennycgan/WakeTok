import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/l10n/app_localizations.dart';

void main() {
  test('en smoke key loads', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(l10n.l10nSmoke, 'Localization OK');
  });

  test('zh_Hans smoke key loads', () async {
    final l10n = await AppLocalizations.delegate.load(
      const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    );
    expect(l10n.l10nSmoke, '本地化正常');
  });

  test('supportedLocales include en, zh, and zh_Hans', () {
    expect(
      AppLocalizations.supportedLocales,
      containsAll(<Locale>[
        const Locale('en'),
        const Locale('zh'),
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
      ]),
    );
  });
}
