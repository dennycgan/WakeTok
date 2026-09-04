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
  String get mainBrowseFeedMediaFailed => 'Could not display this item.';

  @override
  String get mainBrowseFeedNetworkFailed =>
      'Could not load. Allow wireless data, then retry.';

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
}
