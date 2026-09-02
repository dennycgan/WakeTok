import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/features/main_browse/cap19_actions_half_sheet.dart';
import 'package:waketok/features/main_browse/cap19_entry_layout.dart';
import 'package:waketok/l10n/app_localizations.dart';

/// Cap 19.4 / ADR-040 D15: fixed bottom-trailing entry on Browse media area.
class Cap19EntryIcon extends StatelessWidget {
  const Cap19EntryIcon({super.key, required this.access});

  final PhotosAccess access;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;

    return Semantics(
      button: true,
      label: l10n.cap19EntryIconSemantics,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('cap19EntryIcon'),
          onTap: () => showCap19ActionsHalfSheet(context, access: access),
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              CupertinoIcons.rectangle_stack_badge_plus,
              color: tokens.onMedia,
              shadows: tokens.onMediaLabelShadows,
            ),
          ),
        ),
      ),
    );
  }
}

/// Positions [Cap19EntryIcon] on the Browse pane with a shell-fixed bottom
/// inset (see [cap19EntryIconBottomInset]).
class Cap19EntryIconSlot extends StatelessWidget {
  const Cap19EntryIconSlot({super.key, required this.access});

  final PhotosAccess access;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: kCap19EntryIconTrailingInset,
      bottom: cap19EntryIconBottomInset(),
      child: Cap19EntryIcon(access: access),
    );
  }
}
