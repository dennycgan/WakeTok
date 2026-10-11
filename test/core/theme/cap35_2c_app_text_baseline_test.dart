import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/core/theme/app_text_baseline.dart';
import 'package:waketok/core/theme/status_bar_style.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/authorization/photos_access.dart';

import '../../features/authorization/permission_ui_test_harness.dart';

/// iOS body text at the largest accessibility size (53 pt) over 17 pt.
const _largestAccessibilityScale = 53 / 17;

class _BoldText implements AccessibilityFeatures {
  const _BoldText();

  @override
  bool get boldText => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => false;
}

void _setSystemText(WidgetTester tester) {
  tester.platformDispatcher.textScaleFactorTestValue =
      _largestAccessibilityScale;
  tester.platformDispatcher.accessibilityFeaturesTestValue = const _BoldText();
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

void _setSeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(375, 667);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

RenderParagraph _paragraph(WidgetTester tester, String text) =>
    tester.renderObject<RenderParagraph>(find.text(text));

void _expectBaseline(WidgetTester tester, String text) {
  final paragraph = _paragraph(tester, text);
  expect(paragraph.textScaler, TextScaler.noScaling, reason: text);
  expect(
    paragraph.text.style?.fontWeight,
    isNot(FontWeight.bold),
    reason: text,
  );
}

/// Text, global rect and weight of every visible paragraph, in tree order.
List<(String, Rect, FontWeight?)> _paragraphs(WidgetTester tester) {
  return [
    for (final element in find.byType(RichText).evaluate())
      () {
        final box = element.renderObject! as RenderParagraph;
        final topLeft = box.localToGlobal(Offset.zero);
        return (
          box.text.toPlainText(),
          topLeft & box.size,
          box.text.style?.fontWeight,
        );
      }(),
  ];
}

void main() {
  testWidgets('W-35.2c-1 page, dialog, half sheet and overlay text ignore the '
      'system text size and Bold Text', (tester) async {
    _setSystemText(tester);
    final anchor = GlobalKey();

    Future<void> pumpApp(TransitionBuilder builder) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MaterialApp(
          theme: waketokTheme(Brightness.light),
          builder: builder,
          home: Scaffold(body: Text('page', key: anchor)),
        ),
      );
    }

    await pumpApp(statusBarBaselineBuilder);
    final reached = _paragraph(tester, 'page');
    expect(reached.textScaler, isNot(TextScaler.noScaling));
    expect(reached.text.style?.fontWeight, FontWeight.bold);

    await pumpApp(appRootBuilder);
    _expectBaseline(tester, 'page');

    final context = anchor.currentContext!;
    showDialog<void>(
      context: context,
      builder: (_) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [Text('dialog'), TextField()],
        ),
      ),
    );
    await tester.pumpAndSettle();
    _expectBaseline(tester, 'dialog');
    final editable = tester
        .state<EditableTextState>(find.byType(EditableText))
        .renderEditable;
    expect(editable.textScaler, TextScaler.noScaling);
    expect(editable.text?.style?.fontWeight, isNot(FontWeight.bold));

    showModalBottomSheet<void>(
      context: context,
      builder: (_) => const Text('sheet'),
    );
    await tester.pumpAndSettle();
    _expectBaseline(tester, 'sheet');

    final entry = OverlayEntry(
      builder: (_) => const Center(child: Text('overlay')),
    );
    Overlay.of(context).insert(entry);
    await tester.pump();
    _expectBaseline(tester, 'overlay');
    entry.remove();
    entry.dispose();
  });

  testWidgets('W-35.2c-2 Browse shell on a 375 pt SE at the largest '
      'accessibility size with Bold Text lays out text as at the default '
      'size', (tester) async {
    _setSeSurface(tester);

    Future<void> pumpBrowse({required bool appTextBaseline}) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        permissionUiHarness(
          repo: ControllablePhotosAuthorizationRepository(PhotosAccess.full),
          locale: const Locale('en'),
          appTextBaseline: appTextBaseline,
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpBrowse(appTextBaseline: true);
    final atDefault = _paragraphs(tester);
    expect(atDefault, isNotEmpty);

    _setSystemText(tester);
    await pumpBrowse(appTextBaseline: false);
    expect(
      tester.takeException(),
      isNotNull,
      reason: 'without the baseline the shell overflows',
    );

    await pumpBrowse(appTextBaseline: true);
    expect(tester.takeException(), isNull);
    for (final element in find.byType(RichText).evaluate()) {
      expect(
        (element.renderObject! as RenderParagraph).textScaler,
        TextScaler.noScaling,
      );
    }
    expect(_paragraphs(tester), atDefault);
  });
}
