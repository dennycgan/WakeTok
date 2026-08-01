// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get l10nSmoke => '本地化正常';

  @override
  String get appTitle => 'WakeTok';

  @override
  String get permissionRequestTitle => '访问你的照片图库';

  @override
  String get permissionRequestBody => 'WakeTok 在本机以私密方式展示你的照片和视频。媒体不会离开这台设备。';

  @override
  String get permissionRequestContinue => '继续';

  @override
  String get permissionBlockedTitleDenied => '未开启照片访问权限';

  @override
  String get permissionBlockedTitleRestricted => '照片访问受限';

  @override
  String get permissionBlockedBody => 'WakeTok 需要照片图库权限才能展示媒体。你可以在设置中开启访问。';

  @override
  String get permissionOpenSettings => '打开设置';

  @override
  String get limitedAccessBannerMessage => '当前仅显示你选择的照片和视频。相册与切片功能需要完全访问权限。';

  @override
  String get limitedAccessManageSelection => '管理所选内容';

  @override
  String get libraryShellTitle => '图库';

  @override
  String get libraryRowAll => '全部';

  @override
  String get libraryRowPhotos => '照片';

  @override
  String get libraryRowVideos => '视频';

  @override
  String get countsPending => '—';
}

/// The translations for Chinese, using the Han script (`zh_Hans`).
class AppLocalizationsZhHans extends AppLocalizationsZh {
  AppLocalizationsZhHans() : super('zh_Hans');

  @override
  String get l10nSmoke => '本地化正常';

  @override
  String get appTitle => 'WakeTok';

  @override
  String get permissionRequestTitle => '访问你的照片图库';

  @override
  String get permissionRequestBody => 'WakeTok 在本机以私密方式展示你的照片和视频。媒体不会离开这台设备。';

  @override
  String get permissionRequestContinue => '继续';

  @override
  String get permissionBlockedTitleDenied => '未开启照片访问权限';

  @override
  String get permissionBlockedTitleRestricted => '照片访问受限';

  @override
  String get permissionBlockedBody => 'WakeTok 需要照片图库权限才能展示媒体。你可以在设置中开启访问。';

  @override
  String get permissionOpenSettings => '打开设置';

  @override
  String get limitedAccessBannerMessage => '当前仅显示你选择的照片和视频。相册与切片功能需要完全访问权限。';

  @override
  String get limitedAccessManageSelection => '管理所选内容';

  @override
  String get libraryShellTitle => '图库';

  @override
  String get libraryRowAll => '全部';

  @override
  String get libraryRowPhotos => '照片';

  @override
  String get libraryRowVideos => '视频';

  @override
  String get countsPending => '—';
}
