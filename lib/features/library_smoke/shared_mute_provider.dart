import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Cap 9.6 / ADR-019: shared Mute preference (default unmuted).
///
/// Source of truth for Feed video + Live apply. Not persisted; product Mute
/// rail is a later capability. Debug toggle lives on library_smoke.
final sharedMuteProvider = NotifierProvider<SharedMuteNotifier, bool>(
  SharedMuteNotifier.new,
);

class SharedMuteNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setMuted(bool muted) => state = muted;

  void toggle() => state = !state;
}
