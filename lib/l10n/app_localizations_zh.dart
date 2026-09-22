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
  String get permissionRequestBody => 'WakeTok 在本机以私密方式展示你的图片和视频。媒体不会离开这台设备。';

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
  String get limitedAccessBannerMessage => '当前仅显示你选择的图片和视频。相册与切片功能需要完全访问权限。';

  @override
  String get limitedAccessManageSelection => '管理所选内容';

  @override
  String get libraryShellTitle => '图库';

  @override
  String get libraryRowAll => '全部';

  @override
  String get libraryRowPhotos => '图片';

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
  String get sourceAlbumResolveSectionTitle => 'Album / Smart resolve (debug)';

  @override
  String get sourceResolveFirstUserAlbum => 'Resolve first User Album';

  @override
  String get sourceResolveFirstSmartAlbum => 'Resolve first Smart Album';

  @override
  String get sourceProbeCachedAlbumResolve => 'Probe cached album resolve';

  @override
  String get sourceAlbumResolveNoUserAlbum =>
      'No User Album in list (Full Access required).';

  @override
  String get sourceAlbumResolveNoSmartAlbum =>
      'No Smart Album in list (Full Access required).';

  @override
  String get sourceAlbumResolveNoCache =>
      'Resolve a User Album under Full Access first.';

  @override
  String sourceAlbumResolvedLength(int count, String name) {
    return 'album resolved length: $count ($name)';
  }

  @override
  String get sourceAlbumResolveUnauthorized =>
      'Expected unauthorized (Limited / Album).';

  @override
  String sourceAlbumResolveCacheLoaded(String name) {
    return 'Cached User Album for Limited probe: $name';
  }

  @override
  String get sourceAlbumResolveFailed => 'Album / Smart resolve probe failed.';

  @override
  String get sourcePoolProbeSectionTitle => 'Pool resolve (debug)';

  @override
  String get sourcePoolProbeButton => 'Resolve pool (Photos + All)';

  @override
  String sourcePoolProbeCoalesced(int count) {
    return 'coalesced=$count';
  }

  @override
  String sourcePoolProbeStatus(
    String kind,
    String id,
    String availability,
    int raw,
    int contrib,
  ) {
    return '$kind:$id $availability raw=$raw contrib=$contrib';
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
  String get playbackProbeFailed => 'Playback / display probe failed.';

  @override
  String get mainBrowseTempPoolChip => 'Temp Pool';

  @override
  String mainBrowseBuiltInWhileEphemeralSemantics(String builtInLabel) {
    return '$builtInLabel. Currently browsing Temp Pool.';
  }

  @override
  String mainBrowseBuiltInWhileSavedPoolSemantics(
    String builtInLabel,
    String savedPoolName,
  ) {
    return '$builtInLabel. Currently browsing $savedPoolName.';
  }

  @override
  String get mainBrowseBuiltInMenu => 'Built-in';

  @override
  String get mainBrowseSavedPoolsMenu => 'Saved pools';

  @override
  String get mainBrowseCreatePool => 'Create Pool';

  @override
  String get mainBrowseSavedPlaceholderEmpty => 'No saved pools yet';

  @override
  String get mainBrowseCompositionPeekTitle => 'Sources in this pool';

  @override
  String mainBrowseSavedPoolSourcesTitle(String name) {
    return 'Sources in “$name”';
  }

  @override
  String mainBrowseSavedPoolAlreadyBrowsing(String name) {
    return 'You\'re already browsing “$name”.';
  }

  @override
  String get mainBrowseCompositionPeekUnavailable => 'Unavailable';

  @override
  String get mainBrowseCompositionPeekRemovedFromPhotos =>
      'Removed from Photos';

  @override
  String get mainBrowseCompositionPeekRequiresFullAccess =>
      'Requires Full Access';

  @override
  String get mainBrowseCreatePoolRequiresFullAccess => 'Requires Full Access';

  @override
  String get mainBrowseCompositionPeekUnknownSource => 'Source';

  @override
  String get mainBrowseBuildPoolScaffoldTitle => 'Build a Pool';

  @override
  String get mainBrowseBuildPoolScaffoldBody =>
      'Pick albums and sources here in a later step. For now, go back to Browse.';

  @override
  String get mainBrowseBuildPoolSectionBuiltIn => 'Built-in';

  @override
  String get mainBrowseBuildPoolSectionAlbums => 'My Albums';

  @override
  String get mainBrowseBuildPoolSectionSmartAlbums => 'System Albums';

  @override
  String get mainBrowseBuildPoolSmartCatalogLoading => 'Loading system albums…';

  @override
  String get mainBrowseBuildPoolSmartCatalogFailed =>
      'Could not load system albums.';

  @override
  String get smartAlbumFavorites => 'Favorites';

  @override
  String get smartAlbumLivePhotos => 'Live Photos';

  @override
  String get smartAlbumScreenshots => 'Screenshots';

  @override
  String get smartAlbumAnimated => 'Animated';

  @override
  String get smartAlbumSelfies => 'Selfies';

  @override
  String get smartAlbumVideos => 'Videos';

  @override
  String get smartAlbumScreenRecordings => 'Screen Recordings';

  @override
  String get smartAlbumPanoramas => 'Panoramas';

  @override
  String get smartAlbumTimelapse => 'Time-lapse';

  @override
  String get smartAlbumBursts => 'Bursts';

  @override
  String get smartAlbumSlomo => 'Slo-mo';

  @override
  String get smartAlbumPortrait => 'Portrait';

  @override
  String get smartAlbumLongExposure => 'Long Exposure';

  @override
  String get smartAlbumRaw => 'RAW';

  @override
  String get smartAlbumCinematic => 'Cinematic';

  @override
  String get smartAlbumSpatial => 'Spatial';

  @override
  String get smartAlbumDualCapture => 'Dual Capture';

  @override
  String mainBrowseBuildPoolSelectedHeading(int count) {
    return 'Selected ($count/30)';
  }

  @override
  String get mainBrowseBuildPoolStart => 'Start browsing';

  @override
  String get mainBrowseBuildPoolSave => 'Save';

  @override
  String get mainBrowseBuildPoolSaveSuccess => 'Saved.';

  @override
  String get mainBrowseBuildPoolSaveAndBrowse => 'Save & browse';

  @override
  String get mainBrowseBuildPoolBrowseWithoutSaving => 'Browse without saving';

  @override
  String get mainBrowseSavedPoolNamingTitle => 'Name this pool';

  @override
  String get mainBrowseSavedPoolNamingHint => 'Name';

  @override
  String get mainBrowseSavedPoolNamingConfirm => 'Save';

  @override
  String get mainBrowseSavedPoolNamingCancel => 'Cancel';

  @override
  String get mainBrowseSavedPoolNamingEmpty => 'Enter a name.';

  @override
  String get mainBrowseSavedPoolNamingDuplicate => 'This name is already used.';

  @override
  String get mainBrowseSavedPoolNamingTooLong => 'Name is too long.';

  @override
  String mainBrowseSavedPoolNamingDuplicateRecipe(String name) {
    return 'You already have a pool with these sources — “$name”.';
  }

  @override
  String get mainBrowseSavedPoolCapacityTitle => 'Saved pools full';

  @override
  String get mainBrowseSavedPoolCapacityBody =>
      'You can save up to 10 pools. Delete one from Saved pools, then try again.';

  @override
  String get mainBrowseSavedPoolCapacityConfirm => 'OK';

  @override
  String get mainBrowseCompositionPeekSave => 'Save this pool';

  @override
  String get mainBrowseSavedPoolRowInfo => 'Info';

  @override
  String get mainBrowseSavedPoolInfoClose => 'OK';

  @override
  String get mainBrowseSavedPoolRowRename => 'Rename';

  @override
  String get mainBrowseSavedPoolRowDelete => 'Delete';

  @override
  String get mainBrowseSavedPoolDeleteTitle => 'Delete this pool?';

  @override
  String mainBrowseSavedPoolDeleteBody(String name) {
    return 'Delete “$name”? This cannot be undone.';
  }

  @override
  String get mainBrowseSavedPoolDeleteConfirm => 'Delete';

  @override
  String get mainBrowseSavedPoolDeleteCancel => 'Cancel';

  @override
  String get mainBrowseBuildPoolCatalogLoading => 'Loading sources…';

  @override
  String get mainBrowseBuildPoolCatalogFailed =>
      'Could not load the source list.';

  @override
  String get mainBrowseBuildPoolEmptySelected =>
      'Select at least one source to start.';

  @override
  String get mainBrowseBuildPoolCatalogEmpty => 'No albums available.';

  @override
  String get mainBrowseNavBrowse => 'Browse';

  @override
  String get mainBrowseNavSettings => 'Settings';

  @override
  String get mainBrowseOrderNewest => 'New first';

  @override
  String get mainBrowseOrderOldest => 'Old first';

  @override
  String get mainBrowseOrderShuffle => 'Shuffle';

  @override
  String get mainBrowseOrderSlotSemantics =>
      'Browse order. Opens browse order options.';

  @override
  String get mainBrowseOrderSheetTitle => 'Browse Order';

  @override
  String get mainBrowseOrderSheetNewest => 'Newest → Oldest';

  @override
  String get mainBrowseOrderSheetOldest => 'Oldest → Newest';

  @override
  String get mainBrowseOrderSheetShuffle => 'Shuffle';

  @override
  String get mainBrowseOrderSheetConfirm => 'Confirm';

  @override
  String get mainBrowseOrderSheetCancel => 'Cancel';

  @override
  String get mainBrowseFeedPlaceholder => 'Feed arrives in a later step.';

  @override
  String get mainBrowseFeedLoading => 'Loading library…';

  @override
  String get mainBrowseFeedEmpty => 'No items in this source.';

  @override
  String get mainBrowseNewRoundToast => 'You\'ve seen it all — starting over';

  @override
  String get mainBrowseFeedResolveFailed => 'Could not load this source.';

  @override
  String get mainBrowseFeedRetry => 'Retry';

  @override
  String get mainBrowseFeedMediaFailed => 'Could not display this item.';

  @override
  String get mainBrowseFeedNetworkFailed =>
      'Could not load. Allow wireless data, then retry.';

  @override
  String get mainBrowseFeedUnavailable => 'This item is unavailable.';

  @override
  String get mainBrowseFeedLayer1Loading => 'Loading item';

  @override
  String get mainBrowseFeedLayer2Reassure => 'Still loading';

  @override
  String get mainBrowseFeedLayer3Loading => 'Loading full quality';

  @override
  String get mainBrowseFeedLiveLoading => 'Loading Live Photo';

  @override
  String get mainBrowseFeedDownloadFailed => 'Could not download this item.';

  @override
  String get mainBrowseLiveBadge => 'LIVE';

  @override
  String get mainBrowseMagnificationReset => 'Reset';

  @override
  String get mainBrowseStubSettingsBody =>
      'Settings — coming in a later capability.';

  @override
  String get mainBrowseOpenLibrarySmokeDebug => 'Library smoke (debug)';

  @override
  String get cap27L1StallProbeSectionTitle => 'L1-stall probe';

  @override
  String get cap27L1StallProbeBlurb =>
      'Debug/Profile only. Writes Documents/cap27_l1_stall_probe.log for debt 478 (non-deviceLocal / iCloud remount L1 stick). When stuck on Layer 1 after remount: tap Mark stuck, swipe away then back, tap Mark healed.';

  @override
  String get cap27L1StallProbeMarkStuck => 'Mark stuck (L1 stall now)';

  @override
  String get cap27L1StallProbeMarkHealed => 'Mark healed (after swipe back)';

  @override
  String get cap28LiveProbeSectionTitle => 'Cap 28 live probe';

  @override
  String get cap28LiveProbeBlurb =>
      'Debug/Profile only. Writes Documents/wtlive.log for Settings leave/return keep diagnosis. Clear before a soak; Mark black / Mark OK after each return.';

  @override
  String get cap28LiveProbeClear => 'Clear wtlive.log';

  @override
  String get cap28LiveProbeMarkBlack => 'Mark black frame (this return)';

  @override
  String get cap28LiveProbeMarkOk => 'Mark return OK';

  @override
  String get mainBrowseVideoTapToPlay => 'Play video';

  @override
  String get mainBrowseVideoTapToPause => 'Pause video';

  @override
  String get mediaInfoRelativeWithin3Days => 'Within the past 3 days';

  @override
  String get mediaInfoRelativeWithinWeek => 'Within the past week';

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
  String mediaInfoExactDateApprox(String year, String month, String day) {
    return '~ $year-$month-$day';
  }

  @override
  String get mediaInfoLivePhoto => 'Live Photo';

  @override
  String get mediaInfoAnimated => 'Animated';

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

  @override
  String get cap19AlbumMutationProbeSectionTitle =>
      'Cap 19 Album Mutation Probe (debug)';

  @override
  String cap19WaketokAlbumKvLabel(String id) {
    return 'WakeTok album KV: $id';
  }

  @override
  String get cap19ProbeSampleAssetIdLabel => 'Sample PHAsset localIdentifier';

  @override
  String get cap19ProbeUseFirstAllAssetId => 'Use first All asset id';

  @override
  String get cap19ProbeLBootCreate => 'L-BOOT: Create \"WakeTok\" (no list)';

  @override
  String get cap19ProbeLBootKvShow => 'L-BOOT-KV: Show cached id';

  @override
  String get cap19ProbeLAppend => 'L-APPEND: Add sample to WakeTok album';

  @override
  String get cap19ProbeFullD1Smoke => 'Full: D1 KV→list find→create smoke';

  @override
  String get cap19ProbeClearKv => 'Clear WakeTok probe KV';

  @override
  String cap19ProductAlbumKvLabel(String id) {
    return 'Product WakeTok album KV: $id';
  }

  @override
  String get cap19ProbeProductBootstrap => 'Product: D1 bootstrap';

  @override
  String get cap19ProbeClearProductKv => 'Clear product WakeTok KV';

  @override
  String get cap19EntryIconSemantics => 'Add to album actions';

  @override
  String get cap19PanelTitle => 'Actions';

  @override
  String get cap19PanelAddToAlbumTitle => 'Add to Album';

  @override
  String get cap19PanelAddToAlbumLimitedMessage =>
      'Favorites and albums need full Photos access. Open Settings to allow access to all photos.';

  @override
  String get cap19PanelAddToAlbumFullPlaceholder =>
      'Album picker arrives in a later update.';

  @override
  String get cap19PanelAddToAlbumEmpty => 'No albums you can add to.';

  @override
  String get cap19PanelAddToAlbumListError =>
      'Couldn\'t load albums. Try again.';

  @override
  String get cap19PanelAddToAlbumRetry => 'Retry';

  @override
  String cap19PanelAddToAlbumSuccess(String albumName) {
    return 'Added to $albumName';
  }

  @override
  String get cap19PanelAddToAlbumError => 'Couldn\'t add to album. Try again.';

  @override
  String get cap19PanelFavoritesSectionTitle => 'Quick action';

  @override
  String get cap19PanelAlbumsSectionTitle => 'Albums';

  @override
  String get cap19PanelAddToFavorites => 'Add to Favorites';

  @override
  String get cap19PanelRemoveFromFavorites => 'Favorited — Remove';

  @override
  String get cap19PanelFavoritesAddedSuccess => 'Added to Favorites';

  @override
  String get cap19PanelFavoritesRemovedSuccess => 'Removed from Favorites';

  @override
  String get cap19PanelFavoritesError =>
      'Couldn\'t update Favorites. Try again.';

  @override
  String get cap19CurrentMediaNotReady => 'Media isn\'t ready yet.';

  @override
  String get stillInLibraryUnavailableTitle => 'This action isn\'t available';

  @override
  String get stillInLibraryUnavailableBody =>
      'It\'s no longer in your Photos library.';

  @override
  String get stillInLibraryUnavailableConfirm => 'OK';

  @override
  String get cap19LeftSwipeGuideTitle => 'Swipe left to add to WakeTok';

  @override
  String get cap19LeftSwipeGuideSubtitle =>
      'Saves it to your WakeTok album as a bookmark for later in Photos — nothing is moved or deleted';

  @override
  String get cap19LeftSwipeAppendSuccess => 'Added to WakeTok';

  @override
  String get cap19LeftSwipeAppendError =>
      'Couldn\'t add to WakeTok. Try again.';

  @override
  String get cap19LeftSwipeDragHintContinue =>
      'Keep swiping left · Add to your WakeTok album as a mark';

  @override
  String get cap19LeftSwipeDragHintArmed =>
      'Add to your WakeTok album · for later';

  @override
  String get cap19LeftSwipeAlreadyInAlbum => 'Already in your WakeTok album';

  @override
  String get cap19SettingsGesturesSectionTitle => 'Gestures';

  @override
  String get cap19SettingsLeftSwipeAddTitle => 'Swipe left to add to WakeTok';

  @override
  String get cap19SettingsLeftSwipeAddSubtitle =>
      'Adds the current item to your WakeTok album';

  @override
  String get cap19SettingsLeftSwipeGuideTitle => 'Show left-swipe tip';

  @override
  String get cap19SettingsLeftSwipeGuideSubtitle =>
      'Once per launch when Browse is ready';

  @override
  String get browseSettingsSectionTitle => 'Browse notices';

  @override
  String get browseSettingsNewRoundToastTitle => 'Starting-over notice';

  @override
  String get browseSettingsNewRoundToastSubtitle =>
      'When you finish browsing the whole list and it starts over, a short message appears near the top of Browse for about 1.5 seconds. Swipe away and it disappears right away.';

  @override
  String get cap24MoreEntryIconSemantics => 'More actions';

  @override
  String get cap24SoftDeleteSheetDelete => 'Delete';

  @override
  String get cap24MoreSheetFileSizeTitle => 'File size';

  @override
  String get cap24MoreSheetSavedTimeTitle => 'Saved time';

  @override
  String get cap24MoreSheetUnavailableValue => '—';

  @override
  String get cap24SoftDeleteSheetMinuteTimezoneNote =>
      'This is the finest time resolution WakeTok can show here for this item. Time zone differences may still shift it by a few hours; in extreme cases, even the date may not match the date on Browse (marked with ~). Because time can be stored differently in the file and in the Photos library, and may be affected by your current time zone, neither is guaranteed to match the exact moment this item was created or saved.';

  @override
  String get cap24SoftDeleteSheetMinuteTimezoneInfoSemantics =>
      'More about this time';

  @override
  String cap24SoftDeleteSheetExactMinute(
    String year,
    String month,
    String day,
    String hour,
    String minute,
    String second,
  ) {
    return '$year-$month-$day $hour:$minute:$second';
  }

  @override
  String cap24SoftDeleteSheetExactMinuteNoSeconds(
    String year,
    String month,
    String day,
    String hour,
    String minute,
  ) {
    return '$year-$month-$day $hour:$minute';
  }

  @override
  String cap24SoftDeleteSheetExactMinuteLibrary(
    String year,
    String month,
    String day,
    String hour,
    String minute,
  ) {
    return '$year-$month-$day $hour:$minute';
  }

  @override
  String get cap24SoftDeleteFailed => 'Couldn\'t delete. Try again.';

  @override
  String get cap25ShareEntryIconSemantics => 'Share';

  @override
  String get cap25ShareFailed => 'Couldn\'t share. Try again.';
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
  String get permissionRequestBody => 'WakeTok 在本机以私密方式展示你的图片和视频。媒体不会离开这台设备。';

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
  String get limitedAccessBannerMessage => '当前仅显示你选择的图片和视频。相册与切片功能需要完全访问权限。';

  @override
  String get limitedAccessManageSelection => '管理所选内容';

  @override
  String get libraryShellTitle => '图库';

  @override
  String get libraryRowAll => '全部';

  @override
  String get libraryRowPhotos => '图片';

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
  String get sourceAlbumResolveSectionTitle => '相册 / Smart 解析（调试）';

  @override
  String get sourceResolveFirstUserAlbum => '解析首个 User Album';

  @override
  String get sourceResolveFirstSmartAlbum => '解析首个 Smart Album';

  @override
  String get sourceProbeCachedAlbumResolve => '探测缓存相册解析';

  @override
  String get sourceAlbumResolveNoUserAlbum => '列表中无 User Album（需要完全访问权限）。';

  @override
  String get sourceAlbumResolveNoSmartAlbum => '列表中无 Smart Album（需要完全访问权限）。';

  @override
  String get sourceAlbumResolveNoCache => '请先在完全访问下解析一次 User Album。';

  @override
  String sourceAlbumResolvedLength(int count, String name) {
    return '相册解析长度：$count（$name）';
  }

  @override
  String get sourceAlbumResolveUnauthorized =>
      '符合预期：unauthorized（Limited / Album）。';

  @override
  String sourceAlbumResolveCacheLoaded(String name) {
    return '已加载 Limited 探针缓存 User Album：$name';
  }

  @override
  String get sourceAlbumResolveFailed => '相册 / Smart 解析探针失败。';

  @override
  String get sourcePoolProbeSectionTitle => 'Pool 解析（调试）';

  @override
  String get sourcePoolProbeButton => '解析 Pool（Photos + All）';

  @override
  String sourcePoolProbeCoalesced(int count) {
    return 'coalesced=$count';
  }

  @override
  String sourcePoolProbeStatus(
    String kind,
    String id,
    String availability,
    int raw,
    int contrib,
  ) {
    return '$kind:$id $availability raw=$raw contrib=$contrib';
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
  String get playbackProbeLoadImage => '加载首张图片静图';

  @override
  String get playbackProbeLoadVideo => '加载首个视频项';

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
  String get playbackProbeFailed => '播放 / 显示探针失败。';

  @override
  String get mainBrowseTempPoolChip => '临时片库';

  @override
  String mainBrowseBuiltInWhileEphemeralSemantics(String builtInLabel) {
    return '$builtInLabel。当前正在刷临时片库。';
  }

  @override
  String mainBrowseBuiltInWhileSavedPoolSemantics(
    String builtInLabel,
    String savedPoolName,
  ) {
    return '$builtInLabel。当前正在刷$savedPoolName。';
  }

  @override
  String get mainBrowseBuiltInMenu => '内置';

  @override
  String get mainBrowseSavedPoolsMenu => '已保存';

  @override
  String get mainBrowseCreatePool => '创建片库';

  @override
  String get mainBrowseSavedPlaceholderEmpty => '还没有已保存的片库';

  @override
  String get mainBrowseCompositionPeekTitle => '此片库中的来源';

  @override
  String mainBrowseSavedPoolSourcesTitle(String name) {
    return '「$name」中的来源';
  }

  @override
  String mainBrowseSavedPoolAlreadyBrowsing(String name) {
    return '当前刷的就是这个片库。';
  }

  @override
  String get mainBrowseCompositionPeekUnavailable => '不可用';

  @override
  String get mainBrowseCompositionPeekRemovedFromPhotos => '已在系统中删除';

  @override
  String get mainBrowseCompositionPeekRequiresFullAccess => '需要完全访问权限';

  @override
  String get mainBrowseCreatePoolRequiresFullAccess => '需要完全访问权限';

  @override
  String get mainBrowseCompositionPeekUnknownSource => '来源';

  @override
  String get mainBrowseBuildPoolScaffoldTitle => '创建片库';

  @override
  String get mainBrowseBuildPoolScaffoldBody => '后续步骤可在此选择相册与来源。现在请返回浏览。';

  @override
  String get mainBrowseBuildPoolSectionBuiltIn => '内置';

  @override
  String get mainBrowseBuildPoolSectionAlbums => '我的相册';

  @override
  String get mainBrowseBuildPoolSectionSmartAlbums => '系统相册';

  @override
  String get mainBrowseBuildPoolSmartCatalogLoading => '正在加载系统相册…';

  @override
  String get mainBrowseBuildPoolSmartCatalogFailed => '无法加载系统相册。';

  @override
  String get smartAlbumFavorites => '个人收藏';

  @override
  String get smartAlbumLivePhotos => '实况照片';

  @override
  String get smartAlbumScreenshots => '截屏';

  @override
  String get smartAlbumAnimated => '动图';

  @override
  String get smartAlbumSelfies => '自拍';

  @override
  String get smartAlbumVideos => '视频';

  @override
  String get smartAlbumScreenRecordings => '录屏';

  @override
  String get smartAlbumPanoramas => '全景照片';

  @override
  String get smartAlbumTimelapse => '延时摄影';

  @override
  String get smartAlbumBursts => '连拍快照';

  @override
  String get smartAlbumSlomo => '慢动作';

  @override
  String get smartAlbumPortrait => '人像';

  @override
  String get smartAlbumLongExposure => '长曝光';

  @override
  String get smartAlbumRaw => 'RAW';

  @override
  String get smartAlbumCinematic => '电影效果';

  @override
  String get smartAlbumSpatial => '空间';

  @override
  String get smartAlbumDualCapture => '同步双拍';

  @override
  String mainBrowseBuildPoolSelectedHeading(int count) {
    return '已选（$count/30）';
  }

  @override
  String get mainBrowseBuildPoolStart => '开始浏览';

  @override
  String get mainBrowseBuildPoolSave => '保存';

  @override
  String get mainBrowseBuildPoolSaveSuccess => '已保存。';

  @override
  String get mainBrowseBuildPoolSaveAndBrowse => '保存并浏览';

  @override
  String get mainBrowseBuildPoolBrowseWithoutSaving => '不保存直接浏览';

  @override
  String get mainBrowseSavedPoolNamingTitle => '给这个片库命名';

  @override
  String get mainBrowseSavedPoolNamingHint => '名称';

  @override
  String get mainBrowseSavedPoolNamingConfirm => '保存';

  @override
  String get mainBrowseSavedPoolNamingCancel => '取消';

  @override
  String get mainBrowseSavedPoolNamingEmpty => '请输入名称。';

  @override
  String get mainBrowseSavedPoolNamingDuplicate => '这个名称已被使用。';

  @override
  String get mainBrowseSavedPoolNamingTooLong => '名称超出长度限制。';

  @override
  String mainBrowseSavedPoolNamingDuplicateRecipe(String name) {
    return '你已创建过相同配方的片库 — 「$name」。';
  }

  @override
  String get mainBrowseSavedPoolCapacityTitle => '已保存片库已满';

  @override
  String get mainBrowseSavedPoolCapacityBody => '最多保存 10 个片库。请到「已保存」中删除一个后再试。';

  @override
  String get mainBrowseSavedPoolCapacityConfirm => 'OK';

  @override
  String get mainBrowseCompositionPeekSave => '保存此片库';

  @override
  String get mainBrowseSavedPoolRowInfo => '详情';

  @override
  String get mainBrowseSavedPoolInfoClose => 'OK';

  @override
  String get mainBrowseSavedPoolRowRename => '重命名';

  @override
  String get mainBrowseSavedPoolRowDelete => '删除';

  @override
  String get mainBrowseSavedPoolDeleteTitle => '删除这个片库？';

  @override
  String mainBrowseSavedPoolDeleteBody(String name) {
    return '删除「$name」？此操作无法撤销。';
  }

  @override
  String get mainBrowseSavedPoolDeleteConfirm => '删除';

  @override
  String get mainBrowseSavedPoolDeleteCancel => '取消';

  @override
  String get mainBrowseBuildPoolCatalogLoading => '正在加载来源…';

  @override
  String get mainBrowseBuildPoolCatalogFailed => '无法加载来源列表。';

  @override
  String get mainBrowseBuildPoolEmptySelected => '请至少选择一个来源后再开始。';

  @override
  String get mainBrowseBuildPoolCatalogEmpty => '没有可选的相册。';

  @override
  String get mainBrowseNavBrowse => '浏览';

  @override
  String get mainBrowseNavSettings => '设置';

  @override
  String get mainBrowseOrderNewest => '新→旧';

  @override
  String get mainBrowseOrderOldest => '旧→新';

  @override
  String get mainBrowseOrderShuffle => '随机';

  @override
  String get mainBrowseOrderSlotSemantics => '浏览顺序设置。点击打开浏览顺序选项。';

  @override
  String get mainBrowseOrderSheetTitle => '浏览顺序设置';

  @override
  String get mainBrowseOrderSheetNewest => '时间最近在前';

  @override
  String get mainBrowseOrderSheetOldest => '时间最早在前';

  @override
  String get mainBrowseOrderSheetShuffle => '随机顺序';

  @override
  String get mainBrowseOrderSheetConfirm => '确认';

  @override
  String get mainBrowseOrderSheetCancel => '取消';

  @override
  String get mainBrowseFeedPlaceholder => '信息流将在后续步骤加入。';

  @override
  String get mainBrowseFeedLoading => '正在加载图库…';

  @override
  String get mainBrowseFeedEmpty => '此来源没有内容。';

  @override
  String get mainBrowseNewRoundToast => '已浏览一遍，重新开始';

  @override
  String get mainBrowseFeedResolveFailed => '无法加载此来源。';

  @override
  String get mainBrowseFeedRetry => '重试';

  @override
  String get mainBrowseFeedMediaFailed => '无法显示此项目。';

  @override
  String get mainBrowseFeedNetworkFailed => '无法加载。请允许无线数据后重试。';

  @override
  String get mainBrowseFeedUnavailable => '此项目不可用。';

  @override
  String get mainBrowseFeedLayer1Loading => '正在加载此项';

  @override
  String get mainBrowseFeedLayer2Reassure => '仍在加载';

  @override
  String get mainBrowseFeedLayer3Loading => '正在加载完整画质';

  @override
  String get mainBrowseFeedLiveLoading => '正在加载实况照片';

  @override
  String get mainBrowseFeedDownloadFailed => '无法下载此项目。';

  @override
  String get mainBrowseLiveBadge => 'LIVE';

  @override
  String get mainBrowseMagnificationReset => '还原';

  @override
  String get mainBrowseStubSettingsBody => '设置 — 将在后续能力提供。';

  @override
  String get mainBrowseOpenLibrarySmokeDebug => '图库调试（debug）';

  @override
  String get cap27L1StallProbeSectionTitle => 'L1卡住探测';

  @override
  String get cap27L1StallProbeBlurb =>
      '仅 Debug/Profile。写入 Documents/cap27_l1_stall_probe.log，用于 debt 478（非 deviceLocal / iCloud remount 软粘 L1）。remount 后卡在 Layer 1 时：点「标记卡住」→ 滑走再滑回 → 点「标记已恢复」。';

  @override
  String get cap27L1StallProbeMarkStuck => '标记卡住（当前 L1）';

  @override
  String get cap27L1StallProbeMarkHealed => '标记已恢复（滑回后）';

  @override
  String get cap28LiveProbeSectionTitle => 'Cap 28 实时探针';

  @override
  String get cap28LiveProbeBlurb =>
      '仅 Debug/Profile。写入 Documents/wtlive.log，用于 Settings 往返 keep 诊断。浸泡前点清除；每次返回后点「标记黑帧」或「标记返回正常」。';

  @override
  String get cap28LiveProbeClear => '清除 wtlive.log';

  @override
  String get cap28LiveProbeMarkBlack => '标记黑帧（本次返回）';

  @override
  String get cap28LiveProbeMarkOk => '标记返回正常';

  @override
  String get mainBrowseVideoTapToPlay => '播放视频';

  @override
  String get mainBrowseVideoTapToPause => '暂停视频';

  @override
  String get mediaInfoRelativeWithin3Days => '3天内';

  @override
  String get mediaInfoRelativeWithinWeek => '一周内';

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
  String mediaInfoExactDateApprox(String year, String month, String day) {
    return '~ $year-$month-$day';
  }

  @override
  String get mediaInfoLivePhoto => '实况照片';

  @override
  String get mediaInfoAnimated => '动图';

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

  @override
  String get cap19AlbumMutationProbeSectionTitle => 'Cap 19 相册写入探针（debug）';

  @override
  String cap19WaketokAlbumKvLabel(String id) {
    return 'WakeTok 相册 KV：$id';
  }

  @override
  String get cap19ProbeSampleAssetIdLabel => 'Sample PHAsset localIdentifier';

  @override
  String get cap19ProbeUseFirstAllAssetId => '使用 All 首个 asset id';

  @override
  String get cap19ProbeLBootCreate => 'L-BOOT：创建「WakeTok」（不 list）';

  @override
  String get cap19ProbeLBootKvShow => 'L-BOOT-KV：显示缓存 id';

  @override
  String get cap19ProbeLAppend => 'L-APPEND：添加到 WakeTok 相册';

  @override
  String get cap19ProbeFullD1Smoke => 'Full：D1 KV→list find→create 冒烟';

  @override
  String get cap19ProbeClearKv => '清除 WakeTok 探针 KV';

  @override
  String cap19ProductAlbumKvLabel(String id) {
    return '产品 WakeTok 相册 KV：$id';
  }

  @override
  String get cap19ProbeProductBootstrap => '产品：D1 bootstrap';

  @override
  String get cap19ProbeClearProductKv => '清除产品 WakeTok KV';

  @override
  String get cap19EntryIconSemantics => '添加到相册操作';

  @override
  String get cap19PanelTitle => '操作';

  @override
  String get cap19PanelAddToAlbumTitle => '添加到相册';

  @override
  String get cap19PanelAddToAlbumLimitedMessage =>
      '个人收藏和添加到相册需要完整照片访问权限。请打开设置并允许访问所有照片。';

  @override
  String get cap19PanelAddToAlbumFullPlaceholder => '相册选择器将在后续更新中提供。';

  @override
  String get cap19PanelAddToAlbumEmpty => '没有可添加的相册。';

  @override
  String get cap19PanelAddToAlbumListError => '无法加载相册，请重试。';

  @override
  String get cap19PanelAddToAlbumRetry => '重试';

  @override
  String cap19PanelAddToAlbumSuccess(String albumName) {
    return '已添加到$albumName';
  }

  @override
  String get cap19PanelAddToAlbumError => '无法添加到相册，请重试。';

  @override
  String get cap19PanelFavoritesSectionTitle => '快捷操作';

  @override
  String get cap19PanelAlbumsSectionTitle => '相册';

  @override
  String get cap19PanelAddToFavorites => '添加到个人收藏';

  @override
  String get cap19PanelRemoveFromFavorites => '已在个人收藏 — 取消收藏';

  @override
  String get cap19PanelFavoritesAddedSuccess => '已添加到个人收藏';

  @override
  String get cap19PanelFavoritesRemovedSuccess => '已从个人收藏移除';

  @override
  String get cap19PanelFavoritesError => '无法更新个人收藏，请重试。';

  @override
  String get cap19CurrentMediaNotReady => '媒体尚未就绪。';

  @override
  String get stillInLibraryUnavailableTitle => '无法执行此操作';

  @override
  String get stillInLibraryUnavailableBody => '它已不在你的照片图库中。';

  @override
  String get stillInLibraryUnavailableConfirm => 'OK';

  @override
  String get cap19LeftSwipeGuideTitle => '左滑添加到 WakeTok';

  @override
  String get cap19LeftSwipeGuideSubtitle =>
      '保存到 WakeTok 相册，当作稍后在「照片」里查找的标记 — 不会移动或删除原文件';

  @override
  String get cap19LeftSwipeAppendSuccess => '已添加到 WakeTok';

  @override
  String get cap19LeftSwipeAppendError => '无法添加到 WakeTok，请重试。';

  @override
  String get cap19LeftSwipeDragHintContinue => '继续向左滑 · 添加到你的 WakeTok 相册作标记';

  @override
  String get cap19LeftSwipeDragHintArmed => '添加到你的 WakeTok 相册 · 方便以后查看';

  @override
  String get cap19LeftSwipeAlreadyInAlbum => '已在你的 WakeTok 相册中';

  @override
  String get cap19SettingsGesturesSectionTitle => '手势';

  @override
  String get cap19SettingsLeftSwipeAddTitle => '左滑添加到 WakeTok';

  @override
  String get cap19SettingsLeftSwipeAddSubtitle => '将当前项目添加到你的 WakeTok 相册';

  @override
  String get cap19SettingsLeftSwipeGuideTitle => '显示左滑提示';

  @override
  String get cap19SettingsLeftSwipeGuideSubtitle => '每次启动在浏览就绪时显示一次';

  @override
  String get browseSettingsSectionTitle => '浏览提示';

  @override
  String get browseSettingsNewRoundToastTitle => '重新开始提示';

  @override
  String get browseSettingsNewRoundToastSubtitle =>
      '当你把当前列表刷完、从头再看时，浏览页顶部会短暂出现一条提示，大约 1.5 秒。一划走就会立刻消失。';

  @override
  String get cap24MoreEntryIconSemantics => '更多操作';

  @override
  String get cap24SoftDeleteSheetDelete => '删除';

  @override
  String get cap24MoreSheetFileSizeTitle => '文件大小';

  @override
  String get cap24MoreSheetSavedTimeTitle => '保存时间';

  @override
  String get cap24MoreSheetUnavailableValue => '—';

  @override
  String get cap24SoftDeleteSheetMinuteTimezoneNote =>
      '这里的时间是 WakeTok 能展示的、关于此项的最细时间。跨时区仍可能导致有几小时偏差；极端情况下，连日期也可能和浏览页上带「~」的日期对不上。由于文件和图库记录时间的方式不同，并可能受到你当前时区影响，两边都不保证与此项实际创建或保存的时间完全一致。';

  @override
  String get cap24SoftDeleteSheetMinuteTimezoneInfoSemantics => '关于此时间的说明';

  @override
  String cap24SoftDeleteSheetExactMinute(
    String year,
    String month,
    String day,
    String hour,
    String minute,
    String second,
  ) {
    return '$year-$month-$day $hour:$minute:$second';
  }

  @override
  String cap24SoftDeleteSheetExactMinuteNoSeconds(
    String year,
    String month,
    String day,
    String hour,
    String minute,
  ) {
    return '$year-$month-$day $hour:$minute';
  }

  @override
  String cap24SoftDeleteSheetExactMinuteLibrary(
    String year,
    String month,
    String day,
    String hour,
    String minute,
  ) {
    return '$year-$month-$day $hour:$minute';
  }

  @override
  String get cap24SoftDeleteFailed => '无法删除，请重试。';

  @override
  String get cap25ShareEntryIconSemantics => '分享';

  @override
  String get cap25ShareFailed => '无法分享，请重试。';
}
