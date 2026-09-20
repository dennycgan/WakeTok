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

  /// Browse top source + library totals row for the Photos media-type source (still images + Live Photo, not camera-only)
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

  /// Visible subtitle on disabled Pools tab (not a SnackBar). Cap 21.3 removes the tab from UI; key kept for stability.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get mainBrowsePoolsComingSoon;

  /// Cap 21.3 fixed short label for parked ephemeral Pool chip (ADR-044 D7)
  ///
  /// In en, this message translates to:
  /// **'Temp Pool'**
  String get mainBrowseTempPoolChip;

  /// VoiceOver for Built-in control while Origin is ephemeral Temp Pool
  ///
  /// In en, this message translates to:
  /// **'{builtInLabel}. Currently browsing Temp Pool.'**
  String mainBrowseBuiltInWhileEphemeralSemantics(String builtInLabel);

  /// VoiceOver for Built-in control while Origin is a Saved Pool (ADR-044 D6.4)
  ///
  /// In en, this message translates to:
  /// **'{builtInLabel}. Currently browsing {savedPoolName}.'**
  String mainBrowseBuiltInWhileSavedPoolSemantics(
    String builtInLabel,
    String savedPoolName,
  );

  /// Cap 21.3 Built-in dropdown affordance when no specific source name is shown
  ///
  /// In en, this message translates to:
  /// **'Built-in'**
  String get mainBrowseBuiltInMenu;

  /// Cap 22.4 Saved pools dropdown control label (ADR-046 D6)
  ///
  /// In en, this message translates to:
  /// **'Saved pools'**
  String get mainBrowseSavedPoolsMenu;

  /// Cap 21.3 Create control — opens the Build a Pool screen
  ///
  /// In en, this message translates to:
  /// **'Create Pool'**
  String get mainBrowseCreatePool;

  /// Cap 21.3 gray Saved-menu row; Cap 22 wires persist (ADR-044 D1)
  ///
  /// In en, this message translates to:
  /// **'Save current pool — Coming soon'**
  String get mainBrowseSavedPlaceholderSave;

  /// Cap 21.3 gray Saved-menu row; Cap 22 wires manage (ADR-044 D1)
  ///
  /// In en, this message translates to:
  /// **'Manage pools — Coming soon'**
  String get mainBrowseSavedPlaceholderManage;

  /// Cap 21.3 gray empty Saved list placeholder
  ///
  /// In en, this message translates to:
  /// **'No saved pools yet'**
  String get mainBrowseSavedPlaceholderEmpty;

  /// Temp chip composition peek title (ephemeral only)
  ///
  /// In en, this message translates to:
  /// **'Sources in this pool'**
  String get mainBrowseCompositionPeekTitle;

  /// Saved recipe title for peek and centered Info; {name} is displayName
  ///
  /// In en, this message translates to:
  /// **'Sources in “{name}”'**
  String mainBrowseSavedPoolSourcesTitle(String name);

  /// Toast when Saved menu row is tapped while that pool is already active
  ///
  /// In en, this message translates to:
  /// **'You\'re already browsing “{name}”.'**
  String mainBrowseSavedPoolAlreadyBrowsing(String name);

  /// Legacy Cap 21.3 key; Cap 21.5 peek uses Removed/RequiresFullAccess (kept for key stability)
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get mainBrowseCompositionPeekUnavailable;

  /// Composition peek suffix when a source is missing under Full Access or list-unavailable
  ///
  /// In en, this message translates to:
  /// **'Removed from Photos'**
  String get mainBrowseCompositionPeekRemovedFromPhotos;

  /// Composition peek suffix when source needs Full Access (Limited / unauthorized)
  ///
  /// In en, this message translates to:
  /// **'Requires Full Access'**
  String get mainBrowseCompositionPeekRequiresFullAccess;

  /// Caption under disabled Create when Photos access is Limited (ZH aligns Cap 5.3 Full Access root; Cap 19.5b panel copy may differ)
  ///
  /// In en, this message translates to:
  /// **'Requires Full Access'**
  String get mainBrowseCreatePoolRequiresFullAccess;

  /// Fallback composition label when catalog has no title (never a PhotoKit id)
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get mainBrowseCompositionPeekUnknownSource;

  /// Cap 21 Build a Pool screen AppBar title
  ///
  /// In en, this message translates to:
  /// **'Build a Pool'**
  String get mainBrowseBuildPoolScaffoldTitle;

  /// Legacy Cap 21.3 placeholder body; unused after 21.4 Build UI (key kept for stability)
  ///
  /// In en, this message translates to:
  /// **'Pick albums and sources here in a later step. For now, go back to Browse.'**
  String get mainBrowseBuildPoolScaffoldBody;

  /// Unused after Cap 21.4 device round — All/Photos/Videos stay top-tab only (key kept for stability)
  ///
  /// In en, this message translates to:
  /// **'Built-in'**
  String get mainBrowseBuildPoolSectionBuiltIn;

  /// Cap 21.4 Build catalog section header for user albums
  ///
  /// In en, this message translates to:
  /// **'My Albums'**
  String get mainBrowseBuildPoolSectionAlbums;

  /// Cap 21.4b Build catalog section for curated PhotoKit smart albums (product: System Albums)
  ///
  /// In en, this message translates to:
  /// **'System Albums'**
  String get mainBrowseBuildPoolSectionSmartAlbums;

  /// Cap 21.4b system-albums section while emptiness probe runs
  ///
  /// In en, this message translates to:
  /// **'Loading system albums…'**
  String get mainBrowseBuildPoolSmartCatalogLoading;

  /// Cap 21.4b system-albums section AsyncError fallback
  ///
  /// In en, this message translates to:
  /// **'Could not load system albums.'**
  String get mainBrowseBuildPoolSmartCatalogFailed;

  /// Cap 21.4b Build smart-album row label (subtype 203)
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get smartAlbumFavorites;

  /// Cap 21.4b Build smart-album row label (subtype 213)
  ///
  /// In en, this message translates to:
  /// **'Live Photos'**
  String get smartAlbumLivePhotos;

  /// Cap 21.4b Build smart-album row label (subtype 211)
  ///
  /// In en, this message translates to:
  /// **'Screenshots'**
  String get smartAlbumScreenshots;

  /// Cap 21.4b Build smart-album row label (subtype 214)
  ///
  /// In en, this message translates to:
  /// **'Animated'**
  String get smartAlbumAnimated;

  /// Cap 21.4b Build smart-album row label (subtype 210)
  ///
  /// In en, this message translates to:
  /// **'Selfies'**
  String get smartAlbumSelfies;

  /// Cap 21.4b Build smart-album row label (subtype 202)
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get smartAlbumVideos;

  /// Cap 21.4b Build smart-album row label (subtype 220)
  ///
  /// In en, this message translates to:
  /// **'Screen Recordings'**
  String get smartAlbumScreenRecordings;

  /// Cap 21.4b Build smart-album row label (subtype 201)
  ///
  /// In en, this message translates to:
  /// **'Panoramas'**
  String get smartAlbumPanoramas;

  /// Cap 21.4b Build smart-album row label (subtype 204)
  ///
  /// In en, this message translates to:
  /// **'Time-lapse'**
  String get smartAlbumTimelapse;

  /// Cap 21.4b Build smart-album row label (subtype 207)
  ///
  /// In en, this message translates to:
  /// **'Bursts'**
  String get smartAlbumBursts;

  /// Cap 21.4b Build smart-album row label (subtype 208)
  ///
  /// In en, this message translates to:
  /// **'Slo-mo'**
  String get smartAlbumSlomo;

  /// Cap 21.4b Build smart-album row label (subtype 212)
  ///
  /// In en, this message translates to:
  /// **'Portrait'**
  String get smartAlbumPortrait;

  /// Cap 21.4b Build smart-album row label (subtype 215)
  ///
  /// In en, this message translates to:
  /// **'Long Exposure'**
  String get smartAlbumLongExposure;

  /// Cap 21.4b Build smart-album row label (subtype 217)
  ///
  /// In en, this message translates to:
  /// **'RAW'**
  String get smartAlbumRaw;

  /// Cap 21.4b Build smart-album row label (subtype 218)
  ///
  /// In en, this message translates to:
  /// **'Cinematic'**
  String get smartAlbumCinematic;

  /// Cap 21.4b Build smart-album row label (subtype 219)
  ///
  /// In en, this message translates to:
  /// **'Spatial'**
  String get smartAlbumSpatial;

  /// Cap 21.4b Build smart-album row label (subtype 221)
  ///
  /// In en, this message translates to:
  /// **'Dual Capture'**
  String get smartAlbumDualCapture;

  /// Cap 21.4 selected-sources heading with count
  ///
  /// In en, this message translates to:
  /// **'Selected ({count}/30)'**
  String mainBrowseBuildPoolSelectedHeading(int count);

  /// Legacy Cap 21.4 Start label — unused after ADR-047; kept for key stability
  ///
  /// In en, this message translates to:
  /// **'Start browsing'**
  String get mainBrowseBuildPoolStart;

  /// Legacy Cap 22.3 Save-only label — unused after ADR-047; kept for key stability
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get mainBrowseBuildPoolSave;

  /// Legacy Cap 22.3 Save-only SnackBar — unused after ADR-047; kept for key stability
  ///
  /// In en, this message translates to:
  /// **'Saved.'**
  String get mainBrowseBuildPoolSaveSuccess;

  /// ADR-047 Build: persist then start Saved Session and pop
  ///
  /// In en, this message translates to:
  /// **'Save & browse'**
  String get mainBrowseBuildPoolSaveAndBrowse;

  /// ADR-047 Build: ephemeral Start only — never consult prior Save
  ///
  /// In en, this message translates to:
  /// **'Browse without saving'**
  String get mainBrowseBuildPoolBrowseWithoutSaving;

  /// Shared Saved Pool naming dialog title (Build Save, peek Save, Rename)
  ///
  /// In en, this message translates to:
  /// **'Name this pool'**
  String get mainBrowseSavedPoolNamingTitle;

  /// Shared naming dialog text field hint
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get mainBrowseSavedPoolNamingHint;

  /// Shared naming dialog confirm
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get mainBrowseSavedPoolNamingConfirm;

  /// Shared naming dialog cancel
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get mainBrowseSavedPoolNamingCancel;

  /// Inline error when the naming field is empty after trim
  ///
  /// In en, this message translates to:
  /// **'Enter a name.'**
  String get mainBrowseSavedPoolNamingEmpty;

  /// Inline error when the normalized name collides with another Saved preset
  ///
  /// In en, this message translates to:
  /// **'This name is already used.'**
  String get mainBrowseSavedPoolNamingDuplicate;

  /// Inline error when the name exceeds the visual naming weight budget
  ///
  /// In en, this message translates to:
  /// **'Name is too long.'**
  String get mainBrowseSavedPoolNamingTooLong;

  /// Inline error when create recipe matches an existing Saved preset; {name} is that preset's display name
  ///
  /// In en, this message translates to:
  /// **'You already have a pool with these sources — “{name}”.'**
  String mainBrowseSavedPoolNamingDuplicateRecipe(String name);

  /// Capacity dialog title at max 10 Saved presets
  ///
  /// In en, this message translates to:
  /// **'Saved pools full'**
  String get mainBrowseSavedPoolCapacityTitle;

  /// Capacity dialog body — guides the user to Saved pools to delete (ADR-046 D2)
  ///
  /// In en, this message translates to:
  /// **'You can save up to 10 pools. Delete one from Saved pools, then try again.'**
  String get mainBrowseSavedPoolCapacityBody;

  /// Capacity dialog dismiss
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get mainBrowseSavedPoolCapacityConfirm;

  /// Ephemeral composition peek footer — persist and promote to savedPool
  ///
  /// In en, this message translates to:
  /// **'Save this pool'**
  String get mainBrowseCompositionPeekSave;

  /// Saved menu per-row Info — opens centered recipe dialog
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get mainBrowseSavedPoolRowInfo;

  /// Centered Saved Info dialog dismiss
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get mainBrowseSavedPoolInfoClose;

  /// Saved menu per-row Rename
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get mainBrowseSavedPoolRowRename;

  /// Saved menu per-row Delete
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get mainBrowseSavedPoolRowDelete;

  /// Confirm dialog title before deleting a Saved preset
  ///
  /// In en, this message translates to:
  /// **'Delete this pool?'**
  String get mainBrowseSavedPoolDeleteTitle;

  /// Confirm dialog body; {name} is the preset displayName
  ///
  /// In en, this message translates to:
  /// **'Delete “{name}”? This cannot be undone.'**
  String mainBrowseSavedPoolDeleteBody(String name);

  /// Confirm dialog destructive action
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get mainBrowseSavedPoolDeleteConfirm;

  /// Confirm dialog dismiss
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get mainBrowseSavedPoolDeleteCancel;

  /// Cap 21.4 catalog list while assetSourcesProvider is loading
  ///
  /// In en, this message translates to:
  /// **'Loading sources…'**
  String get mainBrowseBuildPoolCatalogLoading;

  /// Cap 21.4 catalog AsyncError fallback (no Retry polish in 21.4)
  ///
  /// In en, this message translates to:
  /// **'Could not load the source list.'**
  String get mainBrowseBuildPoolCatalogFailed;

  /// Cap 21.4 hint when selected list is empty
  ///
  /// In en, this message translates to:
  /// **'Select at least one source to start.'**
  String get mainBrowseBuildPoolEmptySelected;

  /// Cap 21.4 catalog empty state (e.g. Limited access exposes no albums)
  ///
  /// In en, this message translates to:
  /// **'No albums available.'**
  String get mainBrowseBuildPoolCatalogEmpty;

  /// Bottom navigation Browse destination
  ///
  /// In en, this message translates to:
  /// **'Browse'**
  String get mainBrowseNavBrowse;

  /// Bottom navigation Settings stub destination
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get mainBrowseNavSettings;

  /// Cap 27 bottom-bar order slot label — newest first
  ///
  /// In en, this message translates to:
  /// **'New first'**
  String get mainBrowseOrderNewest;

  /// Cap 27 bottom-bar order slot label — oldest first
  ///
  /// In en, this message translates to:
  /// **'Old first'**
  String get mainBrowseOrderOldest;

  /// Cap 27 bottom-bar order slot label — shuffle
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get mainBrowseOrderShuffle;

  /// Semantics for the bottom-bar order action slot (not a destination tab)
  ///
  /// In en, this message translates to:
  /// **'Play order. Opens play order options.'**
  String get mainBrowseOrderSlotSemantics;

  /// Cap 27 Layer-1 order-control half-sheet title
  ///
  /// In en, this message translates to:
  /// **'Play Order'**
  String get mainBrowseOrderSheetTitle;

  /// Cap 27 order-control sheet option — newest first
  ///
  /// In en, this message translates to:
  /// **'Newest → Oldest'**
  String get mainBrowseOrderSheetNewest;

  /// Cap 27 order-control sheet option — oldest first
  ///
  /// In en, this message translates to:
  /// **'Oldest → Newest'**
  String get mainBrowseOrderSheetOldest;

  /// Cap 27 order-control sheet option — shuffle
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get mainBrowseOrderSheetShuffle;

  /// Cap 27 order-control sheet confirm button
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get mainBrowseOrderSheetConfirm;

  /// Cap 27 order-control sheet cancel button
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get mainBrowseOrderSheetCancel;

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

  /// Cap 22.5 toast after one full Endless pass; commit next Shuffle (not internal jargon)
  ///
  /// In en, this message translates to:
  /// **'You\'ve seen it all — starting over'**
  String get mainBrowseNewRoundToast;

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

  /// Feed Layer-2/page fail when Host returns assetUnavailable (Cap 21.6 debt 444); no Retry
  ///
  /// In en, this message translates to:
  /// **'This item is unavailable.'**
  String get mainBrowseFeedUnavailable;

  /// Visible center copy + immediate VoiceOver on Layer 1 miss; center copy has a source-switch-only 150ms delay (ADR-039)
  ///
  /// In en, this message translates to:
  /// **'Loading item'**
  String get mainBrowseFeedLayer1Loading;

  /// Short copy left of the corner gold spinner after 3s L2 wait (cover optional; ADR-039 removed center Layer2Waiting)
  ///
  /// In en, this message translates to:
  /// **'Still loading'**
  String get mainBrowseFeedLayer2Reassure;

  /// Semantics for the Layer 2/full-quality corner spinner, with or without a visible Layer 1 cover
  ///
  /// In en, this message translates to:
  /// **'Loading full quality'**
  String get mainBrowseFeedLayer3Loading;

  /// Semantics for the single Live still spinner covering Layer 2 and motion prepare (Cap 14.6b)
  ///
  /// In en, this message translates to:
  /// **'Loading Live Photo'**
  String get mainBrowseFeedLiveLoading;

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

  /// Cap 20 Reset pill visible label + semantics (short; Video-App-B class)
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get mainBrowseMagnificationReset;

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

  /// TEMP Cap 27 Debt 468 probe section title — remove after fix
  ///
  /// In en, this message translates to:
  /// **'L1-stall probe (temp)'**
  String get cap27L1StallProbeSectionTitle;

  /// TEMP Cap 27 Debt 468 probe instructions
  ///
  /// In en, this message translates to:
  /// **'Writes Documents/cap27_l1_stall_probe.log. When stuck on Layer 1 after starting-over: tap Mark stuck, swipe away then back, tap Mark healed.'**
  String get cap27L1StallProbeBlurb;

  /// TEMP Cap 27 Debt 468 — owner marks stuck snapshot
  ///
  /// In en, this message translates to:
  /// **'Mark stuck (L1 stall now)'**
  String get cap27L1StallProbeMarkStuck;

  /// TEMP Cap 27 Debt 468 — owner marks heal snapshot
  ///
  /// In en, this message translates to:
  /// **'Mark healed (after swipe back)'**
  String get cap27L1StallProbeMarkHealed;

  /// Semantics / accessibility label when paused video can resume via tap
  ///
  /// In en, this message translates to:
  /// **'Play video'**
  String get mainBrowseVideoTapToPlay;

  /// Semantics / accessibility label when playing video can pause via tap
  ///
  /// In en, this message translates to:
  /// **'Pause video'**
  String get mainBrowseVideoTapToPause;

  /// Overlay row 1 when local calendar age is 0–2 days (Cap 17.7 coarse band)
  ///
  /// In en, this message translates to:
  /// **'Within the past 3 days'**
  String get mediaInfoRelativeWithin3Days;

  /// Overlay row 1 when local calendar age is 3–7 days (Cap 17.7 coarse band)
  ///
  /// In en, this message translates to:
  /// **'Within the past week'**
  String get mediaInfoRelativeWithinWeek;

  /// Overlay row 1 when age is 8–30 days (inclusive)
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

  /// Overlay row 2 approximate local calendar date (~ prefix; day precision; not minute-exact)
  ///
  /// In en, this message translates to:
  /// **'~ {year}-{month}-{day}'**
  String mediaInfoExactDateApprox(String year, String month, String day);

  /// Overlay row 3 label when mediaKind is livePhoto
  ///
  /// In en, this message translates to:
  /// **'Live Photo'**
  String get mediaInfoLivePhoto;

  /// Overlay row 3 Animated still characteristics label (GIF kin; ADR-053)
  ///
  /// In en, this message translates to:
  /// **'Animated'**
  String get mediaInfoAnimated;

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

  /// Overlay row 3 when both a characteristics label (Live Photo or Animated) and file size are present
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

  /// Cap 19.2a library_smoke section for Limited album mutation spike
  ///
  /// In en, this message translates to:
  /// **'Cap 19 Album Mutation Probe (debug)'**
  String get cap19AlbumMutationProbeSectionTitle;

  /// Shows cached WakeTok probe album id from debug SharedPreferences
  ///
  /// In en, this message translates to:
  /// **'WakeTok album KV: {id}'**
  String cap19WaketokAlbumKvLabel(String id);

  /// Cap 19.2a probe TextField label for append target asset id
  ///
  /// In en, this message translates to:
  /// **'Sample PHAsset localIdentifier'**
  String get cap19ProbeSampleAssetIdLabel;

  /// Cap 19.2a probe button to fill sample asset id from All resolve head
  ///
  /// In en, this message translates to:
  /// **'Use first All asset id'**
  String get cap19ProbeUseFirstAllAssetId;

  /// Cap 19.2a Limited bootstrap probe — create-only, no list find
  ///
  /// In en, this message translates to:
  /// **'L-BOOT: Create \"WakeTok\" (no list)'**
  String get cap19ProbeLBootCreate;

  /// Cap 19.2a Limited KV-only bootstrap probe
  ///
  /// In en, this message translates to:
  /// **'L-BOOT-KV: Show cached id'**
  String get cap19ProbeLBootKvShow;

  /// Cap 19.2a Limited append probe
  ///
  /// In en, this message translates to:
  /// **'L-APPEND: Add sample to WakeTok album'**
  String get cap19ProbeLAppend;

  /// Cap 19.2a Full Access D1 bootstrap smoke probe
  ///
  /// In en, this message translates to:
  /// **'Full: D1 KV→list find→create smoke'**
  String get cap19ProbeFullD1Smoke;

  /// Cap 19.2a clears debug SharedPreferences album id
  ///
  /// In en, this message translates to:
  /// **'Clear WakeTok probe KV'**
  String get cap19ProbeClearKv;

  /// Shows cached product WakeTok album localIdentifier (Cap 19.3)
  ///
  /// In en, this message translates to:
  /// **'Product WakeTok album KV: {id}'**
  String cap19ProductAlbumKvLabel(String id);

  /// Cap 19.3 library_smoke probe — product bootstrapWakeTokAlbum
  ///
  /// In en, this message translates to:
  /// **'Product: D1 bootstrap'**
  String get cap19ProbeProductBootstrap;

  /// Cap 19.3 clears product SharedPreferences album id
  ///
  /// In en, this message translates to:
  /// **'Clear product WakeTok KV'**
  String get cap19ProbeClearProductKv;

  /// Cap 19.4 entry icon accessibility label
  ///
  /// In en, this message translates to:
  /// **'Add to album actions'**
  String get cap19EntryIconSemantics;

  /// Cap 19.4 half-sheet title
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get cap19PanelTitle;

  /// Cap 19 half-sheet title (shared Full/Limited chrome; keep Add to Album — bare Add rejected on device under Limited)
  ///
  /// In en, this message translates to:
  /// **'Add to Album'**
  String get cap19PanelAddToAlbumTitle;

  /// Cap 19.4 D4 non-interactive Limited upgrade copy (Cap 19.5b: favorites + albums)
  ///
  /// In en, this message translates to:
  /// **'Favorites and albums need full Photos access. Open Settings to allow access to all photos.'**
  String get cap19PanelAddToAlbumLimitedMessage;

  /// Cap 19.4 Full Access placeholder until Cap 19.5 picker
  ///
  /// In en, this message translates to:
  /// **'Album picker arrives in a later update.'**
  String get cap19PanelAddToAlbumFullPlaceholder;

  /// Cap 19.5 picker when no writable User Albums
  ///
  /// In en, this message translates to:
  /// **'No albums you can add to.'**
  String get cap19PanelAddToAlbumEmpty;

  /// Cap 19.5 listAssetSources failure
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load albums. Try again.'**
  String get cap19PanelAddToAlbumListError;

  /// Cap 19.5 retry album list load
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get cap19PanelAddToAlbumRetry;

  /// Cap 19.5 append success SnackBar
  ///
  /// In en, this message translates to:
  /// **'Added to {albumName}'**
  String cap19PanelAddToAlbumSuccess(String albumName);

  /// Cap 19.5 append failure SnackBar
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t add to album. Try again.'**
  String get cap19PanelAddToAlbumError;

  /// Cap 19.5b Favorites section header above album list
  ///
  /// In en, this message translates to:
  /// **'Quick action'**
  String get cap19PanelFavoritesSectionTitle;

  /// Cap 19.5b Albums section header below Favorites row
  ///
  /// In en, this message translates to:
  /// **'Albums'**
  String get cap19PanelAlbumsSectionTitle;

  /// Cap 19.5b Favorites row when asset is not favorited
  ///
  /// In en, this message translates to:
  /// **'Add to Favorites'**
  String get cap19PanelAddToFavorites;

  /// Cap 19.5b Favorites row when asset is already favorited; states status then action
  ///
  /// In en, this message translates to:
  /// **'Favorited — Remove'**
  String get cap19PanelRemoveFromFavorites;

  /// Cap 19.5b toggle-on success toast
  ///
  /// In en, this message translates to:
  /// **'Added to Favorites'**
  String get cap19PanelFavoritesAddedSuccess;

  /// Cap 19.5b toggle-off success toast
  ///
  /// In en, this message translates to:
  /// **'Removed from Favorites'**
  String get cap19PanelFavoritesRemovedSuccess;

  /// Cap 19.5b Favorites Host read/toggle failure (not media-not-ready)
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update Favorites. Try again.'**
  String get cap19PanelFavoritesError;

  /// Cap 19 when current asset id is unset (panel row or toast; may split later)
  ///
  /// In en, this message translates to:
  /// **'Media isn\'t ready yet.'**
  String get cap19CurrentMediaNotReady;

  /// Cap 23 shared dialog title (action-focused; item reason stays in body)
  ///
  /// In en, this message translates to:
  /// **'This action isn\'t available'**
  String get stillInLibraryUnavailableTitle;

  /// Cap 23 shared dialog body for still-in-library miss
  ///
  /// In en, this message translates to:
  /// **'It\'s no longer in your Photos library.'**
  String get stillInLibraryUnavailableBody;

  /// Cap 23 shared unavailable dialog dismiss action
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get stillInLibraryUnavailableConfirm;

  /// Cap 19.6 one-shot coach mark title
  ///
  /// In en, this message translates to:
  /// **'Swipe left to add to WakeTok'**
  String get cap19LeftSwipeGuideTitle;

  /// Cap 19.6 one-shot coach mark subtitle (why + safety)
  ///
  /// In en, this message translates to:
  /// **'Saves it to your WakeTok album as a bookmark for later in Photos — nothing is moved or deleted'**
  String get cap19LeftSwipeGuideSubtitle;

  /// Cap 19.6 left-swipe append success toast
  ///
  /// In en, this message translates to:
  /// **'Added to WakeTok'**
  String get cap19LeftSwipeAppendSuccess;

  /// Cap 19.6 left-swipe append failure toast
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t add to WakeTok. Try again.'**
  String get cap19LeftSwipeAppendError;

  /// Cap 19 left-swipe chip before commit threshold (motion + album mark)
  ///
  /// In en, this message translates to:
  /// **'Keep swiping left · Add to your WakeTok album as a mark'**
  String get cap19LeftSwipeDragHintContinue;

  /// Cap 19 left-swipe chip past commit threshold (album destination; no release verb)
  ///
  /// In en, this message translates to:
  /// **'Add to your WakeTok album · for later'**
  String get cap19LeftSwipeDragHintArmed;

  /// Cap 19.7 left-swipe when asset is already a member
  ///
  /// In en, this message translates to:
  /// **'Already in your WakeTok album'**
  String get cap19LeftSwipeAlreadyInAlbum;

  /// Cap 19.7 Settings Gestures section header
  ///
  /// In en, this message translates to:
  /// **'Gestures'**
  String get cap19SettingsGesturesSectionTitle;

  /// Cap 19.7 master left-swipe toggle title
  ///
  /// In en, this message translates to:
  /// **'Swipe left to add to WakeTok'**
  String get cap19SettingsLeftSwipeAddTitle;

  /// Cap 19.7 master left-swipe toggle subtitle
  ///
  /// In en, this message translates to:
  /// **'Adds the current item to your WakeTok album'**
  String get cap19SettingsLeftSwipeAddSubtitle;

  /// Cap 19.7 guide tip toggle title
  ///
  /// In en, this message translates to:
  /// **'Show left-swipe tip'**
  String get cap19SettingsLeftSwipeGuideTitle;

  /// Cap 19.7 guide tip toggle subtitle
  ///
  /// In en, this message translates to:
  /// **'Once per launch when Browse is ready'**
  String get cap19SettingsLeftSwipeGuideSubtitle;

  /// Cap 22.5 Settings section for Browse notifications (not bottom-nav Browse)
  ///
  /// In en, this message translates to:
  /// **'Browse notices'**
  String get browseSettingsSectionTitle;

  /// Cap 22.5 toggle title for end-of-list restart toast
  ///
  /// In en, this message translates to:
  /// **'Starting-over notice'**
  String get browseSettingsNewRoundToastTitle;

  /// Cap 22.5 toggle subtitle: where, when, duration, early dismiss
  ///
  /// In en, this message translates to:
  /// **'When you finish browsing the whole list and it starts over, a short message appears near the top of Browse for about 1.5 seconds. Swipe away and it disappears right away.'**
  String get browseSettingsNewRoundToastSubtitle;

  /// Cap 24.3 Action Column ellipsis entry accessibility label
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get cap24MoreEntryIconSemantics;

  /// Cap 24.3 more half-sheet Delete row (system PhotoKit consent is the only confirm)
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get cap24SoftDeleteSheetDelete;

  /// Cap 26.4 more half-sheet File size row title (always shown)
  ///
  /// In en, this message translates to:
  /// **'File size'**
  String get cap24MoreSheetFileSizeTitle;

  /// Cap 26.4 more half-sheet Saved time row title (umbrella wording; omits with value when landmark missing)
  ///
  /// In en, this message translates to:
  /// **'Saved time'**
  String get cap24MoreSheetSavedTimeTitle;

  /// Cap 26.4 half-sheet placeholder when a resolved meta value is unavailable (em dash U+2014)
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get cap24MoreSheetUnavailableValue;

  /// Cap 24 half-sheet honesty note shown in the i-bubble (finest resolution here; file vs library + device TZ; hour common, date rare vs Overlay ~ day)
  ///
  /// In en, this message translates to:
  /// **'This is the finest time resolution WakeTok can show here for this item. Time zone differences may still shift it by a few hours; in extreme cases, even the date may not match the date on Browse (marked with ~). Because time can be stored differently in the file and in the Photos library, and may be affected by your current time zone, neither is guaranteed to match the exact moment this item was created or saved.'**
  String get cap24SoftDeleteSheetMinuteTimezoneNote;

  /// Semantics / accessibility label for Cap 24 half-sheet circular i next to the minute row
  ///
  /// In en, this message translates to:
  /// **'More about this time'**
  String get cap24SoftDeleteSheetMinuteTimezoneInfoSemantics;

  /// Cap 24.3 bare EXIF/TIFF civil clock with seconds
  ///
  /// In en, this message translates to:
  /// **'{year}-{month}-{day} {hour}:{minute}:{second}'**
  String cap24SoftDeleteSheetExactMinute(
    String year,
    String month,
    String day,
    String hour,
    String minute,
    String second,
  );

  /// Cap 24.3 bare EXIF/TIFF civil clock without seconds
  ///
  /// In en, this message translates to:
  /// **'{year}-{month}-{day} {hour}:{minute}'**
  String cap24SoftDeleteSheetExactMinuteNoSeconds(
    String year,
    String month,
    String day,
    String hour,
    String minute,
  );

  /// Cap 24 Instant→device-local minute landmark (no tilde; library-sourced)
  ///
  /// In en, this message translates to:
  /// **'{year}-{month}-{day} {hour}:{minute}'**
  String cap24SoftDeleteSheetExactMinuteLibrary(
    String year,
    String month,
    String day,
    String hour,
    String minute,
  );

  /// Cap 24 soft-delete Host failure toast (same style family as Cap 19 add-to-album error; new key)
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete. Try again.'**
  String get cap24SoftDeleteFailed;

  /// Cap 25.3 Action Column Share entry accessibility label
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get cap25ShareEntryIconSemantics;

  /// Cap 25 Share Host present/prepare failure toast (Cap 19 toast style; ADR-051 D4/D5)
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t share. Try again.'**
  String get cap25ShareFailed;
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
