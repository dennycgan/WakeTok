import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/app/browse/browse_session_providers.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';

/// Cap 28.5 / ADR-058 Decision 4: single authority for **in-app** Photos
/// access-scope Session boundaries.
///
/// **Reuse / review discipline (do not bypass):**
/// - [notifyAccessScopePossiblyChanged] is the **only** writer that marks
///   dirty for in-app scope changes (Limited picker dismiss, grant-complete).
/// - This notifier is the **only** consumer allowed to call
///   [BrowseSessionNotifier.restartSession] **because of** an in-app access-
///   scope change. Other Session boundaries (Origin real boundary, Confirm,
///   etc.) keep their own `restartSession` call sites — do **not** route
///   those through here, and do **not** add a second in-app-scope
///   `restartSession` beside this authority.
/// - Out of Cap 28.5: user changes Photos access in **iOS Settings** then
///   resumes the app — existing [PhotosAccessGate] auth refresh path only;
///   do **not** mark dirty here.
/// - Debt **421** Limited manage UI must call through
///   [PhotosAuthorizationNotifier.presentLimitedLibraryPicker] (or this
///   API directly after dismiss) — do not invent a parallel restart path.
///
/// State is the pending dirty generation (`null` = clean). Coalesce: repeat
/// [notifyAccessScopePossiblyChanged] while dirty keeps the same generation.
final accessScopeAuthorityProvider =
    NotifierProvider<AccessScopeAuthorityNotifier, int?>(
      AccessScopeAuthorityNotifier.new,
    );

class AccessScopeAuthorityNotifier extends Notifier<int?> {
  int _nextGeneration = 0;
  bool _consumeInFlight = false;

  @override
  int? build() {
    // Settings → Browse: consume deferred dirty (ADR-058 D4).
    ref.listen<MainBrowseDestination>(mainBrowseDestinationProvider, (
      previous,
      next,
    ) {
      if (next == MainBrowseDestination.browse) {
        unawaited(_consumeIfNeeded());
      }
    });
    return null;
  }

  /// Marks access scope possibly changed (Limited picker every dismiss;
  /// grant-complete). If destination is already Browse, consumes immediately;
  /// if Settings, defers until Browse.
  void notifyAccessScopePossiblyChanged() {
    // D1 coalesce: one pending generation until clear.
    state ??= ++_nextGeneration;
    if (ref.read(mainBrowseDestinationProvider) ==
        MainBrowseDestination.browse) {
      unawaited(_consumeIfNeeded());
    }
  }

  /// D2: while a restart runs, further notifies only re-set pending; when the
  /// in-flight restart finishes, consume again if still dirty.
  Future<void> _consumeIfNeeded() async {
    if (_consumeInFlight) {
      return;
    }
    _consumeInFlight = true;
    try {
      while (ref.mounted && state != null) {
        state = null;
        await ref.read(browseSessionProvider.notifier).restartSession();
      }
    } finally {
      _consumeInFlight = false;
    }
  }
}
