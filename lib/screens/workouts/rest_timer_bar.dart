// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../clock.dart';
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
/// It makes no notification and asks for no permission. At zero it vibrates
/// once with Flutter's own haptic call (task 4.5 adds the alert when the app
/// is in the background).
class RestTimer extends ChangeNotifier {
  RestTimer(this._clock);

  final Clock _clock;
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

  /// Starts a rest of [seconds], replacing any that is running. A rest of zero
  /// or less means no rest: nothing starts and an old rest is dropped.
  void start(int workoutId, int seconds) {
    _stop();
    if (seconds <= 0) {
      notifyListeners();
      return;
    }
    _workoutId = workoutId;
    _totalMs = seconds * 1000;
    _endMs = _clock().utcMs + _totalMs;
    _over = false;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
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
    } else {
      _endMs = end;
      _totalMs += seconds * 1000;
      if (_totalMs < end - now) _totalMs = end - now;
    }
    notifyListeners();
  }

  /// Hides the timer (Skip, or Hide once the rest is over).
  void skip() {
    final was = isActive;
    _stop();
    if (was) notifyListeners();
  }

  /// Hides the timer when it belongs to [workoutId].
  void clearFor(int workoutId) {
    if (_workoutId == workoutId) skip();
  }

  void _stop() {
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
    // Flutter's own haptic call: no package and no permission. A phone with
    // no vibration motor answers with an error, which is not worth a message.
    unawaited(HapticFeedback.vibrate().catchError((Object _) {}));
    notifyListeners();
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
