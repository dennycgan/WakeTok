import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/domain/onboarding/cap30_first_launch_guide_preferences.dart';

/// Bound at composition root to [Cap30FirstLaunchGuidePreferencesStore]
/// (Cap 30.2).
final cap30FirstLaunchGuidePreferencesProvider =
    Provider<Cap30FirstLaunchGuidePreferences>(
  (ref) => throw UnimplementedError(
    'cap30FirstLaunchGuidePreferencesProvider must be overridden at '
    'the composition root',
  ),
);
