import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/presentation/presentation_media_kind.dart';
import 'package:waketok/features/main_browse/center_playback_affordance.dart';
import 'package:waketok/features/main_browse/media_chrome_layout.dart';
import 'package:waketok/features/main_browse/media_info_overlay.dart';
import 'package:waketok/features/main_browse/presentation_overlay_snapshot.dart';
import 'package:waketok/l10n/app_localizations.dart';

/// Local twin of production LIVE badge for geometry checks (private in feed).
class _LiveBadgeTwin extends StatelessWidget {
  const _LiveBadgeTwin({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    final labelStyle = tokens.labelOnMedia.copyWith(
      height: 1.0,
      shadows: tokens.onMediaLabelShadows,
    );
    final fontSize = labelStyle.fontSize ?? 12;
    return Container(
      key: const Key('mainBrowseLiveBadge'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: tokens.mediaScrim.withValues(alpha: kStatusChromeScrimOpacity),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: tokens.onMedia.withValues(alpha: kStatusChromeBorderOpacity),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: fontSize,
            height: fontSize,
            child: Center(
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: tokens.onMedia, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(label, style: labelStyle),
        ],
      ),
    );
  }
}

void main() {
  testWidgets('LIVE capsule bottom aligns with Overlay row-3 text bottom', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: waketokTheme(Brightness.dark),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              final tokens = Theme.of(context).extension<WakeTokTokens>()!;
              return Stack(
                fit: StackFit.expand,
                children: [
                  MediaInfoOverlay(
                    snapshot: PresentationOverlaySnapshot(
                      assetIdentifier: 'a',
                      createdAt: DateTime(2026, 1, 21),
                      mediaKind: PresentationMediaKind.livePhoto,
                      fileSizeBytes: 5400000,
                    ),
                  ),
                  Positioned(
                    right: kMediaChromeTrailingInset,
                    bottom: mainBrowseLiveStatusBottomInset(tokens),
                    child: const _LiveBadgeTwin(label: 'LIVE'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();

    final row3 = tester.getRect(find.byKey(const Key('mediaInfoOverlayRow3')));
    final live = tester.getRect(find.byKey(const Key('mainBrowseLiveBadge')));
    // Row-3 box bottom == text bottom (bottom-aligned glyphs).
    expect(
      live.bottom,
      moreOrLessEquals(row3.bottom, epsilon: 0.5),
      reason: 'LIVE outer bottom must match Overlay row-3 bottom',
    );
  });
}
