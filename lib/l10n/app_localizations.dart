import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
  ];

  /// App Foundation 4.1 infrastructure smoke; not product UI copy
  ///
  /// In en, this message translates to:
  /// **'Localization OK'**
  String get l10nSmoke;

  /// Application title
  ///
  /// In en, this message translates to:
  /// **'WakeTok'**
  String get appTitle;

  /// First-launch Photos permission screen title
  ///
  /// In en, this message translates to:
  /// **'Access your photo library'**
  String get permissionRequestTitle;

  /// First-launch Photos permission screen body
  ///
  /// In en, this message translates to:
  /// **'WakeTok shows your photos and videos in a private, on-device feed. Your media never leaves this device.'**
  String get permissionRequestBody;

  /// CTA that triggers the system Photos permission prompt
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get permissionRequestContinue;

  /// Blocked screen title when Photos access is denied
  ///
  /// In en, this message translates to:
  /// **'Photo access is turned off'**
  String get permissionBlockedTitleDenied;

  /// Blocked screen title when Photos access is restricted
  ///
  /// In en, this message translates to:
  /// **'Photo access is restricted'**
  String get permissionBlockedTitleRestricted;

  /// Blocked screen body for denied or restricted access
  ///
  /// In en, this message translates to:
  /// **'WakeTok needs photo library access to show your media. You can enable access in Settings.'**
  String get permissionBlockedBody;

  /// Button that opens the iOS Settings app
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get permissionOpenSettings;

  /// Limited Photos Access banner message (ADR-K)
  ///
  /// In en, this message translates to:
  /// **'Showing only selected photos and videos. Album features and clips need full access.'**
  String get limitedAccessBannerMessage;

  /// Opens the system limited-library picker
  ///
  /// In en, this message translates to:
  /// **'Manage selection'**
  String get limitedAccessManageSelection;

  /// Library totals shell app bar title
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get libraryShellTitle;

  /// Totals row label for all accessible media
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get libraryRowAll;

  /// Totals row label for photos
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get libraryRowPhotos;

  /// Totals row label for videos
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get libraryRowVideos;

  /// Placeholder for per-type totals until 5.4 library enumeration (not a fake zero)
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get countsPending;

  /// Cap 6.4 smoke section title for All/Photos/Videos resolve
  ///
  /// In en, this message translates to:
  /// **'Built-in sources (debug)'**
  String get sourceSmokeSectionTitle;

  /// Runs resolveSource for the selected built-in source
  ///
  /// In en, this message translates to:
  /// **'Resolve selected'**
  String get sourceResolveButton;

  /// Shows AssetSource.estimatedCount from listAssetSources
  ///
  /// In en, this message translates to:
  /// **'estimatedCount: {count}'**
  String sourceEstimatedCount(int count);

  /// Shown when album estimatedCount is null (PhotoKit NSNotFound)
  ///
  /// In en, this message translates to:
  /// **'estimatedCount: unknown'**
  String get sourceEstimatedCountUnknown;

  /// Cap 11.2 E1 section title for listAssetSources kind counts
  ///
  /// In en, this message translates to:
  /// **'List diagnostic (debug)'**
  String get sourceListDiagnosticTitle;

  /// Cap 11.2 E1 counts from listAssetSources by kind
  ///
  /// In en, this message translates to:
  /// **'built-in={builtIn}, userAlbum={album}, smartAlbum={smart}'**
  String sourceListDiagnosticCounts(int builtIn, int album, int smart);

  /// Cap 11.2 E1 lists smart album displayName values for Limited notes
  ///
  /// In en, this message translates to:
  /// **'Smart albums: {names}'**
  String sourceListDiagnosticSmartNames(String names);

  /// Cap 11.2 E1 when list has zero smart albums (e.g. Limited)
  ///
  /// In en, this message translates to:
  /// **'Smart albums: (none)'**
  String get sourceListDiagnosticSmartNamesNone;

  /// Placeholder when a smart album displayName is empty
  ///
  /// In en, this message translates to:
  /// **'(untitled)'**
  String get sourceListDiagnosticUntitled;

  /// Cap 11.3 smoke section for album and smartAlbum resolve probes
  ///
  /// In en, this message translates to:
  /// **'Album / Smart resolve (debug)'**
  String get sourceAlbumResolveSectionTitle;

  /// Resolves the first kind=album entry from listAssetSources
  ///
  /// In en, this message translates to:
  /// **'Resolve first User Album'**
  String get sourceResolveFirstUserAlbum;

  /// Resolves Favorites if present, else the first smartAlbum
  ///
  /// In en, this message translates to:
  /// **'Resolve first Smart Album'**
  String get sourceResolveFirstSmartAlbum;

  /// Re-resolves the last Full-Access user album id (Limited → unauthorized)
  ///
  /// In en, this message translates to:
  /// **'Probe cached album resolve'**
  String get sourceProbeCachedAlbumResolve;

  /// Shown when list has zero album kinds
  ///
  /// In en, this message translates to:
  /// **'No User Album in list (Full Access required).'**
  String get sourceAlbumResolveNoUserAlbum;

  /// Shown when list has zero smartAlbum kinds
  ///
  /// In en, this message translates to:
  /// **'No Smart Album in list (Full Access required).'**
  String get sourceAlbumResolveNoSmartAlbum;

  /// Cached Limited probe has no prior album id
  ///
  /// In en, this message translates to:
  /// **'Resolve a User Album under Full Access first.'**
  String get sourceAlbumResolveNoCache;

  /// Success line after album/smartAlbum resolve
  ///
  /// In en, this message translates to:
  /// **'album resolved length: {count} ({name})'**
  String sourceAlbumResolvedLength(int count, String name);

  /// Cached album resolve correctly returned unauthorized
  ///
  /// In en, this message translates to:
  /// **'Expected unauthorized (Limited / Album).'**
  String get sourceAlbumResolveUnauthorized;

  /// Shown when debug SharedPreferences restored a User Album id after relaunch
  ///
  /// In en, this message translates to:
  /// **'Cached User Album for Limited probe: {name}'**
  String sourceAlbumResolveCacheLoaded(String name);

  /// Generic ARB fallback when album resolve throws unexpectedly
  ///
  /// In en, this message translates to:
  /// **'Album / Smart resolve probe failed.'**
  String get sourceAlbumResolveFailed;

  /// Cap 11.5 smoke section for sequential resolvePool (Photos+All)
  ///
  /// In en, this message translates to:
  /// **'Pool resolve (debug)'**
  String get sourcePoolProbeSectionTitle;

  /// Runs resolvePool on a fixed ephemeral SPD: Photos then All
  ///
  /// In en, this message translates to:
  /// **'Resolve pool (Photos + All)'**
  String get sourcePoolProbeButton;

  /// ResolvedPoolSnapshot coalescedAssetIds length after resolvePool
  ///
  /// In en, this message translates to:
  /// **'coalesced={count}'**
  String sourcePoolProbeCoalesced(int count);

  /// One SourceResolveStatus row from the snapshot (debug)
  ///
  /// In en, this message translates to:
  /// **'{kind}:{id} {availability} raw={raw} contrib={contrib}'**
  String sourcePoolProbeStatus(
    String kind,
    String id,
    String availability,
    int raw,
    int contrib,
  );

  /// Shows ResolvedSource.assetIdentifiers length after resolve
  ///
  /// In en, this message translates to:
  /// **'resolved length: {count}'**
  String sourceResolvedLength(int count);

  /// Resolved length equals the matching libraryTotals component
  ///
  /// In en, this message translates to:
  /// **'match vs totals: OK'**
  String get sourceCountMatch;

  /// Resolved length does not equal libraryTotals
  ///
  /// In en, this message translates to:
  /// **'match vs totals: FAIL'**
  String get sourceCountMismatch;

  /// Shown before the first successful resolve for the selection
  ///
  /// In en, this message translates to:
  /// **'match vs totals: —'**
  String get sourceCountPending;

  /// Cap 6.4 debug section for ADR-013 All-only date quantiles
  ///
  /// In en, this message translates to:
  /// **'All-only quantile sample (debug)'**
  String get sourceQuantileSectionTitle;

  /// Runs All resolve + fetchLibraryPage(cursor:q, pageSize:1) alignment
  ///
  /// In en, this message translates to:
  /// **'Run All quantile sample'**
  String get sourceQuantileRunButton;

  /// Explains why quantile is disabled unless All is selected
  ///
  /// In en, this message translates to:
  /// **'Quantile sampling is All-only (Photos/Videos unsupported).'**
  String get sourceQuantileOnlyAllHint;

  /// One All quantile sample result line
  ///
  /// In en, this message translates to:
  /// **'q={q} id={id} date={date} align={align} avail={avail}'**
  String sourceQuantileRow(
    int q,
    String id,
    String date,
    String align,
    String avail,
  );

  /// ids[q] matches catalog page asset id
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get sourceQuantileAlignOk;

  /// ids[q] does not match catalog page asset id
  ///
  /// In en, this message translates to:
  /// **'FAIL'**
  String get sourceQuantileAlignFail;

  /// Shown when PhotoKit creationDate is null
  ///
  /// In en, this message translates to:
  /// **'nil'**
  String get sourceQuantileDateUnknown;

  /// Cap 6.4 section that exercises illegal sourceType/id pair
  ///
  /// In en, this message translates to:
  /// **'Negative pair probe (debug)'**
  String get sourceNegativeSectionTitle;

  /// Calls resolve with a mismatched kind/id pair
  ///
  /// In en, this message translates to:
  /// **'Probe illegal pair'**
  String get sourceProbeIllegalPairButton;

  /// Shown when illegal pair correctly returns assetUnavailable
  ///
  /// In en, this message translates to:
  /// **'Expected error: source reference unavailable.'**
  String get sourcePairMismatchError;

  /// Shown when illegal pair did not yield assetUnavailable
  ///
  /// In en, this message translates to:
  /// **'Unexpected result from illegal pair probe.'**
  String get sourcePairProbeUnexpected;

  /// Shown while resolve or quantile sample is in progress
  ///
  /// In en, this message translates to:
  /// **'Working…'**
  String get sourceBusy;

  /// Generic ARB fallback when resolve or quantile throws (not raw exception text)
  ///
  /// In en, this message translates to:
  /// **'Built-in source smoke operation failed.'**
  String get sourceSmokeOperationFailed;

  /// Debug span between earliest and latest non-null creationDate years; not a 6.4 pass gate
  ///
  /// In en, this message translates to:
  /// **'year span (non-null dates): {years}'**
  String sourceQuantileYearSpan(String years);

  /// Cap 7.3 debug probe section title
  ///
  /// In en, this message translates to:
  /// **'Playback + image pipeline (debug)'**
  String get playbackProbeSectionTitle;

  /// Requests display asset temp file for first Photos id
  ///
  /// In en, this message translates to:
  /// **'Load first Photos still'**
  String get playbackProbeLoadImage;

  /// Prepares first Videos id and mounts Platform View
  ///
  /// In en, this message translates to:
  /// **'Load first Videos item'**
  String get playbackProbeLoadVideo;

  /// Calls PlaybackApi.play on the probe video
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get playbackProbePlay;

  /// Calls PlaybackApi.pause on the probe video
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get playbackProbePause;

  /// Shown when requestDisplayAsset returns a local path
  ///
  /// In en, this message translates to:
  /// **'Image temp file ready.'**
  String get playbackProbeImageOk;

  /// Shown after setPlaybackPlan/load before PV ready
  ///
  /// In en, this message translates to:
  /// **'Video plan loaded; surface mounting…'**
  String get playbackProbeVideoReady;

  /// Shown after notifyDisplaySurfaceReady
  ///
  /// In en, this message translates to:
  /// **'Display surface ready (adopt).'**
  String get playbackProbeSurfaceReady;

  /// Resolve returned an empty id list
  ///
  /// In en, this message translates to:
  /// **'No assets in the selected built-in source.'**
  String get playbackProbeNoAssets;

  /// Generic ARB fallback for probe errors
  ///
  /// In en, this message translates to:
  /// **'Playback / display probe failed.'**
  String get playbackProbeFailed;

  /// Top chrome fourth tab label (visible, disabled in Cap 7)
  ///
  /// In en, this message translates to:
  /// **'Pools'**
  String get mainBrowsePoolsTab;

  /// Visible subtitle on disabled Pools tab (not a SnackBar)
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get mainBrowsePoolsComingSoon;

  /// Bottom navigation Browse destination
  ///
  /// In en, this message translates to:
  /// **'Browse'**
  String get mainBrowseNavBrowse;

  /// Bottom navigation Clips stub destination
  ///
  /// In en, this message translates to:
  /// **'Clips'**
  String get mainBrowseNavClips;

  /// Bottom navigation Auto-play stub destination
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get mainBrowseNavAuto;

  /// Bottom navigation Settings stub destination
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get mainBrowseNavSettings;

  /// Legacy Cap 7.4 stub; unused after Cap 7.5 feed (kept for key stability)
  ///
  /// In en, this message translates to:
  /// **'Feed arrives in a later step.'**
  String get mainBrowseFeedPlaceholder;

  /// Main Browse feed while resolveSource is in flight
  ///
  /// In en, this message translates to:
  /// **'Loading library…'**
  String get mainBrowseFeedLoading;

  /// Main Browse feed when resolve returns an empty id list
  ///
  /// In en, this message translates to:
  /// **'No items in this source.'**
  String get mainBrowseFeedEmpty;

  /// Main Browse feed when resolveSource fails
  ///
  /// In en, this message translates to:
  /// **'Could not load this source.'**
  String get mainBrowseFeedResolveFailed;

  /// Retry button for feed resolve or page media errors
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get mainBrowseFeedRetry;

  /// Feed page generic display/playable failure
  ///
  /// In en, this message translates to:
  /// **'Could not display this item.'**
  String get mainBrowseFeedMediaFailed;

  /// Layer 2 failed before transfer began (cellular/wireless-data prompt or no network)
  ///
  /// In en, this message translates to:
  /// **'Could not load. Allow wireless data, then retry.'**
  String get mainBrowseFeedNetworkFailed;

  /// Semantics for Layer 3 spinner over Layer 1 while Layer 2 is in flight
  ///
  /// In en, this message translates to:
  /// **'Loading full quality'**
  String get mainBrowseFeedLayer3Loading;

  /// Layer 2 failed while Layer 1 preview is still shown
  ///
  /// In en, this message translates to:
  /// **'Could not download this item.'**
  String get mainBrowseFeedDownloadFailed;

  /// Corner badge when display mediaKind is livePhoto (static mark only)
  ///
  /// In en, this message translates to:
  /// **'LIVE'**
  String get mainBrowseLiveBadge;

  /// Clips tab stub body copy
  ///
  /// In en, this message translates to:
  /// **'Clips — coming in a later capability.'**
  String get mainBrowseStubClipsBody;

  /// Auto tab stub body copy
  ///
  /// In en, this message translates to:
  /// **'Auto-play — coming in a later capability.'**
  String get mainBrowseStubAutoBody;

  /// Settings tab stub body copy
  ///
  /// In en, this message translates to:
  /// **'Settings — coming in a later capability.'**
  String get mainBrowseStubSettingsBody;

  /// kDebugMode-only button on Settings stub to open library_smoke
  ///
  /// In en, this message translates to:
  /// **'Library smoke (debug)'**
  String get mainBrowseOpenLibrarySmokeDebug;

  /// Overlay row 1 when the asset was created on the current local calendar day
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get mediaInfoRelativeToday;

  /// Overlay row 1 when age is 1–30 days (inclusive)
  ///
  /// In en, this message translates to:
  /// **'{count} days ago'**
  String mediaInfoRelativeDaysAgo(String count);

  /// Overlay row 1 when age is over 30 days and only months (no years)
  ///
  /// In en, this message translates to:
  /// **'{count} months ago'**
  String mediaInfoRelativeMonthsAgo(String count);

  /// Overlay row 1 when age is whole years (no leftover months)
  ///
  /// In en, this message translates to:
  /// **'{count} years ago'**
  String mediaInfoRelativeYearsAgo(String count);

  /// Overlay row 1 when age is over 30 days with both years and months
  ///
  /// In en, this message translates to:
  /// **'{years} years {months} months ago'**
  String mediaInfoRelativeYearsMonthsAgo(String years, String months);

  /// Overlay row 2 exact local date and time
  ///
  /// In en, this message translates to:
  /// **'{year}-{month}-{day} {hour}:{minute}'**
  String mediaInfoExactDateTime(
    String year,
    String month,
    String day,
    String hour,
    String minute,
  );

  /// Overlay row 3 label when mediaKind is livePhoto
  ///
  /// In en, this message translates to:
  /// **'Live Photo'**
  String get mediaInfoLivePhoto;

  /// Overlay row 3 size under 1 KiB
  ///
  /// In en, this message translates to:
  /// **'{count} B'**
  String mediaInfoFileSizeBytes(String count);

  /// Overlay row 3 size in kibibytes
  ///
  /// In en, this message translates to:
  /// **'{count} KB'**
  String mediaInfoFileSizeKb(String count);

  /// Overlay row 3 size in mebibytes
  ///
  /// In en, this message translates to:
  /// **'{count} MB'**
  String mediaInfoFileSizeMb(String count);

  /// Overlay row 3 size in gibibytes
  ///
  /// In en, this message translates to:
  /// **'{count} GB'**
  String mediaInfoFileSizeGb(String count);

  /// Overlay row 3 when both Live Photo label and file size are present
  ///
  /// In en, this message translates to:
  /// **'{live} · {size}'**
  String mediaInfoCharacteristicsJoined(String live, String size);

  /// Cap 9.6 library_smoke section for shared Mute preference toggle
  ///
  /// In en, this message translates to:
  /// **'Shared mute (debug)'**
  String get sharedMuteDebugSectionTitle;

  /// Cap 9.6 debug switch label; true = muted (no Live/video audio)
  ///
  /// In en, this message translates to:
  /// **'Muted'**
  String get sharedMuteDebugSwitchLabel;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.scriptCode) {
          case 'Hans':
            return AppLocalizationsZhHans();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
