import 'package:flutter/foundation.dart';

/// Package name shown on the licence page for the Material Icons font.
const materialIconsLicensePackage = 'Material Icons';

/// CC BY 4.0 attribution for the Material Icons font. Flutter's generated
/// NOTICES does not include it, and release builds ship a tree-shaken subset
/// of the font, so the notice states the modification.
const materialIconsLicenseText =
    'Copyright 2019 Google LLC. All Rights Reserved.\n'
    '\n'
    'Material Icons by Google, licensed under the Creative Commons '
    'Attribution 4.0 International Public License (CC BY 4.0): '
    'https://creativecommons.org/licenses/by/4.0/legalcode\n'
    '\n'
    'Provided as is, without warranties; see section 5 of the licence for '
    'the full disclaimer.\n'
    '\n'
    'Modified: WakeTok includes a subset of the font that keeps only the '
    'icons the app uses.';

/// Adds licence entries that Flutter's generated NOTICES does not cover.
/// Call once from `main()`.
void registerThirdPartyLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks([
      materialIconsLicensePackage,
    ], materialIconsLicenseText);
  });
}
