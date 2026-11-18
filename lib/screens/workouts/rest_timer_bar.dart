// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../clock.dart';
import '../../data/database.dart';
import '../../data/settings_data.dart';
import '../../platform/rest_alert.dart';
import '../../strings.dart';

/// Seconds of rest when the routine gives none, and for an exercise added
/// during the workout (workout.html frame 3 shows 90).
const defaultRestSeconds = 90;

/// What -15 s and +15 s change.
const restStepSeconds = 15;

/// The in-app rest timer: one for the running workout, held by the app above
/// every screen, so it keeps counting when the workout screen is left or the
/// tab is changed. It is driven by the app's clock, not by the length of a
/// timer tick, so a test can move time. It is not kept if the app is closed.
///
/// It asks for no permission by itself. At zero it vibrates once with
/// Flutter's own haptic call. The "Rest done" notification for when the app is
/// in the background is off until the user taps "Alert me when rest ends" in
/// the bar ([enableAlert]); with it off, [alert] is never called.
class RestTimer extends ChangeNotifier {
  RestTimer(this._clock, {this.alert = const LocalRestAlert(), this.db}) {
    _loadSetting();
  }

  final Clock _clock;
  final RestAlert alert;

  /// Where the "alert me" setting is kept. Null in a test that never taps it.
  final AppDatabase? db;
  bool _alertOn = false;
  bool _asking = false;
  bool _refused = false;

  /// The phone's answer to the quiet check for this rest: null until it
  /// answers (or when the setting is off), true to schedule, false when the
  /// setting is on but the phone does not allow notifications.
  bool? _allowed;
  int _serial = 0;
  int? _workoutId;
  int _endMs = 0;
  int _totalMs = 0;
  bool _over = false;
  Timer? _ticker;

  /// The workout this rest belongs to, or null when no rest is showing.
  int? get workoutId => _workoutId;

  /// True from the start of a rest until it is skipped, hidden or replaced.
  bool get isActive => _workoutId != null;

  /// True once the rest has run out.
  bool get isOver => _over;

  /// The rest's length so far, with the -15 s and +15 s taps.
  int get totalMs => _totalMs;

  int get remainingMs {
    if (!isActive || _over) return 0;
    final left = _endMs - _clock().utcMs;
    return left < 0 ? 0 : left;
  }

  /// True when the user has the "Rest done" alert on.
  bool get alertOn => _alertOn;

  /// True when the "Alert me when rest ends" row is shown: the setting is off,
  /// or it is on but the phone does not allow notifications for this rest.
  bool get showAlertRow => !_alertOn || _allowed == false;

  /// True after the phone refused notifications to the last tap on the row.
  bool get alertRefused => _refused;

  Future<void> _loadSetting() async {
    try {
      final on = await db?.getRestAlert() ?? false;
      if (on == _alertOn) return;
      _alertOn = on;
      notifyListeners();
    } catch (_) {
      // No setting read means the alert stays off.
    }
  }

  /// The row in the bar, shown while the setting is off. Asks the phone for
  /// permission (this is the only place it is asked). If granted, keeps the
  /// setting on for good and schedules the alert for this rest; the row is
  /// then gone. If refused, the row stays and can be tapped again. Turning it
  /// off again is done in the phone's notification settings.
  Future<void> enableAlert() async {
    if (_asking || !showAlertRow) return;
    _asking = true;
    var granted = false;
    try {
      granted = await alert.requestPermission();
    } catch (_) {
      // A request that fails counts as a refusal.
    } finally {
      _asking = false;
      _refused = !granted;
    }
    if (!granted) {
      notifyListeners();
      return;
    }
    _alertOn = true;
    _allowed = true;
    if (isActive && !_over) unawaited(alert.schedule(_endMs));
    notifyListeners();
    await _saveSetting(true);
  }

  /// The app came back to the front. A "Rest done" that is about to arrive
  /// late, or is sitting in the shade, is no use now: the bar says it.
  void appResumed() {
    if (_alertOn && _over) unawaited(alert.cancel());
  }

  Future<void> _saveSetting(bool on) async {
    try {
      await db?.setRestAlert(on);
    } catch (_) {
      // It then holds until the app is closed.
    }
  }

  /// Starts a rest of [seconds], replacing any that is running. A rest of zero
  /// or less means no rest: nothing starts and an old rest is dropped.
  void start(int workoutId, int seconds) {
    final was = isActive;
    _stop();
    _refused = false;
    // The old rest's alert goes first, which also removes one that showed.
    if (was && _alertOn) unawaited(alert.cancel());
    if (seconds <= 0) {
      notifyListeners();
      return;
    }
    _workoutId = workoutId;
    _totalMs = seconds * 1000;
    _endMs = _clock().utcMs + _totalMs;
    _over = false;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    if (_alertOn) unawaited(_scheduleIfAllowed(_serial));
    notifyListeners();
  }

  /// The setting is on: ask the phone quietly, then schedule this rest. The
  /// rest has already started. A rest that was skipped, replaced or finished
  /// while the check was out gets nothing.
  Future<void> _scheduleIfAllowed(int serial) async {
    var allowed = false;
    try {
      allowed = await alert.isAllowed();
    } catch (_) {
      // A check that fails counts as not allowed.
    }
    if (serial != _serial || !isActive) return;
    _allowed = allowed;
    if (allowed && !_over) unawaited(alert.schedule(_endMs));
    notifyListeners();
  }

  /// Moves the end of this rest by [seconds] (minus 15 or plus 15). A rest that
  /// would end at or before now ends quietly: the user did it, so no buzz.
  void adjust(int seconds) {
    if (!isActive || _over) return;
    final now = _clock().utcMs;
    final end = _endMs + seconds * 1000;
    if (end <= now) {
      _ticker?.cancel();
      _ticker = null;
      _over = true;
      if (_alertOn) unawaited(alert.cancel());
    } else {
      _endMs = end;
      _totalMs += seconds * 1000;
      if (_totalMs < end - now) _totalMs = end - now;
      if (_alertOn && _allowed == true) unawaited(alert.schedule(_endMs));
    }
    notifyListeners();
  }

  /// Hides the timer (Skip, or Hide once the rest is over) and cancels the
  /// alert, which also removes a "Rest done" that already showed.
  ///
  /// Import (task 8.2) replaces every workout: it must end the rest through
  /// this (or [clearFor]) so the pending alert is cancelled too.
  void skip() {
    final was = isActive;
    _stop();
    if (was && _alertOn) unawaited(alert.cancel());
    if (was) notifyListeners();
  }

  /// Hides the timer when it belongs to [workoutId]. Finish, a workout deleted
  /// or finished elsewhere, and (in task 8.2) an import all come through here
  /// or [skip], so each cancels the alert.
  void clearFor(int workoutId) {
    if (_workoutId == workoutId) skip();
  }

  void _stop() {
    _serial++;
    _allowed = null;
    _ticker?.cancel();
    _ticker = null;
    _workoutId = null;
    _over = false;
  }

  void _tick() {
    if (!isActive || _over) return;
    if (remainingMs > 0) {
      notifyListeners();
      return;
    }
    _ticker?.cancel();
    _ticker = null;
    _over = true;
    // With the app in front the buzz has done the job, so the alert goes. In
    // the background (the timer can still tick for a while) it must stay: it
    // is the only thing that tells the user.
    if (_alertOn && _inFront) unawaited(alert.cancel());
    // Flutter's own haptic call: no package and no permission. A phone with
    // no vibration motor answers with an error, which is not worth a message.
    unawaited(HapticFeedback.vibrate().catchError((Object _) {}));
    notifyListeners();
  }

  bool get _inFront {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _ticker = null;
    super.dispose();
  }
}

/// The bar under the set list: the countdown, what is next, -15 s, +15 s and
/// Skip (workout.html frame 3). It sits below the list, never over it.
class RestTimerBar extends StatelessWidget {
  const RestTimerBar({super.key, required this.timer, this.upNext});

  final RestTimer timer;

  /// 'Up next: set 2, 175 lb x 8', or null when nothing is left to do.
  final String? upNext;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: timer,
      builder: (context, _) {
        if (!timer.isActive) return const SizedBox.shrink();
        final theme = Theme.of(context);
        final over = timer.isOver;
        final total = timer.totalMs;
        final left = timer.remainingMs;
        final leftSeconds = (left / 1000).ceil();
        final totalSeconds = (total / 1000).round();
        final heading = over
            ? S.restDone
            : S.restRunning(
                S.minutesSeconds(leftSeconds),
                S.minutesSeconds(totalSeconds),
              );
        const button = ButtonStyle(
          minimumSize: WidgetStatePropertyAll(Size(48, 48)),
          padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 8)),
        );
        return Material(
          color: theme.colorScheme.surfaceContainer,
          child: ContentWidth(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // The running countdown is not a live region, which would
                  // read out every second. Only the end is announced.
                  Semantics(
                    liveRegion: over,
                    child: Text(
                      heading,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (upNext != null) Text(upNext!),
                  if (!over) ...[
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: total <= 0
                          ? 1
                          : (1 - left / total).clamp(0.0, 1.0),
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ],
                  const SizedBox(height: 8),
                  if (over)
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton(
                        style: button,
                        onPressed: timer.skip,
                        child: const Text(S.restHide),
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: Semantics(
                            container: true,
                            button: true,
                            label: S.restMinusSpoken,
                            excludeSemantics: true,
                            onTap: () => timer.adjust(-restStepSeconds),
                            child: OutlinedButton(
                              style: button,
                              onPressed: () => timer.adjust(-restStepSeconds),
                              child: const Text(S.restMinus),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Semantics(
                            container: true,
                            button: true,
                            label: S.restPlusSpoken,
                            excludeSemantics: true,
                            onTap: () => timer.adjust(restStepSeconds),
                            child: OutlinedButton(
                              style: button,
                              onPressed: () => timer.adjust(restStepSeconds),
                              child: const Text(S.restPlus),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Semantics(
                            container: true,
                            button: true,
                            label: S.restSkipSpoken,
                            excludeSemantics: true,
                            onTap: timer.skip,
                            child: OutlinedButton(
                              style: button,
                              onPressed: timer.skip,
                              child: const Text(S.restSkip),
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (!over && timer.showAlertRow) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        style: const ButtonStyle(
                          minimumSize: WidgetStatePropertyAll(Size(48, 48)),
                          alignment: Alignment.centerLeft,
                        ),
                        onPressed: timer.enableAlert,
                        child: const Text(S.restAlertOff),
                      ),
                    ),
                    if (timer.alertRefused)
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          S.restAlertRefused,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
