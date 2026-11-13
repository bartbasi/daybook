// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'dart:async';

import 'package:flutter/material.dart';

import 'app_info.dart';
import 'app_scope.dart';
import 'clock.dart';
import 'data/database.dart';
import 'data/off_client.dart';
import 'data/settings_data.dart';
import 'data/weight_data.dart';
import 'platform/barcode.dart';
import 'platform/weight_widget.dart';
import 'screens/food/food_entry_screen.dart' show FoodEntryScreenState;
import 'screens/home/home_screen.dart';
import 'screens/more/more_screen.dart';
import 'screens/weight/weight_sheet.dart' show weightSheetOpen;
import 'screens/weight/weight_tab.dart';
import 'strings.dart';
import 'util/units.dart';

class DaybookApp extends StatefulWidget {
  const DaybookApp({
    super.key,
    required this.db,
    required this.clock,
    required this.foodsPath,
    this.workerFactory,
    this.camera = const ZxingCamera(),
    this.offClient,
  });

  final AppDatabase db;
  final Clock clock;
  final Future<String> foodsPath;

  /// Makes the parser worker once the food data is installed. main() passes
  /// [ParseWorker.isolate]; a test passes [ParseWorker.inline] or a function
  /// returning [ParseWorker.inlineWith]. Left out, the app has no parser, which
  /// is fine for a test that never opens the food screen.
  final WorkerFactory? workerFactory;

  /// The barcode camera. A test passes a fake, so no camera is ever opened.
  final BarcodeCamera camera;

  /// The Open Food Facts client. Left out, the app makes the real one; a test
  /// passes one over a mock HTTP client.
  final OffClient? offClient;

  @override
  State<DaybookApp> createState() => _DaybookAppState();
}

class _DaybookAppState extends State<DaybookApp> {
  late final ParserHost _parser = ParserHost(
    db: widget.db,
    foodsPath: widget.foodsPath,
    factory: widget.workerFactory,
  );

  late final OffClient _off =
      widget.offClient ??
      OffClient.network(userAgent: offUserAgent(appVersion));

  @override
  void initState() {
    super.initState();
    // The worker starts after the first frame, so it never delays it.
    WidgetsBinding.instance.addPostFrameCallback((_) => _parser.begin());
  }

  @override
  void dispose() {
    unawaited(_parser.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      db: widget.db,
      clock: widget.clock,
      foodsPath: widget.foodsPath,
      parser: _parser,
      camera: widget.camera,
      off: _off,
      child: MaterialApp(
        title: S.title,
        theme: ThemeData(colorSchemeSeed: Colors.teal),
        darkTheme: ThemeData(
          colorSchemeSeed: Colors.teal,
          brightness: Brightness.dark,
        ),
        home: const HomeShell(),
      ),
    );
  }
}

/// Content is one column, at most 600 dp wide, centered when the window is
/// wider. Bars outside it stretch edge to edge.
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: child,
      ),
    );
  }
}

/// The five tabs. Tabs whose screens are not built yet are shown but
/// disabled: they are greyed, cannot be selected, and read as disabled to a
/// screen reader.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  static const _today = 0;
  static const _weight = 3;

  final _home = GlobalKey<HomeScreenState>();
  int _index = _today;

  // The home-screen widget shows the latest weigh-in. Listening to the
  // weights and the units here, and rewriting the widget on every change,
  // means no write path (save, edit, delete, Undo, a units switch, an
  // import) can forget to update it.
  List<WeightEntry>? _rows;
  UnitSystem? _units;
  Clock? _clock;
  StreamSubscription<List<WeightEntry>>? _weightsSub;
  StreamSubscription<UnitSystem>? _unitsSub;
  StreamSubscription<Uri?>? _linksSub;
  Timer? _midnightTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Started from the widget: show Today and open the weight sheet.
    readWidgetLaunchLink().then(_onLink);
    // Tapped while the app is already running.
    _linksSub = widgetLinks().listen(_onLink);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_weightsSub != null) return;
    final scope = AppScope.of(context);
    _clock = scope.clock;
    _weightsSub = scope.db.watchWeights().listen((rows) {
      _rows = rows;
      _syncWidget();
    }, onError: (Object _) {});
    _unitsSub = scope.db.watchUnits().listen((units) {
      _units = units;
      _syncWidget();
    }, onError: (Object _) {});
    _scheduleMidnight();
  }

  /// One timer for the next local midnight, by the injected clock, so a phone
  /// left open across midnight moves to the new day.
  void _scheduleMidnight() {
    _midnightTimer?.cancel();
    const day = Duration.millisecondsPerDay;
    final now = _clock!();
    final localMs = now.utcMs + now.offsetMinutes * 60000;
    final wait = day - (localMs % day);
    _midnightTimer = Timer(Duration(milliseconds: wait), () {
      if (!mounted) return;
      setState(() {});
      _syncWidget();
      _scheduleMidnight();
    });
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _weightsSub?.cancel();
    _unitsSub?.cancel();
    _linksSub?.cancel();
    super.dispose();
  }

  void _syncWidget() {
    final rows = _rows;
    final units = _units;
    if (rows == null || units == null) return;
    writeWeightWidget(rows, units, _clock!().localDate);
  }

  void _onLink(Uri? link) {
    if (!isWeightLink(link) || !mounted) return;
    // A weight sheet is already open: leave it in front, on its own tab.
    if (weightSheetOpen) return;
    // The food screen is open: the sheet opens over it, the typed text stays,
    // and the "Weight saved" bar is shown on that screen, where it can be
    // seen (Home is underneath).
    final food = FoodEntryScreenState.active;
    if (food != null) {
      food.openWeightSheet();
      return;
    }
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    setState(() => _index = _today);
    // Home's own method, so its confirmation bar applies here too.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _home.currentState?.openWeightSheet(),
    );
  }

  /// "Today" comes from the clock, so draw the shell and the tabs again when
  /// the app comes back (it may be a new day), and refresh the widget's
  /// "Today" wording.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {});
      _syncWidget();
      _scheduleMidnight();
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = AppScope.of(context).clock().localDate;
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _index,
          children: [
            HomeScreen(
              key: _home,
              today: today,
              onOpenWeightTab: () => setState(() => _index = _weight),
            ),
            const SizedBox.shrink(),
            const SizedBox.shrink(),
            WeightTab(today: today),
            const MoreScreen(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          // A tab's message does not follow the user to another tab.
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          setState(() => _index = i);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: S.tabToday,
          ),
          NavigationDestination(
            enabled: false,
            icon: Icon(Icons.bar_chart_outlined),
            label: S.tabSummary,
          ),
          NavigationDestination(
            enabled: false,
            icon: Icon(Icons.fitness_center_outlined),
            label: S.tabWorkouts,
          ),
          NavigationDestination(
            icon: Icon(Icons.monitor_weight_outlined),
            selectedIcon: Icon(Icons.monitor_weight),
            label: S.tabWeight,
          ),
          NavigationDestination(icon: Icon(Icons.more_horiz), label: S.tabMore),
        ],
      ),
    );
  }
}
