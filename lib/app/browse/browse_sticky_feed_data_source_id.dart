import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Cap 27 / ADR-057 Decision 5: sticky PageView / ADR-039 data-source id.
///
/// Independent of Decision 3 (Session rebuild). Hold the pre-promote
/// `ephemeral:$id` across identity-preserving promote; clear only on a
/// **real Session boundary**. Effective id composition lives next to
/// [browseChromeStateProvider] in `browse_session_providers.dart`.
final browseStickyFeedDataSourceIdProvider =
    NotifierProvider<BrowseStickyFeedDataSourceIdNotifier, String?>(
      BrowseStickyFeedDataSourceIdNotifier.new,
    );

class BrowseStickyFeedDataSourceIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void hold(String id) {
    if (id.isEmpty) {
      return;
    }
    state = id;
  }

  void clear() {
    if (state == null) {
      return;
    }
    state = null;
  }
}
