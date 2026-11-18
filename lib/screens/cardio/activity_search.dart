// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:flutter/material.dart';

import '../../data/met_table.dart';
import '../../strings.dart';
import '../../util/insets.dart';

/// Opens the search of the Compendium's activity names over the cardio screen
/// (cardio.html frame 4). Completes with the row the user picked, or null.
/// It is a sheet, not a route.
Future<MetActivity?> showActivitySearch(BuildContext context, MetTable table) {
  return showModalBottomSheet<MetActivity>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 600),
    builder: (_) => ActivitySearch(table: table),
  );
}

/// The search box stays at the top, in view with the keyboard up; the results
/// are a list under it, worded exactly as the Compendium words them.
class ActivitySearch extends StatefulWidget {
  const ActivitySearch({super.key, required this.table});

  final MetTable table;

  @override
  State<ActivitySearch> createState() => _ActivitySearchState();
}

class _ActivitySearchState extends State<ActivitySearch> {
  static const _limit = 50;

  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = _query.text.trim();
    final found = text.isEmpty
        ? const <MetActivity>[]
        : widget.table.search(text);
    final shown = found.take(_limit).toList();
    return Padding(
      padding: EdgeInsets.only(bottom: keyboardInset(context)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      S.cardioSearchTitle,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(S.cancel),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _query,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                labelText: S.cardioSearchHint,
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                if (text.isEmpty)
                  const Text(S.cardioSearchPrompt)
                else if (found.isEmpty)
                  const Text(S.cardioSearchNone)
                else ...[
                  for (final a in shown)
                    InkWell(
                      key: ValueKey('activity-${a.code}'),
                      onTap: () => Navigator.of(context).pop(a),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 56),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(a.description),
                          ),
                        ),
                      ),
                    ),
                  if (found.length > shown.length)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(S.cardioSearchMore(shown.length)),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
