import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:waketok/core/config/app_links.dart';

/// Opens the privacy policy in the system browser.
///
/// Overridable in tests so widget tests do not launch the browser.
typedef OpenPrivacyPolicy = Future<void> Function();

final openPrivacyPolicyProvider = Provider<OpenPrivacyPolicy>((ref) {
  return () async {
    await launchUrl(
      Uri.parse(kPrivacyPolicyUrl),
      mode: LaunchMode.externalApplication,
    );
  };
});
