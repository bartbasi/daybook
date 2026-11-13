// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:flutter/material.dart';

import 'app_scope.dart';
import 'clock.dart';
import 'data/database.dart';
import 'screens/home/home_screen.dart';
import 'screens/more/more_screen.dart';
import 'strings.dart';

class DaybookApp extends StatelessWidget {
  const DaybookApp({
    super.key,
    required this.db,
    required this.clock,
    required this.foodsPath,
  });

  final AppDatabase db;
  final Clock clock;
  final Future<String> foodsPath;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      db: db,
      clock: clock,
      foodsPath: foodsPath,
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

class _HomeShellState extends State<HomeShell> {
  static const _today = 0;

  int _index = _today;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _index,
          children: const [
            HomeScreen(),
            SizedBox.shrink(),
            SizedBox.shrink(),
            SizedBox.shrink(),
            MoreScreen(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
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
            enabled: false,
            icon: Icon(Icons.monitor_weight_outlined),
            label: S.tabWeight,
          ),
          NavigationDestination(icon: Icon(Icons.more_horiz), label: S.tabMore),
        ],
      ),
    );
  }
}
