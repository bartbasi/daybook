// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'dart:async';
import 'dart:io';

import 'package:daybook/parser/line.dart';
import 'package:daybook/parser/parse_session.dart';
import 'package:daybook/parser/parse_worker.dart';
import 'package:daybook/parser/parser.dart';
import 'package:daybook/parser/search_index.dart';
import 'package:daybook/parser/user_snapshot_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

// The worker (grammar 12.3, phase 4 plan 2.7): a real isolate over the real
// bundled database, the stale-result rule, failures, shutdown, and the inline
// mode giving the same answers as the isolate.

const _egg = 'usda:2707153';
const _halfAndHalf = 'usda:2705594';

UserSnapshotData _data({int version = 1, bool learned = false}) =>
    UserSnapshotData(
      version: version,
      foods: const [
        UserFoodData(
          ref: 'local:1',
          name: 'Protein bar',
          kind: 'custom',
          baseUnit: 'g',
          baseAmount: 50,
          portions: [PortionData('1 bar', 50)],
          nutrients: {1008: 200},
        ),
      ],
      learned: [
        if (learned)
          const LearnedMatchData(
            key: 'toast',
            foodRef: _egg,
            foodName: 'Egg, whole',
          ),
      ],
    );

String _sum(Line l) => [
  l.state.name,
  l.foodRef,
  l.foodName,
  l.quantity,
  l.unitLabel,
  l.baseQuantity,
  (l.nutrients.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))
      .map((e) => '${e.key}:${e.value}')
      .join(','),
  (l.markers.toList()..sort((a, b) => a.index - b.index))
      .map((m) => m.name)
      .join(','),
  l.learnedKey,
  l.span,
  l.amountSpans.join(),
  l.foodText,
  l.plain,
].join('|');

String _resultSum(ParseResult r) =>
    '${r.text}|${r.cursor}|${r.snapshotVersion}|${r.lines.map(_sum).join(';')}';

String _choiceSum(FoodChoice c) => '${c.ref}|${c.name}|${c.dataset}|${c.kcal}';

String _altSum(Alternatives a) =>
    '${a.current == null ? '' : _choiceSum(a.current!)}#'
    '${a.others.map(_choiceSum).join(';')}';

/// Waits for results by request number. Results that arrive before anyone
/// waits are kept.
class _Harness {
  _Harness(this.worker) {
    worker.onResult = (r) {
      results[r.id] = r;
      waiters.remove(r.id)?.complete(r);
    };
    worker.onFailure = failures.add;
  }

  final ParseWorker worker;
  final results = <int, ParseResult>{};
  final waiters = <int, Completer<ParseResult>>{};
  final failures = <WorkerFailure>[];

  Future<ParseResult> wait(int id) {
    final r = results[id];
    if (r != null) return Future.value(r);
    return (waiters[id] = Completer<ParseResult>()).future.timeout(
      const Duration(seconds: 30),
    );
  }

  Future<ParseResult> text(String t, [int? cursor]) =>
      wait(worker.setText(t, cursor ?? t.length));
}

/// A link that runs the worker's core at once but holds each reply until the
/// test lets it go, so the order of arrival is the test's choice.
class _HeldLink implements WorkerLink {
  _HeldLink(this.core);

  final WorkerCore core;
  final held = <WorkerReply>[];
  late void Function(WorkerReply) _deliver;

  @override
  void start(void Function(WorkerReply reply) onReply) {
    _deliver = onReply;
    onReply(const ReadyReply());
  }

  @override
  void send(WorkerRequest request) => held.add(core.handle(request));

  @override
  Future<void> close() async {}

  void release(int i) => _deliver(held[i]);
}

void main() {
  late String path;
  late Database db;
  late Parser parser;

  setUpAll(() {
    final dir = Directory.systemTemp.createTempSync('daybook_worker');
    addTearDown(() => dir.deleteSync(recursive: true));
    path = '${dir.path}/usda.sqlite';
    File(path).writeAsBytesSync(
      gzip.decode(File('assets/food/usda.sqlite.gz').readAsBytesSync()),
    );
    db = sqlite3.open(path, mode: OpenMode.readOnly);
    // Registered after the folder's delete, so it runs first: the loader's
    // statements are released, then the database is closed, then the file goes.
    addTearDown(db.close);
    final loader = SqliteUsdaFoods(db);
    addTearDown(loader.dispose);
    parser = Parser(SearchIndex.build(readUsdaFoods(db)), loader.call);
  });

  group('a real isolate', () {
    late ParseWorker worker;
    late _Harness h;

    setUp(() async {
      worker = ParseWorker.isolate(path);
      h = _Harness(worker);
    });
    tearDown(() => worker.dispose());

    test('starts, reports ready, and parses', () async {
      expect(worker.isReady, isFalse);
      expect(await worker.start(), isTrue);
      expect(worker.isReady, isTrue);
      final r = await h.text('2 eggs, 2 sl', 12);
      expect(r.text, '2 eggs, 2 sl');
      expect(r.cursor, 12);
      expect(r.lines, hasLength(2));
      expect(r.lines[0].foodRef, _egg);
      expect(r.lines[0].baseQuantity, 100);
      expect(r.lines[1].state, LineState.notFound);
      expect(r.lines[1].plain, isTrue);
      // The same as the parser run here.
      final here = ParseSession(parser)..setText('2 eggs, 2 sl', 12);
      expect(r.lines.map(_sum), here.lines.map(_sum));
    });

    test('start returns at once and parse requests wait for ready', () async {
      // One request before start, one right after it, neither awaited.
      final a = worker.setText('2 eggs', 6);
      final ready = worker.start();
      expect(worker.isReady, isFalse);
      final b = worker.setText('2 eggs, toast', 13);
      final ra = await h.wait(a);
      expect(worker.isReady, isTrue);
      final rb = await h.wait(b);
      expect(await ready, isTrue);
      expect(ra.lines, hasLength(1));
      expect(rb.lines, hasLength(2));
      expect(a < b, isTrue);
    });

    test('a snapshot update parses the current text again', () async {
      await worker.start();
      final before = await h.text('toast');
      expect(before.snapshotVersion, 0);
      expect(before.lines[0].foodRef, isNot(_egg));
      final r = await h.wait(
        worker.setSnapshot(_data(version: 7, learned: true)),
      );
      expect(r.snapshotVersion, 7);
      expect(r.text, 'toast');
      expect(r.lines[0].foodRef, _egg);
      // The user's own food is found by typing.
      final bar = await h.text('protein bar');
      expect(bar.lines[0].foodRef, 'local:1');
    });

    test('picks follow the text through the worker', () async {
      await worker.start();
      var r = await h.text('2 eggs, toast');
      expect(
        await h.wait(worker.pick(r.lines[1].span!, _halfAndHalf)),
        isA<ParseResult>(),
      );
      r = await h.text('1 banana, 2 eggs, toast');
      expect(r.lines[2].foodRef, _halfAndHalf);
      expect(r.lines[2].markers, contains(Marker.yourPick));
      r = await h.wait(worker.clearPick(r.lines[2].span!));
      expect(r.lines[2].markers, isNot(contains(Marker.yourPick)));
    });

    test('alternatives and search answer for the correction sheet', () async {
      await worker.start();
      final r = await h.text('2 slices toast');
      final a = await worker.alternatives(r.lines[0].span!);
      expect(a.current!.ref, r.lines[0].foodRef);
      expect(a.others, isNotEmpty);
      expect(a.others.length, lessThanOrEqualTo(7));
      expect(a.others.every((c) => c.kcal != null), isTrue);
      final found = await worker.search('half and half', forLine: null);
      expect(found, isNotEmpty);
      expect(found.length, lessThanOrEqualTo(20));
      expect(found.first.kcal, isNull);
      final sized = await worker.search(
        'half and half',
        forLine: r.lines[0].span,
      );
      expect(sized.first.kcal, isNotNull);
      expect(
        await worker.alternatives(const Span(90, 91)),
        isA<Alternatives>(),
      );
    });

    test('dispose ends the isolate', () async {
      await worker.start();
      await h.text('2 eggs');
      final sw = Stopwatch()..start();
      await worker.dispose().timeout(const Duration(seconds: 10));
      // It finished because the isolate exited, not because the fallback
      // timer ran out.
      expect(sw.elapsed, lessThan(const Duration(seconds: 2)));
      expect(worker.isStopped, isTrue);
      expect(worker.isReady, isFalse);
      final id = worker.setText('after', 5);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(h.results.containsKey(id), isFalse);
      await expectLater(
        worker.alternatives(const Span(0, 1)),
        throwsA(isA<WorkerFailure>()),
      );
      await worker.dispose(); // twice is fine
    });

    test('dispose while the index is still being built', () async {
      final ready = worker.start();
      final sw = Stopwatch()..start();
      await worker.dispose().timeout(const Duration(seconds: 10));
      expect(sw.elapsed, lessThan(const Duration(seconds: 2)));
      expect(await ready, isFalse);
    });

    test('a file that is not there is a typed failure, not a crash', () async {
      final bad = ParseWorker.isolate('${Directory.systemTemp.path}/nope.db');
      final hb = _Harness(bad);
      final pending = bad.alternatives(const Span(0, 1));
      expect(await bad.start(), isFalse);
      expect(bad.isReady, isFalse);
      expect(hb.failures, hasLength(1));
      expect(hb.failures.single.kind, FailureKind.startup);
      expect(hb.failures.single.errorType, isNotEmpty);
      await expectLater(pending, throwsA(isA<WorkerFailure>()));
      // Asking again does not throw into the caller.
      bad.setText('2 eggs', 6);
      await bad.dispose().timeout(const Duration(seconds: 10));
    });

    test('a file that is not a food database is a typed failure', () async {
      final dir = Directory.systemTemp.createTempSync('daybook_badfile');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/other.sqlite');
      final other = sqlite3.open(file.path);
      other.execute('CREATE TABLE unrelated (x TEXT)');
      other.close();
      final bad = ParseWorker.isolate(file.path);
      final hb = _Harness(bad);
      expect(await bad.start(), isFalse);
      expect(hb.failures.single.kind, FailureKind.startup);
      await bad.dispose().timeout(const Duration(seconds: 10));
    });
  });

  group('stale results', () {
    test('an older result arriving after a newer one is ignored', () {
      final link = _HeldLink(WorkerCore(parser));
      final w = ParseWorker.linked(link);
      final h = _Harness(w);
      w.start();
      final older = w.setText('2 eggs', 6);
      final newer = w.setText('2 eggs, toast', 13);
      expect(link.held, hasLength(2));

      // The newer one arrives first, then the older one.
      link.release(1);
      expect(h.results.keys, [newer]);
      link.release(0);
      expect(h.results.keys, [newer], reason: 'the older result was applied');
      expect(h.results[newer]!.lines, hasLength(2));
      expect(h.results.containsKey(older), isFalse);
      expect(w.droppedResults, 1);
    });

    test('in order, every result is used', () {
      final link = _HeldLink(WorkerCore(parser));
      final w = ParseWorker.linked(link);
      final h = _Harness(w);
      w.start();
      final a = w.setText('2 eggs', 6);
      final b = w.setText('2 eggs, toast', 13);
      link.release(0);
      link.release(1);
      expect(h.results.keys, [a, b]);
      expect(w.droppedResults, 0);
    });

    test('a snapshot or a pick answered late is dropped the same way', () {
      final link = _HeldLink(WorkerCore(parser));
      final w = ParseWorker.linked(link);
      final h = _Harness(w);
      w.start();
      w.setText('toast', 5); // 0
      w.setSnapshot(_data(version: 2, learned: true)); // 1
      final last = w.setText('toast, 2 eggs', 13); // 2
      link.release(2);
      link.release(1);
      link.release(0);
      expect(h.results.keys, [last]);
      expect(w.droppedResults, 2);
      // The worker's session had run all three in order, so the answer used
      // is right: the learned match is in it.
      expect(h.results[last]!.lines[0].foodRef, _egg);
      expect(h.results[last]!.snapshotVersion, 2);
    });
  });

  group('failures inside the worker', () {
    Parser throwing() => Parser(
      SearchIndex.build(readUsdaFoods(db)),
      (ref) => throw StateError('secret user text: 2 eggs'),
    );

    test(
      'a failed request is a typed failure with no text, and it goes on',
      () {
        final w = ParseWorker.inlineWith(throwing());
        final h = _Harness(w);
        w.start();
        final bad = w.setText('2 eggs', 6);
        expect(h.results, isEmpty);
        expect(h.failures, hasLength(1));
        final f = h.failures.single;
        expect(f.kind, FailureKind.request);
        expect(f.id, bad);
        expect(f.errorType, 'StateError');
        expect('$f${f.errorType}', isNot(contains('secret')));
        expect('$f', isNot(contains('eggs')));
        // The worker is still there and its session was not changed.
        expect(w.isReady, isTrue);
        final ok = w.setText('purple monkey dishwasher', 24);
        expect(h.results[ok]!.lines.single.state, LineState.notFound);
      },
    );

    test('a failed question fails its own future', () async {
      final w = ParseWorker.inlineWith(throwing());
      final h = _Harness(w);
      w.start();
      final r = await h.text('purple monkey dishwasher');
      await expectLater(
        w.search('egg', forLine: r.lines[0].span),
        throwsA(
          isA<WorkerFailure>().having(
            (f) => f.kind,
            'kind',
            FailureKind.request,
          ),
        ),
      );
      // A future that failed is not also reported as a failure of its own.
      expect(h.failures, isEmpty);
    });

    test('a worker that cannot start tells the main side', () async {
      final w = ParseWorker.inline('${Directory.systemTemp.path}/nope.db');
      final h = _Harness(w);
      expect(await w.start(), isFalse);
      expect(h.failures.single.kind, FailureKind.startup);
      w.setText('x', 1);
      expect(h.results, isEmpty);
    });
  });

  group('the inline worker', () {
    test('answers before the call returns, and waits for start', () async {
      final w = ParseWorker.inline(path);
      final h = _Harness(w);
      final early = w.setText('2 eggs', 6);
      expect(h.results, isEmpty);
      w.start(); // not awaited: inline work is done when it returns
      expect(w.isReady, isTrue);
      expect(h.results[early]!.lines.single.foodRef, _egg);
      final id = w.setText('2 eggs, toast', 13);
      expect(h.results[id]!.lines, hasLength(2));
      await w.dispose();
    });

    test(
      'gives exactly the results of the isolate for the same requests',
      () async {
        Future<List<String>> run(ParseWorker w) async {
          final h = _Harness(w);
          final out = <String>[];
          await w.start();
          Future<void> text(String t, int c) async =>
              out.add(_resultSum(await h.text(t, c)));
          await text('2 eggs, 2 slices sourdough toast, 1 tbsp butter', 47);
          await text('2 eggs, 2 slices sourdough toast, 1 tbsp butter, co', 51);
          final lines = h.results.values.last.lines;
          out.add(_altSum(await w.alternatives(lines[1].span!)));
          out.add(_altSum(await w.alternatives(lines[3].span!)));
          out.add(
            (await w.search(
              'half and half',
              forLine: lines[2].span,
            )).map(_choiceSum).join(';'),
          );
          out.add((await w.search('protein')).map(_choiceSum).join(';'));
          out.add(
            _resultSum(await h.wait(w.pick(lines[1].span!, _halfAndHalf))),
          );
          await text(
            '1 banana, 2 eggs, 2 slices sourdough toast, 1 tbsp butter',
            12,
          );
          out.add(
            _resultSum(
              await h.wait(w.setSnapshot(_data(version: 3, learned: true))),
            ),
          );
          await text('toast, my usual', 5);
          out.add(_resultSum(await h.wait(w.clearPick(const Span(0, 5)))));
          out.add(_altSum(await w.alternatives(const Span(0, 5))));
          await w.dispose();
          return out;
        }

        final isolate = await run(ParseWorker.isolate(path));
        final inline = await run(ParseWorker.inline(path));
        expect(inline, hasLength(isolate.length));
        for (var i = 0; i < isolate.length; i++) {
          expect(inline[i], isolate[i], reason: 'answer $i');
        }
        expect(isolate.join(), contains(_egg));
      },
    );
  });
}
