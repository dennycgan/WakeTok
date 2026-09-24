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
  String get photosAccessSettingsSectionTitle => 'Photos Access';

  @override
  String get photosAccessFullStatusMessage =>
      'Full access to your photo library.';

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
  String get cap30VerticalHintGuideTitle => 'Swipe to browse your library';

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
  String get browseDisplaySettingsSectionTitle => 'Browse display';

  @override
  String get browseDisplayMetaOverlayTitle => 'Show item details';

  @override
  String get browseDisplayMetaOverlaySubtitle =>
      'Turn off to hide the details shown at the bottom-left of each item. Reopening the app restores display.';

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
