import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/authorization/photos_authorization_repository.dart';
import 'package:waketok/features/authorization/photos_authorization_notifier.dart';
import 'package:waketok/l10n/app_localizations.dart';
import 'package:waketok/main.dart';

class _FakePhotosAuthorizationRepository
    implements PhotosAuthorizationRepository {
  @override
  Future<PhotosAccess> currentStatus() async => PhotosAccess.notDetermined;

  @override
  Future<PhotosAccess> requestAccess() async => PhotosAccess.notDetermined;

  @override
  Future<void> presentLimitedLibraryPicker() async {}
}

Widget _harness(Widget child) {
  return ProviderScope(
    overrides: [
      photosAuthorizationRepositoryProvider.overrideWithValue(
        _FakePhotosAuthorizationRepository(),
      ),
    ],
    child: child,
  );
}

void main() {
  testWidgets('T7 forced zh_Hans shows 本地化正常', (tester) async {
    await tester.pumpWidget(
      _harness(
        MaterialApp(
          locale:
              const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: waketokTheme(Brightness.light),
          home: const L10nSmokePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('本地化正常'), findsWidgets);
  });

  testWidgets('T8 forced en shows Localization OK', (tester) async {
    await tester.pumpWidget(
      _harness(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: waketokTheme(Brightness.light),
          home: const L10nSmokePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Localization OK'), findsWidgets);
  });

  testWidgets('WakeTokApp builds with l10n delegates', (tester) async {
    await tester.pumpWidget(_harness(const WakeTokApp()));
    await tester.pumpAndSettle();
    expect(find.byType(L10nSmokePage), findsOneWidget);
  });
}
