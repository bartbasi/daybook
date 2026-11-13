// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:flutter/material.dart';

import '../../app.dart';
import '../../strings.dart';

/// A one-line message with an optional Undo, read aloud when it appears. Home
/// shows it above the action bar; the food screen shows it under the meal
/// chips, so it never covers the totals bar or Save.
class ConfirmBar extends StatefulWidget {
  const ConfirmBar({
    super.key,
    required this.message,
    this.onUndo,
    this.actionLabel,
    this.onAction,
    this.actionSpoken,
    this.maxMessageHeight,
  });

  /// When set, a message taller than this scrolls inside it, with a scrollbar
  /// that is always shown, while the buttons stay in view.
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

  @override
  State<ConfirmBar> createState() => _ConfirmBarState();
}

class _ConfirmBarState extends State<ConfirmBar> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  String get message => widget.message;
  VoidCallback? get onUndo => widget.onUndo;
  String? get actionLabel => widget.actionLabel;
  VoidCallback? get onAction => widget.onAction;
  String? get actionSpoken => widget.actionSpoken;

  /// The message, padded; limited to the room it is given, and when it is
  /// taller than that, scrolling with a scrollbar that is always shown.
  Widget _scrolling(Widget child) {
    final max = widget.maxMessageHeight;
    if (max == null) return child;
    return LayoutBuilder(
      builder: (context, box) {
        final painter = TextPainter(
          text: TextSpan(
            text: message,
            style: DefaultTextStyle.of(context).style,
          ),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: box.maxWidth);
        final tall = painter.height + 24 > max;
        painter.dispose();
        final scrolling = ConstrainedBox(
          constraints: BoxConstraints(maxHeight: max),
          child: SingleChildScrollView(controller: _scroll, child: child),
        );
        if (!tall) return scrolling;
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: max),
          child: Scrollbar(
            controller: _scroll,
            thumbVisibility: true,
            child: SingleChildScrollView(controller: _scroll, child: child),
          ),
        );
      },
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
