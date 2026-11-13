// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'dart:async';

import 'package:flutter/widgets.dart';

import 'clock.dart';
import 'data/database.dart';
import 'data/food_data.dart';
import 'data/off_client.dart';
import 'parser/parse_worker.dart';
import 'platform/barcode.dart';
import 'parser/user_snapshot_data.dart';

/// Makes a worker for the USDA file at the given path. The app uses
/// [ParseWorker.isolate]; tests use [ParseWorker.inline] or inlineWith.
typedef WorkerFactory = ParseWorker Function(String usdaPath);

/// The one parser worker of the app (phase 4 plan 2.7, rule 1 of "How the
/// screens use the parser worker"). It is made once the food data is
/// installed, started after the first frame, given the user's data at start
/// and again whenever that data changes, and disposed with the app. A dead
/// worker cannot be restarted, so [acquire] makes a new one.
class ParserHost {
  ParserHost({required this.db, required this.foodsPath, required this.factory})
    : _resolved = foodsPath.then<String?>(
        (path) => path,
        // Looked at at once, so a failure before the first frame is not an
        // unhandled error. [acquire] reports it to the screen that asks.
        onError: (Object _) => null,
      );

  final AppDatabase db;
  final Future<String> foodsPath;

  /// Null means no parser: the food screen then waits for a worker that never
  /// comes. Only tests that never open the food screen leave it out.
  final WorkerFactory? factory;

  final Future<String?> _resolved;
  final _pathKnown = Completer<void>();
  String? _path;
  ParseWorker? _worker;
  UserSnapshotData? _snapshot;
  StreamSubscription<UserSnapshotData>? _snapshots;
  var _begun = false;
  var _disposed = false;

  /// Call after the first frame. Waits for the food data, makes and starts the
  /// worker, and feeds it the user's data.
  void begin() {
    if (_begun || _disposed || factory == null) return;
    _begun = true;
    _resolved.then((path) {
      if (_disposed) return;
      if (path == null) {
        // The food data could not be installed: no worker, ever. A screen
        // that asks for one is told.
        _pathKnown.completeError(StateError('no food data'));
        // Nobody may be waiting yet.
        _pathKnown.future.ignore();
        return;
      }
      _path = path;
      _make();
      _snapshots = db.watchUserSnapshot().listen((data) {
        _snapshot = data;
        _worker?.setSnapshot(data);
      }, onError: (Object _) {});
      _pathKnown.complete();
    });
  }

  ParseWorker _make() {
    final old = _worker;
    // Nothing is waited for: a dead worker has nothing left to say.
    if (old != null) unawaited(old.dispose());
    final w = factory!(_path!);
    // Failures with no typed box (new user data that could not be read, a
    // worker that failed to start or stopped) need no action here: every open
    // box hears of a dead worker itself, and the next acquire replaces it.
    w.onFailure = (_) {};
    _worker = w;
    unawaited(w.start());
    final s = _snapshot;
    if (s != null) w.setSnapshot(s);
    return w;
  }

  /// A live worker, made new when the last one died. Waits for the food data;
  /// never completes when there is no parser, and fails when the food data
  /// could not be installed.
  Future<ParseWorker> acquire() async {
    if (factory == null) return Completer<ParseWorker>().future;
    await _pathKnown.future;
    final w = _worker;
    if (w == null || w.isDead) return _make();
    return w;
  }

  Future<void> dispose() async {
    _disposed = true;
    final listening = _snapshots?.cancel();
    _snapshots = null;
    final w = _worker;
    _worker = null;
    await w?.dispose();
    await listening;
  }
}

/// The shared objects, read with AppScope.of(context).
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.db,
    required this.clock,
    required this.foodsPath,
    this.parser,
    this.camera = const ZxingCamera(),
    this.off,
    required super.child,
  });

  final AppDatabase db;
  final Clock clock;

  /// Path of the installed USDA database, see installFoodReference.
  final Future<String> foodsPath;

  /// The parser worker, for the food entry box. Null in a test that builds an
  /// AppScope by hand and never opens the food screen.
  final ParserHost? parser;

  /// The camera for scanning a barcode. Tests put a fake here.
  final BarcodeCamera camera;

  /// The Open Food Facts client, the only network code. Null in a test that
  /// never scans (a scan then reports no connection).
  final OffClient? off;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No AppScope above this widget');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope old) =>
      db != old.db ||
      clock != old.clock ||
      foodsPath != old.foodsPath ||
      parser != old.parser ||
      camera != old.camera ||
      off != old.off;
}
