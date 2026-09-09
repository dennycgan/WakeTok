import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/source/saved_pool_display_name.dart';
import 'package:waketok/features/main_browse/saved_pool_dialogs.dart';

void main() {
  const formatter = SavedPoolDisplayNameWeightFormatter();

  TextEditingValue _v(
    String text, {
    TextRange? composing,
    TextSelection? selection,
  }) {
    return TextEditingValue(
      text: text,
      selection: selection ?? TextSelection.collapsed(offset: text.length),
      composing: composing ?? TextRange.empty,
    );
  }

  test('U-22.5 composing Pinyin is not weight-capped mid-IME', () {
    // 9 CJK = weight 27; room for one more ideograph after 上屏.
    final committed = '中' * 9;
    final oldValue = _v(committed);
    // Pre-edit Latin would exceed 32 if counted; must still be accepted.
    final composingText = '${committed}zhong';
    final newValue = _v(
      composingText,
      composing: TextRange(start: committed.length, end: composingText.length),
    );

    final out = formatter.formatEditUpdate(oldValue, newValue);
    expect(out.text, composingText);
    expect(out.composing.isValid, isTrue);
  });

  test('U-22.5 over-budget commit truncates to in-budget prefix', () {
    final oldValue = _v('');
    final newValue = _v('中' * 15);
    final out = formatter.formatEditUpdate(oldValue, newValue);
    expect(out.text, '中' * 10);
    expect(savedPoolDisplayNameWeight(out.text), 30);
    expect(out.composing, TextRange.empty);
  });

  test('U-22.5 single-char over-budget append keeps prior prefix', () {
    final oldValue = _v('中' * 10); // weight 30
    final newValue = _v('中' * 11); // weight 33
    final out = formatter.formatEditUpdate(oldValue, newValue);
    expect(out.text, '中' * 10);
  });
}
