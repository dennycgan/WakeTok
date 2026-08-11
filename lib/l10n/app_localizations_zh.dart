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

  @override
  String get sourceSmokeSectionTitle => 'Built-in sources (debug)';

  @override
  String get sourceResolveButton => 'Resolve selected';

  @override
  String sourceEstimatedCount(int count) {
    return 'estimatedCount: $count';
  }

  @override
  String get sourceEstimatedCountUnknown => 'estimatedCount: unknown';

  @override
  String get sourceListDiagnosticTitle => 'List diagnostic (debug)';

  @override
  String sourceListDiagnosticCounts(int builtIn, int album, int smart) {
    return 'built-in=$builtIn, userAlbum=$album, smartAlbum=$smart';
  }

  @override
  String sourceListDiagnosticSmartNames(String names) {
    return 'Smart albums: $names';
  }

  @override
  String get sourceListDiagnosticSmartNamesNone => 'Smart albums: (none)';

  @override
  String get sourceListDiagnosticUntitled => '(untitled)';

  @override
  String sourceResolvedLength(int count) {
    return 'resolved length: $count';
  }

  @override
  String get sourceCountMatch => 'match vs totals: OK';

  @override
  String get sourceCountMismatch => 'match vs totals: FAIL';

  @override
  String get sourceCountPending => 'match vs totals: —';

  @override
  String get sourceQuantileSectionTitle => 'All-only quantile sample (debug)';

  @override
  String get sourceQuantileRunButton => 'Run All quantile sample';

  @override
  String get sourceQuantileOnlyAllHint =>
      'Quantile sampling is All-only (Photos/Videos unsupported).';

  @override
  String sourceQuantileRow(
    int q,
    String id,
    String date,
    String align,
    String avail,
  ) {
    return 'q=$q id=$id date=$date align=$align avail=$avail';
  }

  @override
  String get sourceQuantileAlignOk => 'OK';

  @override
  String get sourceQuantileAlignFail => 'FAIL';

  @override
  String get sourceQuantileDateUnknown => 'nil';

  @override
  String get sourceNegativeSectionTitle => 'Negative pair probe (debug)';

  @override
  String get sourceProbeIllegalPairButton => 'Probe illegal pair';

  @override
  String get sourcePairMismatchError =>
      'Expected error: source reference unavailable.';

  @override
  String get sourcePairProbeUnexpected =>
      'Unexpected result from illegal pair probe.';

  @override
  String get sourceBusy => 'Working…';

  @override
  String get sourceSmokeOperationFailed =>
      'Built-in source smoke operation failed.';

  @override
  String sourceQuantileYearSpan(String years) {
    return 'year span (non-null dates): $years';
  }

  @override
  String get playbackProbeSectionTitle => 'Playback + image pipeline (debug)';

  @override
  String get playbackProbeLoadImage => 'Load first Photos still';

  @override
  String get playbackProbeLoadVideo => 'Load first Videos item';

  @override
  String get playbackProbePlay => 'Play';

  @override
  String get playbackProbePause => 'Pause';

  @override
  String get playbackProbeImageOk => 'Image temp file ready.';

  @override
  String get playbackProbeVideoReady => 'Video plan loaded; surface mounting…';

  @override
  String get playbackProbeSurfaceReady => 'Display surface ready (adopt).';

  @override
  String get playbackProbeNoAssets =>
      'No assets in the selected built-in source.';

  @override
  String get playbackProbeICloudOnly =>
      'iCloud-only on device; Cap 7.3 does not download.';

  @override
  String get playbackProbeFailed => 'Playback / display probe failed.';

  @override
  String get mainBrowsePoolsTab => 'Pools';

  @override
  String get mainBrowsePoolsComingSoon => 'Coming soon';

  @override
  String get mainBrowseNavBrowse => 'Browse';

  @override
  String get mainBrowseNavClips => 'Clips';

  @override
  String get mainBrowseNavAuto => 'Auto';

  @override
  String get mainBrowseNavSettings => 'Settings';

  @override
  String get mainBrowseFeedPlaceholder => 'Feed arrives in a later step.';

  @override
  String get mainBrowseFeedLoading => 'Loading library…';

  @override
  String get mainBrowseFeedEmpty => 'No items in this source.';

  @override
  String get mainBrowseFeedResolveFailed => 'Could not load this source.';

  @override
  String get mainBrowseFeedRetry => 'Retry';

  @override
  String get mainBrowseFeedICloudOnly =>
      'This item is iCloud-only on this device.';

  @override
  String get mainBrowseFeedMediaFailed => 'Could not display this item.';

  @override
  String get mainBrowseLiveBadge => 'LIVE';

  @override
  String get mainBrowseStubClipsBody => 'Clips — coming in a later capability.';

  @override
  String get mainBrowseStubAutoBody =>
      'Auto-play — coming in a later capability.';

  @override
  String get mainBrowseStubSettingsBody =>
      'Settings — coming in a later capability.';

  @override
  String get mainBrowseOpenLibrarySmokeDebug => 'Library smoke (debug)';

  @override
  String get mediaInfoRelativeToday => 'Today';

  @override
  String mediaInfoRelativeDaysAgo(String count) {
    return '$count days ago';
  }

  @override
  String mediaInfoRelativeMonthsAgo(String count) {
    return '$count months ago';
  }

  @override
  String mediaInfoRelativeYearsAgo(String count) {
    return '$count years ago';
  }

  @override
  String mediaInfoRelativeYearsMonthsAgo(String years, String months) {
    return '$years years $months months ago';
  }

  @override
  String mediaInfoExactDateTime(
    String year,
    String month,
    String day,
    String hour,
    String minute,
  ) {
    return '$year-$month-$day $hour:$minute';
  }

  @override
  String get mediaInfoLivePhoto => 'Live Photo';

  @override
  String mediaInfoFileSizeBytes(String count) {
    return '$count B';
  }

  @override
  String mediaInfoFileSizeKb(String count) {
    return '$count KB';
  }

  @override
  String mediaInfoFileSizeMb(String count) {
    return '$count MB';
  }

  @override
  String mediaInfoFileSizeGb(String count) {
    return '$count GB';
  }

  @override
  String mediaInfoCharacteristicsJoined(String live, String size) {
    return '$live · $size';
  }

  @override
  String get sharedMuteDebugSectionTitle => 'Shared mute (debug)';

  @override
  String get sharedMuteDebugSwitchLabel => 'Muted';
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

  @override
  String get sourceSmokeSectionTitle => '内置来源（调试）';

  @override
  String get sourceResolveButton => '解析当前来源';

  @override
  String sourceEstimatedCount(int count) {
    return 'estimatedCount：$count';
  }

  @override
  String get sourceEstimatedCountUnknown => 'estimatedCount：未知';

  @override
  String get sourceListDiagnosticTitle => '列表诊断（调试）';

  @override
  String sourceListDiagnosticCounts(int builtIn, int album, int smart) {
    return 'built-in=$builtIn, userAlbum=$album, smartAlbum=$smart';
  }

  @override
  String sourceListDiagnosticSmartNames(String names) {
    return 'Smart albums：$names';
  }

  @override
  String get sourceListDiagnosticSmartNamesNone => 'Smart albums：（无）';

  @override
  String get sourceListDiagnosticUntitled => '（无标题）';

  @override
  String sourceResolvedLength(int count) {
    return '解析长度：$count';
  }

  @override
  String get sourceCountMatch => '与 totals 比对：通过';

  @override
  String get sourceCountMismatch => '与 totals 比对：失败';

  @override
  String get sourceCountPending => '与 totals 比对：—';

  @override
  String get sourceQuantileSectionTitle => '仅 All 分位抽样（调试）';

  @override
  String get sourceQuantileRunButton => '运行 All 分位抽样';

  @override
  String get sourceQuantileOnlyAllHint => '分位抽样仅支持 All（Photos/Videos 不可用）。';

  @override
  String sourceQuantileRow(
    int q,
    String id,
    String date,
    String align,
    String avail,
  ) {
    return 'q=$q id=$id date=$date align=$align avail=$avail';
  }

  @override
  String get sourceQuantileAlignOk => '通过';

  @override
  String get sourceQuantileAlignFail => '失败';

  @override
  String get sourceQuantileDateUnknown => '空';

  @override
  String get sourceNegativeSectionTitle => '非法 pair 探针（调试）';

  @override
  String get sourceProbeIllegalPairButton => '探测非法 pair';

  @override
  String get sourcePairMismatchError => '符合预期的错误：来源引用不可用。';

  @override
  String get sourcePairProbeUnexpected => '非法 pair 探针出现意外结果。';

  @override
  String get sourceBusy => '处理中…';

  @override
  String get sourceSmokeOperationFailed => '内置来源调试操作失败。';

  @override
  String sourceQuantileYearSpan(String years) {
    return '年份跨度（非空日期）：$years';
  }

  @override
  String get playbackProbeSectionTitle => '播放与图像管线（调试）';

  @override
  String get playbackProbeLoadImage => '加载首张 Photos 静图';

  @override
  String get playbackProbeLoadVideo => '加载首个 Videos 项';

  @override
  String get playbackProbePlay => '播放';

  @override
  String get playbackProbePause => '暂停';

  @override
  String get playbackProbeImageOk => '图像临时文件已就绪。';

  @override
  String get playbackProbeVideoReady => '视频计划已加载；正在挂载表面…';

  @override
  String get playbackProbeSurfaceReady => '显示表面就绪（adopt）。';

  @override
  String get playbackProbeNoAssets => '所选内置来源没有资源。';

  @override
  String get playbackProbeICloudOnly => '设备上为仅 iCloud；Cap 7.3 不发起下载。';

  @override
  String get playbackProbeFailed => '播放 / 显示探针失败。';

  @override
  String get mainBrowsePoolsTab => '片库';

  @override
  String get mainBrowsePoolsComingSoon => '即将推出';

  @override
  String get mainBrowseNavBrowse => '浏览';

  @override
  String get mainBrowseNavClips => '切片';

  @override
  String get mainBrowseNavAuto => '自动播放';

  @override
  String get mainBrowseNavSettings => '设置';

  @override
  String get mainBrowseFeedPlaceholder => '信息流将在后续步骤加入。';

  @override
  String get mainBrowseFeedLoading => '正在加载图库…';

  @override
  String get mainBrowseFeedEmpty => '此来源没有内容。';

  @override
  String get mainBrowseFeedResolveFailed => '无法加载此来源。';

  @override
  String get mainBrowseFeedRetry => '重试';

  @override
  String get mainBrowseFeedICloudOnly => '此项目在本机仅为 iCloud。';

  @override
  String get mainBrowseFeedMediaFailed => '无法显示此项目。';

  @override
  String get mainBrowseLiveBadge => 'LIVE';

  @override
  String get mainBrowseStubClipsBody => '切片 — 将在后续能力提供。';

  @override
  String get mainBrowseStubAutoBody => '自动播放 — 将在后续能力提供。';

  @override
  String get mainBrowseStubSettingsBody => '设置 — 将在后续能力提供。';

  @override
  String get mainBrowseOpenLibrarySmokeDebug => '图库调试（debug）';

  @override
  String get mediaInfoRelativeToday => '今天';

  @override
  String mediaInfoRelativeDaysAgo(String count) {
    return '$count 天前';
  }

  @override
  String mediaInfoRelativeMonthsAgo(String count) {
    return '$count 个月前';
  }

  @override
  String mediaInfoRelativeYearsAgo(String count) {
    return '$count 年前';
  }

  @override
  String mediaInfoRelativeYearsMonthsAgo(String years, String months) {
    return '$years 年 $months 个月前';
  }

  @override
  String mediaInfoExactDateTime(
    String year,
    String month,
    String day,
    String hour,
    String minute,
  ) {
    return '$year-$month-$day $hour:$minute';
  }

  @override
  String get mediaInfoLivePhoto => '实况照片';

  @override
  String mediaInfoFileSizeBytes(String count) {
    return '$count B';
  }

  @override
  String mediaInfoFileSizeKb(String count) {
    return '$count KB';
  }

  @override
  String mediaInfoFileSizeMb(String count) {
    return '$count MB';
  }

  @override
  String mediaInfoFileSizeGb(String count) {
    return '$count GB';
  }

  @override
  String mediaInfoCharacteristicsJoined(String live, String size) {
    return '$live · $size';
  }

  @override
  String get sharedMuteDebugSectionTitle => '共享静音（调试）';

  @override
  String get sharedMuteDebugSwitchLabel => '已静音';
}
