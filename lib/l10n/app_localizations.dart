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
