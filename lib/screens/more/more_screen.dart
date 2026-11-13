// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:flutter/material.dart';

import '../../app.dart';
import '../../app_scope.dart';
import '../../strings.dart';
import '../data_check_screen.dart';

/// Things set up once and changed rarely. For now: the Data check screen.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ContentWidth(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Semantics(
              header: true,
              child: Text(
                S.moreTitle,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
          ),
          ListTile(
            minTileHeight: 56,
            title: const Text(S.dataCheck),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              final scope = AppScope.of(context);
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      DataCheckScreen(db: scope.db, foodsPath: scope.foodsPath),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
