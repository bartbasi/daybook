// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:flutter/material.dart';

import '../../app.dart';
import '../../strings.dart';

/// A one-line message with an optional Undo, read aloud when it appears. Home
/// shows it above the action bar; the food screen shows it under the meal
/// chips, so it never covers the totals bar or Save.
class ConfirmBar extends StatelessWidget {
  const ConfirmBar({super.key, required this.message, this.onUndo});

  final String message;

  /// Null hides the Undo button.
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: ContentWidth(
        child: Padding(
          padding: const EdgeInsets.only(left: 16, right: 8),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(message),
                  ),
                ),
              ),
              if (onUndo != null)
                TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: onUndo,
                  child: const Text(S.undo),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
