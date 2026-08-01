import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the iOS Settings page for this app.
///
/// Overridable in tests so widget tests do not launch system Settings.
typedef OpenAppSettings = Future<void> Function();

final openAppSettingsProvider = Provider<OpenAppSettings>((ref) {
  return () async {
    final uri = Uri.parse('app-settings:');
    await launchUrl(uri);
  };
});
