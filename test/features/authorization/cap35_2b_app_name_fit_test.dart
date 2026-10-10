import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/features/authorization/permission_blocked_page.dart';
import 'package:waketok/features/authorization/permission_page_style.dart';
import 'package:waketok/features/authorization/permission_request_page.dart';

import 'permission_ui_test_harness.dart';

const _appName = 'WakeTok';
const _pageWidth = 375.0;
const _contentLeft = 24.0;
const _contentRight = _pageWidth - 24;

/// Glyph boxes carry half the theme letter spacing on each side.
const _letterSpacingSlack = 0.5;
const _pages = [
  (PhotosAccess.notDetermined, PermissionRequestPage),
  (PhotosAccess.denied, PermissionBlockedPage),
];

class _BoldText implements AccessibilityFeatures {
  const _BoldText();

  @override
  bool get boldText => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => false;
}

void _setSurface(WidgetTester tester, {double textScale = 1}) {
  tester.view.physicalSize = const Size(_pageWidth, 667);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

Future<void> _pumpPage(WidgetTester tester, PhotosAccess access) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    permissionUiHarness(
      repo: ControllablePhotosAuthorizationRepository(access),
      locale: const Locale('en'),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _appNameText(Type pageType) =>
    find.descendant(of: find.byType(pageType), matching: find.text(_appName));

/// Global ink boxes of the app name, one per rendered line.
List<Rect> _inkLines(WidgetTester tester, Finder text) {
  final paragraph = tester.renderObject<RenderParagraph>(text);
  final byTop = <double, Rect>{};
  for (final box in paragraph.getBoxesForSelection(
    const TextSelection(baseOffset: 0, extentOffset: _appName.length),
  )) {
    final rect = Rect.fromPoints(
      paragraph.localToGlobal(Offset(box.left, box.top)),
      paragraph.localToGlobal(Offset(box.right, box.bottom)),
    );
    final line = byTop[box.top];
    byTop[box.top] = line == null ? rect : line.expandToInclude(rect);
  }
  return byTop.values.toList();
}

Rect _globalSemanticsRect(SemanticsNode node) {
  var rect = node.rect;
  for (SemanticsNode? n = node; n != null; n = n.parent) {
    if (n.transform != null) {
      rect = MatrixUtils.transformRect(n.transform!, rect);
    }
  }
  return rect;
}

/// One app name node whose VoiceOver frame is the laid-out text box.
void _expectSingleNodeOnText(WidgetTester tester, Finder text, String reason) {
  final nodes = find.bySemanticsLabel(_appName);
  expect(nodes, findsOneWidget, reason: reason);
  final semanticsRect = _globalSemanticsRect(tester.getSemantics(nodes));
  final textRect = tester.getRect(text);
  for (final (semantics, laidOut) in [
    (semanticsRect.left, textRect.left),
    (semanticsRect.top, textRect.top),
    (semanticsRect.right, textRect.right),
    (semanticsRect.bottom, textRect.bottom),
  ]) {
    expect(semantics, moreOrLessEquals(laidOut, epsilon: 0.01), reason: reason);
  }
}

void main() {
  testWidgets('W-35.2b-1 at a large text size the app name stays one line, '
      'scaled down to the page width and start-aligned', (tester) async {
    final semantics = tester.ensureSemantics();
    _setSurface(tester, textScale: 3);
    for (final bold in [false, true]) {
      if (bold) {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const _BoldText();
      }
      for (final (access, pageType) in _pages) {
        final reason = '$pageType bold=$bold';
        await _pumpPage(tester, access);
        expect(tester.takeException(), isNull, reason: reason);

        final text = _appNameText(pageType);
        final paragraph = tester.renderObject<RenderParagraph>(text);
        expect(
          paragraph.text.style!.fontSize,
          lessThan(kPermissionAppNameFontSize * 3),
          reason: '$reason: scaled down from the requested size',
        );
        final lines = _inkLines(tester, text);
        expect(lines, hasLength(1), reason: reason);
        expect(
          lines.single.left,
          moreOrLessEquals(_contentLeft, epsilon: _letterSpacingSlack),
          reason: reason,
        );
        expect(
          lines.single.right,
          lessThanOrEqualTo(_contentRight + _letterSpacingSlack),
          reason: '$reason: inside the page',
        );
        expect(
          lines.single.right,
          greaterThan(_contentRight - 1),
          reason: '$reason: fills the page width',
        );
        _expectSingleNodeOnText(tester, text, reason);
      }
    }
    semantics.dispose();
  });

  testWidgets('W-35.2b-2 at the default text size the app name keeps its '
      'size and its VoiceOver frame spans the page width', (tester) async {
    final semantics = tester.ensureSemantics();
    _setSurface(tester);
    for (final (access, pageType) in _pages) {
      final reason = '$pageType';
      await _pumpPage(tester, access);

      final text = _appNameText(pageType);
      final paragraph = tester.renderObject<RenderParagraph>(text);
      expect(
        paragraph.text.style!.fontSize,
        kPermissionAppNameFontSize,
        reason: reason,
      );
      final lines = _inkLines(tester, text);
      expect(lines, hasLength(1), reason: reason);
      expect(
        lines.single.left,
        moreOrLessEquals(_contentLeft, epsilon: _letterSpacingSlack),
        reason: reason,
      );
      final textRect = tester.getRect(text);
      expect(textRect.left, moreOrLessEquals(_contentLeft), reason: reason);
      expect(textRect.right, moreOrLessEquals(_contentRight), reason: reason);
      _expectSingleNodeOnText(tester, text, reason);
    }
    semantics.dispose();
  });
}
