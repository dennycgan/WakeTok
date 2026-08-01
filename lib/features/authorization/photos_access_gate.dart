import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/features/authorization/permission_blocked_page.dart';
import 'package:waketok/features/authorization/permission_request_page.dart';
import 'package:waketok/features/authorization/photos_authorization_notifier.dart';
import 'package:waketok/features/library_smoke/library_catalog_providers.dart';
import 'package:waketok/features/library_smoke/library_totals_shell_page.dart';

/// Root switcher for Photos authorization → permission UI or library shell.
///
/// On app resume, refreshes authorization status so Settings changes apply.
/// While reloading, keeps the last known [PhotosAccess] so the user does not
/// flash back to Request/Blocked during limited-picker or Settings round-trips.
class PhotosAccessGate extends ConsumerStatefulWidget {
  const PhotosAccessGate({super.key});

  @override
  ConsumerState<PhotosAccessGate> createState() => _PhotosAccessGateState();
}

class _PhotosAccessGateState extends ConsumerState<PhotosAccessGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(photosAuthorizationProvider);
      ref.invalidate(libraryTotalsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(photosAuthorizationProvider);
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;

    // Prefer last known access during reload (picker / Settings resume).
    final access = async.value;
    if (access == null) {
      if (async.hasError) {
        return Scaffold(
          backgroundColor: tokens.background,
          body: Center(
            child: Text(
              '${async.error}',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: tokens.onSurface,
                  ),
            ),
          ),
        );
      }
      return Scaffold(
        backgroundColor: tokens.background,
        body: Center(
          child: CircularProgressIndicator(color: tokens.accentProvisional),
        ),
      );
    }

    return switch (access) {
      PhotosAccess.notDetermined => const PermissionRequestPage(),
      PhotosAccess.denied || PhotosAccess.restricted =>
        PermissionBlockedPage(access: access),
      PhotosAccess.limited || PhotosAccess.full =>
        LibraryTotalsShellPage(access: access),
    };
  }
}
