import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/domain/browse/new_round_toast_preferences.dart';

/// Bound at composition root to [NewRoundToastPreferencesStore] (Cap 22.5).
final newRoundToastPreferencesProvider = Provider<NewRoundToastPreferences>(
  (ref) => throw UnimplementedError(
    'newRoundToastPreferencesProvider must be overridden at the composition root',
  ),
);

/// Bumped when Settings toggles the new-round toast preference.
final newRoundToastPrefsRevisionProvider =
    NotifierProvider<NewRoundToastPrefsRevision, int>(
  NewRoundToastPrefsRevision.new,
);

class NewRoundToastPrefsRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}
