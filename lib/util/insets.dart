// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// The height of the keyboard, never below zero. On iOS the inset can be
/// reported a little below zero for a frame or two while the keyboard moves,
/// and a negative padding is an error.
double keyboardInset(BuildContext context) =>
    math.max(0, MediaQuery.viewInsetsOf(context).bottom);
