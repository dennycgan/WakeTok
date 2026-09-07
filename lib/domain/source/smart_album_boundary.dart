/// Cap 21.4b Build catalog smart-album whitelist / order / Host brute band.
///
/// Product table: `docs/reference/cap21-smart-album-boundary.md`.
/// Host `PhotoLibraryService.smartAlbumBruteRawValues` must stay in sync with
/// [hostBruteRawValues].
library;

/// PhotoKit smart-album subtype raw values + Build catalog policy.
abstract final class SmartAlbumBoundary {
  /// Favorites — pinned first when non-empty.
  static const int favorites = 203;

  /// Fixed product priority after Favorites (not count-sorted).
  static const List<int> fixedOrderAfterFavorites = <int>[
    213, // Live Photos
    211, // Screenshots
    214, // Animated
    210, // Selfies
    202, // Videos
    220, // Screen Recordings
  ];

  /// Remaining whitelist, subtype ascending (stable, measurable).
  static const List<int> remainingAscending = <int>[
    201, // Panoramas
    204, // Time-lapse
    207, // Bursts
    208, // Slo-mo
    212, // Portrait
    215, // Long Exposure
    217, // RAW
    218, // Cinematic
    219, // Spatial
    221, // Dual Capture
  ];

  /// Explicit excludes (reference; omission from whitelist also excludes).
  static const Set<int> explicitExcludes = <int>{
    205, // Hidden (Cap 11.2)
    206, // Recently Added
    209, // Recents
    216, // Unable to Upload
    1000000201, // Recently Deleted (undocumented; not 201 Panoramas)
    1000000218, // Recently Saved
    1000000219, // Recovered
  };

  /// Full whitelist set (pin + fixed + remaining).
  static final Set<int> whitelist = <int>{
    favorites,
    ...fixedOrderAfterFavorites,
    ...remainingAscending,
  };

  /// Host brute-scan band — must include values `.any` historically omitted
  /// (206, 216) plus undocumented neighbors seen on device.
  static final List<int> hostBruteRawValues = <int>[
    ...List<int>.generate(41, (i) => 200 + i),
    1000000201,
    1000000218,
    1000000219,
    1000000220,
    1000000221,
  ];

  static bool isWhitelisted(int subtype) => whitelist.contains(subtype);

  /// Sort visible (already non-empty) smart sources by product order.
  ///
  /// [subtypeOf] returns the collection subtype for each item.
  static List<T> sortForDisplay<T>(
    List<T> items, {
    required int Function(T item) subtypeOf,
  }) {
    int rank(int subtype) {
      if (subtype == favorites) {
        return 0;
      }
      final fixed = fixedOrderAfterFavorites.indexOf(subtype);
      if (fixed >= 0) {
        return 1 + fixed;
      }
      final rem = remainingAscending.indexOf(subtype);
      if (rem >= 0) {
        return 100 + rem;
      }
      return 1000 + subtype;
    }

    final copy = List<T>.from(items);
    copy.sort((a, b) {
      final ra = rank(subtypeOf(a));
      final rb = rank(subtypeOf(b));
      if (ra != rb) {
        return ra.compareTo(rb);
      }
      return subtypeOf(a).compareTo(subtypeOf(b));
    });
    return copy;
  }
}
