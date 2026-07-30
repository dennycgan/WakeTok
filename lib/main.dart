import 'package:flutter/material.dart';
import 'package:waketok/l10n/app_localizations.dart';
import 'package:waketok/l10n/locale_resolution.dart';

void main() {
  runApp(const WakeTokApp());
}

/// Root app: l10n wired with preferred-locale-first resolution (ADR-U §10).
class WakeTokApp extends StatelessWidget {
  const WakeTokApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.l10nSmoke,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      localeListResolutionCallback: (locales, supportedLocales) {
        return resolveAppLocale(locales);
      },
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const L10nSmokePage(),
    );
  }
}

/// Minimal home surface for 4.4 smoke (ARB key visible).
class L10nSmokePage extends StatelessWidget {
  const L10nSmokePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(l10n.l10nSmoke),
      ),
      body: Center(
        child: Text(
          l10n.l10nSmoke,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
    );
  }
}
