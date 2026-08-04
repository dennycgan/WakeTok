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
}
