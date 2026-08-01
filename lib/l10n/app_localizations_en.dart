// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get l10nSmoke => 'Localization OK';

  @override
  String get appTitle => 'WakeTok';

  @override
  String get permissionRequestTitle => 'Access your photo library';

  @override
  String get permissionRequestBody =>
      'WakeTok shows your photos and videos in a private, on-device feed. Your media never leaves this device.';

  @override
  String get permissionRequestContinue => 'Continue';

  @override
  String get permissionBlockedTitleDenied => 'Photo access is turned off';

  @override
  String get permissionBlockedTitleRestricted => 'Photo access is restricted';

  @override
  String get permissionBlockedBody =>
      'WakeTok needs photo library access to show your media. You can enable access in Settings.';

  @override
  String get permissionOpenSettings => 'Open Settings';

  @override
  String get limitedAccessBannerMessage =>
      'Showing only selected photos and videos. Album features and clips need full access.';

  @override
  String get limitedAccessManageSelection => 'Manage selection';

  @override
  String get libraryShellTitle => 'Library';

  @override
  String get libraryRowAll => 'All';

  @override
  String get libraryRowPhotos => 'Photos';

  @override
  String get libraryRowVideos => 'Videos';

  @override
  String get countsPending => '—';
}
