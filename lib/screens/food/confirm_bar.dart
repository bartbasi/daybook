// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:flutter/material.dart';

import '../../app.dart';
import '../../strings.dart';

/// A one-line message with an optional Undo, read aloud when it appears. Home
/// shows it above the action bar; the food screen shows it under the meal
/// chips, so it never covers the totals bar or Save.
class ConfirmBar extends StatelessWidget {
  const ConfirmBar({
    super.key,
    required this.message,
    this.onUndo,
    this.actionLabel,
    this.onAction,
    this.actionSpoken,
    this.maxMessageHeight,
  });

  /// When set, a long message scrolls inside this height while the buttons
  /// stay in view.
  final double? maxMessageHeight;

  final String message;

  /// Null hides the Undo button.
  final VoidCallback? onUndo;

  /// A second button, under the message, for a message that offers a way
  /// forward ("Add it as your own food"). Both or neither.
  final String? actionLabel;
  final VoidCallback? onAction;

  /// What a screen reader says for the action button, when it is longer than
  /// the visible [actionLabel].
  final String? actionSpoken;

  Widget _scrolling(Widget child) {
    final max = maxMessageHeight;
    if (max == null) return child;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: max),
      child: SingleChildScrollView(child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: ContentWidth(
        child: Padding(
          padding: const EdgeInsets.only(left: 16, right: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      liveRegion: true,
                      child: _scrolling(
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(message),
                        ),
                      ),
                    ),
                  ),
                  if (onUndo != null)
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: onUndo,
                      child: const Text(S.undo),
                    ),
                ],
              ),
              if (actionLabel != null && onAction != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: onAction,
                    child: Semantics(
                      label: actionSpoken,
                      excludeSemantics: actionSpoken != null,
                      child: Text(actionLabel!, textAlign: TextAlign.center),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
