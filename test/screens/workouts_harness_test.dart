// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'dart:async';

import 'package:daybook/data/database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'workouts_harness.dart';

// The harness opens a database in setUp. A test that puts its own in place of
// it must not leave the first one open (memory is short on the test machine).

void main() {
  final h = WorkoutHarness()..register();

  test('putting a database in place of the first closes the first', () async {
    final first = h.db;
    // Opened and watched: a watched query ends when its database is closed.
    final ended = Completer<void>();
    final watch = first.select(first.settings).watch().listen(
      (_) {},
      onDone: ended.complete,
    );
    await first.select(first.settings).get();

    final second = AppDatabase(NativeDatabase.memory());
    addTearDown(second.close);
    h.db = second;
    expect(identical(h.db, second), isTrue);
    await ended.future.timeout(const Duration(seconds: 5));
    await watch.cancel();
  });
}
