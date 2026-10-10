import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/features/authorization/open_app_settings.dart';
import 'package:waketok/features/authorization/permission_blocked_page.dart';
import 'package:waketok/features/authorization/permission_request_page.dart';

import 'permission_ui_test_harness.dart';

const _en = Locale('en');

void _setSurface(WidgetTester tester, Size size, {double textScale = 1}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

Future<ControllablePhotosAuthorizationRepository> _pumpPage(
  WidgetTester tester,
  PhotosAccess access, {
  OpenAppSettings? openSettings,
}) async {
  final repo = ControllablePhotosAuthorizationRepository(access);
  await tester.pumpWidget(
    permissionUiHarness(repo: repo, locale: _en, openSettings: openSettings),
  );
  await tester.pumpAndSettle();
  return repo;
}

Finder _in(Type pageType, Type widgetType) => find.descendant(
  of: find.byType(pageType),
  matching: find.byType(widgetType),
);

RenderParagraph _label(WidgetTester tester, Finder button) =>
    tester.renderObject<RenderParagraph>(
      find.descendant(of: button, matching: find.byType(RichText)),
    );

/// Global left / right ink edges of each rendered label line, ignoring
/// spaces at line ends.
List<({double left, double right})> _labelLines(
  WidgetTester tester,
  Finder button,
) {
  final paragraph = _label(tester, button);
  final text = paragraph.text.toPlainText();
  final byTop = <double, ({double left, double right})>{};
  for (final word in RegExp(r'\S+').allMatches(text)) {
    final boxes = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: word.start, extentOffset: word.end),
    );
    for (final box in boxes) {
      final left = paragraph.localToGlobal(Offset(box.left, box.top)).dx;
      final right = paragraph.localToGlobal(Offset(box.right, box.top)).dx;
      final line = byTop[box.top];
      byTop[box.top] = line == null
          ? (left: left, right: right)
          : (
              left: left < line.left ? left : line.left,
              right: right > line.right ? right : line.right,
            );
    }
  }
  final tops = byTop.keys.toList()..sort();
  return [for (final top in tops) byTop[top]!];
}

void _expectWrappedAndCentred(WidgetTester tester, Finder button) {
  final buttonRect = tester.getRect(button);
  final lines = _labelLines(tester, button);
  expect(lines.length, greaterThan(1), reason: 'label should wrap');
  for (final line in lines) {
    expect(
      line.left - buttonRect.left,
      moreOrLessEquals(buttonRect.right - line.right, epsilon: 0.5),
      reason: 'each line is centred in the button',
    );
  }
  final label = _label(tester, button);
  final labelTop = label.localToGlobal(Offset.zero).dy;
  final labelBottom = labelTop + label.size.height;
  expect(labelTop - buttonRect.top, moreOrLessEquals(12));
  expect(buttonRect.bottom - labelBottom, moreOrLessEquals(12));
  expect(buttonRect.height, moreOrLessEquals(label.size.height + 24));
}

void main() {
  testWidgets('W-35.2-1 CTA padding is 16 horizontal and 12 vertical with a '
      '60 pt minimum height on both pages', (tester) async {
    for (final (access, pageType) in const [
      (PhotosAccess.notDetermined, PermissionRequestPage),
      (PhotosAccess.denied, PermissionBlockedPage),
    ]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpPage(tester, access);
      final style = tester
          .widget<FilledButton>(_in(pageType, FilledButton))
          .style!;
      expect(
        style.padding!.resolve(<WidgetState>{}),
        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        reason: '$pageType',
      );
      expect(
        style.minimumSize!.resolve(<WidgetState>{}),
        const Size.fromHeight(60),
        reason: '$pageType',
      );
    }
  });

  testWidgets('W-35.2-2 a one-line label keeps the 60 pt button with the '
      'label vertically centred', (tester) async {
    _setSurface(tester, const Size(800, 900));
    await _pumpPage(tester, PhotosAccess.notDetermined);

    final button = _in(PermissionRequestPage, FilledButton);
    final buttonRect = tester.getRect(button);
    expect(_labelLines(tester, button), hasLength(1));
    expect(buttonRect.height, moreOrLessEquals(60));
    final label = _label(tester, button);
    final labelTop = label.localToGlobal(Offset.zero).dy;
    expect(
      labelTop - buttonRect.top,
      moreOrLessEquals(buttonRect.bottom - (labelTop + label.size.height)),
    );
  });

  testWidgets('W-35.2-3 request page at 375 pt wraps the label with every '
      'line centred and the button grown', (tester) async {
    _setSurface(tester, const Size(375, 667));
    await _pumpPage(tester, PhotosAccess.notDetermined);

    _expectWrappedAndCentred(tester, _in(PermissionRequestPage, FilledButton));
  });

  testWidgets('W-35.2-4 blocked page at 375 pt and larger text wraps the '
      'label with every line centred and the button grown', (tester) async {
    _setSurface(tester, const Size(375, 667), textScale: 1.5);
    await _pumpPage(tester, PhotosAccess.denied);

    _expectWrappedAndCentred(tester, _in(PermissionBlockedPage, FilledButton));
  });

  testWidgets('W-35.2-5a content that fits keeps the page static: CTA at the '
      'bottom and no drag or bounce', (tester) async {
    _setSurface(tester, const Size(430, 1000));
    for (final (access, pageType) in const [
      (PhotosAccess.notDetermined, PermissionRequestPage),
      (PhotosAccess.denied, PermissionBlockedPage),
    ]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpPage(tester, access);

      final position = tester
          .state<ScrollableState>(_in(pageType, Scrollable))
          .position;
      expect(position.maxScrollExtent, 0, reason: '$pageType fits');
      final button = _in(pageType, FilledButton);
      expect(tester.getRect(button).bottom, moreOrLessEquals(1000 - 24));

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(pageType)),
      );
      await gesture.moveBy(const Offset(0, 120));
      await tester.pump();
      expect(position.pixels, 0, reason: '$pageType pulled down');
      expect(tester.getRect(button).bottom, moreOrLessEquals(1000 - 24));
      await gesture.moveBy(const Offset(0, -240));
      await tester.pump();
      expect(position.pixels, 0, reason: '$pageType pushed up');
      expect(tester.getRect(button).bottom, moreOrLessEquals(1000 - 24));
      await gesture.up();
      await tester.pumpAndSettle();
    }
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('W-35.2-5b content taller than the screen scrolls without '
      'overflow and the CTA stays reachable', (tester) async {
    _setSurface(tester, const Size(375, 667), textScale: 3);

    final repo = await _pumpPage(tester, PhotosAccess.notDetermined);
    repo.requestAccessHold = Completer<void>();
    expect(tester.takeException(), isNull);
    await _scrollToAndTap(tester, PermissionRequestPage);
    expect(repo.requestCalls, 1);

    var settingsOpened = 0;
    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpPage(
      tester,
      PhotosAccess.denied,
      openSettings: () async => settingsOpened += 1,
    );
    expect(tester.takeException(), isNull);
    await _scrollToAndTap(tester, PermissionBlockedPage);
    expect(settingsOpened, 1);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}

Future<void> _scrollToAndTap(WidgetTester tester, Type pageType) async {
  final scrollable = _in(pageType, Scrollable);
  expect(
    tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
    greaterThan(0),
    reason: '$pageType should need scrolling',
  );
  final button = _in(pageType, FilledButton);
  await tester.scrollUntilVisible(button, 200, scrollable: scrollable);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pump();
}
