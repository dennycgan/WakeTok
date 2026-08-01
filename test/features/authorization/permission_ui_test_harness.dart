import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/authorization/photos_authorization_repository.dart';
import 'package:waketok/features/authorization/open_app_settings.dart';
import 'package:waketok/features/authorization/photos_access_gate.dart';
import 'package:waketok/features/authorization/photos_authorization_notifier.dart';
import 'package:waketok/l10n/app_localizations.dart';

class ControllablePhotosAuthorizationRepository
    implements PhotosAuthorizationRepository {
  ControllablePhotosAuthorizationRepository(this.status);

  PhotosAccess status;
  int requestCalls = 0;
  int presentCalls = 0;

  @override
  Future<PhotosAccess> currentStatus() async => status;

  @override
  Future<PhotosAccess> requestAccess() async {
    requestCalls += 1;
    status = PhotosAccess.full;
    return status;
  }

  @override
  Future<void> presentLimitedLibraryPicker() async {
    presentCalls += 1;
  }
}

Widget permissionUiHarness({
  required PhotosAuthorizationRepository repo,
  OpenAppSettings? openSettings,
  Locale? locale,
}) {
  return ProviderScope(
    overrides: [
      photosAuthorizationRepositoryProvider.overrideWithValue(repo),
      if (openSettings != null)
        openAppSettingsProvider.overrideWithValue(openSettings),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: waketokTheme(Brightness.light),
      darkTheme: waketokTheme(Brightness.dark),
      home: const PhotosAccessGate(),
    ),
  );
}
