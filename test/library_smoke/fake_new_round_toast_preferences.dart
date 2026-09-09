import 'package:waketok/domain/browse/new_round_toast_preferences.dart';

class FakeNewRoundToastPreferences implements NewRoundToastPreferences {
  bool newRoundToastEnabled = true;

  @override
  Future<bool> isNewRoundToastEnabled() async => newRoundToastEnabled;

  @override
  Future<void> setNewRoundToastEnabled(bool value) async {
    newRoundToastEnabled = value;
  }
}
