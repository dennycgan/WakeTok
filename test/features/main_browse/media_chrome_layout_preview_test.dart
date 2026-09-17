import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/features/main_browse/center_playback_affordance.dart';
import 'package:waketok/features/main_browse/media_chrome_layout.dart';
import 'package:waketok/features/main_browse/media_info_overlay.dart';
import 'package:waketok/l10n/app_localizations.dart';

/// Layout-only chrome preview (not full feed). Writes PNGs via `--update-goldens`.
Future<ByteData> _fileBytes(String path) async {
  final bytes = await File(path).readAsBytes();
  return ByteData.sublistView(Uint8List.fromList(bytes));
}

Future<void> _loadPreviewFonts() async {
  final flutterRoot =
      Platform.environment['FLUTTER_ROOT'] ?? '/usr/local/share/flutter';
  final roboto = FontLoader('Roboto')
    ..addFont(
      _fileBytes(
        '$flutterRoot/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
      ),
    );
  await roboto.load();

  final home = Platform.environment['HOME'] ?? '';
  final matches = Directory('$home/.pub-cache/hosted/pub.dev')
      .listSync()
      .whereType<Directory>()
      .where((d) => d.path.contains('cupertino_icons-'))
      .toList()
    ..sort((a, b) => b.path.compareTo(a.path));
  for (final d in matches) {
    final ttf = File('${d.path}/assets/CupertinoIcons.ttf');
    if (ttf.existsSync()) {
      final icons = FontLoader('CupertinoIcons')..addFont(_fileBytes(ttf.path));
      await icons.load();
      break;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_loadPreviewFonts);

  Future<void> capture(
    WidgetTester tester, {
    required String name,
    required Widget child,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 520));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final base = waketokTheme(Brightness.dark);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: base.copyWith(
          textTheme: base.textTheme.apply(fontFamily: 'Roboto'),
          primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'Roboto'),
        ),
        home: DefaultTextStyle.merge(
          style: const TextStyle(fontFamily: 'Roboto'),
          child: child,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await expectLater(
      find.byKey(const Key('mediaChromePreviewRoot')),
      matchesGoldenFile('goldens/media_chrome_preview/$name.png'),
    );
  }

  testWidgets('preview A — meta only', (tester) async {
    await capture(
      tester,
      name: 'A_meta_only',
      child: const _Preview(
        showReset: false,
        showLive: false,
        showAlbum: false,
        showShare: false,
      ),
    );
  });

  testWidgets('preview B — meta + Reset', (tester) async {
    await capture(
      tester,
      name: 'B_reset',
      child: const _Preview(
        showReset: true,
        showLive: false,
        showAlbum: false,
        showShare: false,
      ),
    );
  });

  testWidgets('preview C — Reset + LIVE', (tester) async {
    await capture(
      tester,
      name: 'C_reset_live',
      child: const _Preview(
        showReset: true,
        showLive: true,
        showAlbum: false,
        showShare: false,
      ),
    );
  });

  testWidgets('preview D — Reset + LIVE + album', (tester) async {
    await capture(
      tester,
      name: 'D_reset_live_album',
      child: const _Preview(
        showReset: true,
        showLive: true,
        showAlbum: true,
        showShare: false,
      ),
    );
  });

  testWidgets('preview E — full + share placeholder', (tester) async {
    await capture(
      tester,
      name: 'E_full_share_placeholder',
      child: const _Preview(
        showReset: true,
        showLive: true,
        showAlbum: true,
        showShare: true,
      ),
    );
  });

  testWidgets('preview LIVE black — visibility', (tester) async {
    await capture(
      tester,
      name: 'LIVE_black_visibility_candidate',
      child: const _Preview(
        showReset: false,
        showLive: true,
        showAlbum: false,
        showShare: false,
        feedColor: Color(0xFF000000),
      ),
    );
  });

  testWidgets('preview LIVE light — shell check', (tester) async {
    await capture(
      tester,
      name: 'LIVE_light_shell_check',
      child: const _Preview(
        showReset: false,
        showLive: true,
        showAlbum: false,
        showShare: false,
        feedColor: Color(0xFFE8E4D9),
      ),
    );
  });
}

class _Preview extends StatelessWidget {
  const _Preview({
    required this.showReset,
    required this.showLive,
    required this.showAlbum,
    required this.showShare,
    this.feedColor = const Color(0xFF000000),
  });

  final bool showReset;
  final bool showLive;
  final bool showAlbum;
  final bool showShare;
  final Color feedColor;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    final style = tokens.labelOnMedia.copyWith(
      fontFamily: 'Roboto',
      shadows: tokens.onMediaLabelShadows,
    );
    // Production Overlay bottom (scrubber timestamp text-bottom lock).
    final metaBottom = mainBrowseMediaOverlayBottomInset(tokens);
    const metaRows = MediaInfoOverlay.baseRowCount;
    const metaHeight = MediaInfoOverlay.rowHeight * metaRows;
    final resetBottom = metaBottom + metaHeight + kResetAboveMetaGap;
    final iconSize = style.fontSize ?? 12;

    const rows = <String>[
      '7 months ago',
      '~ 2026-01-21',
      'Live Photo · 5.4 MB',
    ];

    return Scaffold(
      backgroundColor: feedColor,
      body: RepaintBoundary(
        key: const Key('mediaChromePreviewRoot'),
        child: ColoredBox(
          color: feedColor,
          child: Stack(
            children: [
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: 56,
                  color: const Color(0xFF1C1C1E),
                  alignment: Alignment.center,
                  child: Text('Browse · Clips · Auto · Settings', style: style),
                ),
              ),
              Positioned(
                left: kMediaChromeLeadingInset,
                right: kMediaChromeOverlayTrailingInset,
                bottom: metaBottom,
                child: Column(
                  key: const Key('previewMeta'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final line in rows)
                      SizedBox(
                        height: MediaInfoOverlay.rowHeight,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(line, style: style),
                        ),
                      ),
                  ],
                ),
              ),
              if (showReset)
                Positioned(
                  left: kMediaChromeLeadingInset,
                  bottom: resetBottom,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: tokens.onMediaPillFill,
                      borderRadius: BorderRadius.circular(kResetMinHitEdge),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: kResetPillHorizontalPad,
                        vertical: kResetPillVerticalPad,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.arrow_clockwise,
                            color: tokens.onMedia,
                            size: iconSize,
                          ),
                          const SizedBox(width: kResetIconLabelGap),
                          Text('Reset', style: style),
                        ],
                      ),
                    ),
                  ),
                ),
              if (showLive)
                Positioned(
                  left: kLiveBadgeLeadingInset,
                  top: mainBrowseLiveBadgeTopInset(
                    mediaQueryPaddingTop: MediaQuery.paddingOf(context).top,
                    limitedCreateHelperBand: false,
                  ),
                  child: _PreviewLiveBadge(style: style, tokens: tokens),
                ),
              if (showAlbum)
                Positioned(
                  right: kMediaChromeTrailingInset,
                  // Match production: icon bottom == Reset bottom.
                  bottom: resetBottom -
                      (kActionColumnHitSize - kActionColumnIconSize) / 2,
                  child: _PreviewActionIcon(
                    icon: CupertinoIcons.rectangle_stack_badge_plus,
                    tokens: tokens,
                  ),
                ),
              if (showShare)
                Positioned(
                  right: kMediaChromeTrailingInset,
                  bottom: actionColumnBottomInsetForIndex(
                    1,
                    resetBottom -
                        (kActionColumnHitSize - kActionColumnIconSize) / 2,
                  ),
                  child: _PreviewActionIcon(
                    icon: CupertinoIcons.share,
                    tokens: tokens,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewLiveBadge extends StatelessWidget {
  const _PreviewLiveBadge({required this.style, required this.tokens});

  final TextStyle style;
  final WakeTokTokens tokens;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: tokens.mediaScrim.withValues(alpha: kStatusChromeScrimOpacity),
        shape: StadiumBorder(
          side: BorderSide(
            color: tokens.onMedia.withValues(alpha: kStatusChromeBorderOpacity),
            width: kStatusChromeBorderWidth,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: kLiveBadgeHorizontalPad,
          vertical: kLiveBadgeVerticalPad,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: kLiveBadgeDotSize,
              height: kLiveBadgeDotSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: tokens.onMedia, width: 1.25),
              ),
            ),
            const SizedBox(width: kLiveBadgeDotLabelGap),
            Text('LIVE', style: style.copyWith(height: 1.0)),
          ],
        ),
      ),
    );
  }
}

class _PreviewActionIcon extends StatelessWidget {
  const _PreviewActionIcon({required this.icon, required this.tokens});

  final IconData icon;
  final WakeTokTokens tokens;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: kActionColumnHitSize,
      height: kActionColumnHitSize,
      child: Center(
        child: Icon(
          icon,
          size: kActionColumnIconSize,
          color: tokens.onMedia,
          shadows: tokens.onMediaLabelShadows,
        ),
      ),
    );
  }
}
