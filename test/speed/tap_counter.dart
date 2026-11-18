// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Counts the taps of a speed-target flow. Every speed test in the project
/// drives the screen through one of these.
///
/// A counted tap is any tap made with [tap] and any keyboard action made with
/// [keyboardAction] (the done key, the next key). Typing with [type] is not
/// counted, matching docs/design/speed-targets.md. A flow ends with
/// [expectCount]. Nothing here pumps frames: the flow does that itself.
class TapCounter {
  TapCounter(this.tester);

  final WidgetTester tester;

  /// The taps and keyboard actions counted so far.
  int count = 0;

  /// One counted tap.
  Future<void> tap(Finder finder) async {
    count++;
    await tester.tap(finder);
  }

  /// One counted keyboard action, for example the done key.
  Future<void> keyboardAction([
    TextInputAction action = TextInputAction.done,
  ]) async {
    count++;
    await tester.testTextInput.receiveAction(action);
  }

  /// Typing is free, but only into a field that already has focus: enterText
  /// would focus any field by itself and hide a tap the user would need.
  /// Replaces the text in the field.
  Future<void> type(Finder finder, String text) {
    final editable = find.descendant(
      of: finder,
      matching: find.byType(EditableText),
    );
    final target = editable.evaluate().isEmpty ? finder : editable;
    expect(
      tester.widget<EditableText>(target).focusNode.hasFocus,
      isTrue,
      reason: 'the field needs a tap first, and that tap must be counted',
    );
    return tester.enterText(finder, text);
  }

  /// Fails with a plain message when the flow used another number of taps.
  void expectCount(int expected, {String? flow}) {
    expect(
      count,
      expected,
      reason: '${flow ?? 'The flow'} should take $expected counted taps',
    );
  }
}
