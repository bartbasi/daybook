// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'line.dart';
import 'split.dart' show UserNames;
import 'tokens.dart';

/// The text after the character clean-up of grammar 2.1, with a way back to
/// the text the user typed.
class CleanText {
  CleanText._(this.original, this.text, this._lo, this._hi);

  /// What the user typed.
  final String original;

  /// The cleaned text.
  final String text;

  final List<int> _lo;
  final List<int> _hi;

  /// The part of [original] that the cleaned characters [start] to [end] came
  /// from. [end] is not included. An empty range gives an empty span.
  Span originalSpan(int start, int end) {
    if (start >= end) {
      final at = start < _lo.length ? _lo[start] : original.length;
      return Span(at, at);
    }
    return Span(_lo[start], _hi[end - 1]);
  }
}

/// A string plus, for each character, the range of the original it came from.
class _Buf {
  _Buf(String s)
    : s = s,
      lo = List<int>.generate(s.length, (i) => i),
      hi = List<int>.generate(s.length, (i) => i + 1);

  String s;
  List<int> lo;
  List<int> hi;

  /// Replaces every match with [f]'s text. Every new character maps to the
  /// whole matched range.
  void replace(RegExp re, String Function(Match m) f) {
    final out = StringBuffer();
    final nlo = <int>[];
    final nhi = <int>[];
    var at = 0;
    void copy(int from, int to) {
      out.write(s.substring(from, to));
      nlo.addAll(lo.sublist(from, to));
      nhi.addAll(hi.sublist(from, to));
    }

    for (final m in re.allMatches(s)) {
      if (m.end == m.start) continue;
      copy(at, m.start);
      final r = f(m);
      out.write(r);
      for (var i = 0; i < r.length; i++) {
        nlo.add(lo[m.start]);
        nhi.add(hi[m.end - 1]);
      }
      at = m.end;
    }
    copy(at, s.length);
    s = out.toString();
    lo = nlo;
    hi = nhi;
  }

  /// Inserts one space after each character index in [positions]. The space
  /// maps to the character it follows.
  void insertSpaceAfter(Set<int> positions) {
    if (positions.isEmpty) return;
    final out = StringBuffer();
    final nlo = <int>[];
    final nhi = <int>[];
    for (var i = 0; i < s.length; i++) {
      out.write(s[i]);
      nlo.add(lo[i]);
      nhi.add(hi[i]);
      if (positions.contains(i)) {
        out.write(' ');
        nlo.add(lo[i]);
        nhi.add(hi[i]);
      }
    }
    s = out.toString();
    lo = nlo;
    hi = nhi;
  }
}

// A combining mark belongs to the letter before it, so "e" then U+0301 is one
// letter and never splits a word.
const _lm = r'[\p{L}\p{M}]';

final _vulgar = RegExp('[${vulgarFractions.keys.join()}]');
final _quotes = RegExp('[\'‘’‚‛“”„‟]');
final _wo = RegExp(
  r'(?<![\p{L}\p{M}\d])w/o(?!\p{L})',
  caseSensitive: false,
  unicode: true,
);
final _w = RegExp(
  r'(?<![\p{L}\p{M}\d])w/',
  caseSensitive: false,
  unicode: true,
);
// Only tried at the start of a run of digits, so a long run is not rescanned
// from every digit.
final _percent = RegExp(
  r'(?<![\d.])(\d+(?:\.\d+)?|\.\d+)\s*percent\b',
  caseSensitive: false,
);
// A hyphen between two letters, or between a digit and a letter, is a space.
final _hyphenLetters = RegExp(
  '(?<=$_lm)-(?=\\p{L})|(?<=\\d)-(?=\\p{L})',
  unicode: true,
);
// A hyphen between a letter and a digit is removed: V-8 is V8.
final _hyphenLetterDigit = RegExp('(?<=$_lm)-(?=\\d)', unicode: true);
final _other = RegExp(r'[^\p{L}\p{M}\d \n,;./%+\-~×]', unicode: true);
final _run = RegExp(r'[^\s,;+×]+');
final _manySpaces = RegExp(' {2,}');
final _edgeSpaces = RegExp('^ +| +\$', multiLine: true);
final _startsWithLetter = RegExp(r'^\p{L}', unicode: true);
final _letter = RegExp(r'\p{L}', unicode: true);
final _xDigits = RegExp(r'^[xX]\d[\d./]*\.*$');
final _trailingPeriods = RegExp(r'\.+$');

bool _isDigit(int unit) => unit >= 48 && unit <= 57;

/// The lower case words with digits that stay whole whatever touches them:
/// the single-word entries of the synonym table (`7up`). User names add their
/// own single-word entries (see [UserNames]).
final Set<String> baseKeepWhole = {
  for (final k in synonyms.keys)
    if (!k.contains(' ') && RegExp(r'\d').hasMatch(k)) k.toLowerCase(),
};

/// Grammar 2.1: the character clean-up that runs before anything else.
///
/// [names] holds the user's own names, prepared once (see [UserNames]); a name
/// that is a single word with digits (`7up`) stays whole when a number touches
/// letters, as the synonym entries do. [userNames] is the slow way to pass the
/// same thing as plain strings, rebuilt on every call. The case of the
/// letters is kept, because `T` and `t` are different units.
CleanText cleanText(
  String input, {
  UserNames? names,
  Iterable<String> userNames = const [],
}) {
  final keepWhole = names != null
      ? names.keepWhole
      : (userNames.isEmpty
            ? baseKeepWhole
            : UserNames.from(userNames).keepWhole);
  return _clean(input, keepWhole);
}

CleanText _clean(String input, Set<String> keepWhole) {
  final b = _Buf(input);

  b.replace(RegExp('⁄'), (_) => '/');
  b.replace(_quotes, (_) => '');
  // A fraction maps to itself: the space before it, and the digits of n/d, all
  // belong to the fraction character only (R1).
  b.replace(_vulgar, (m) {
    final frac = vulgarFractions[m[0]]!;
    final prev = m.start > 0 ? m.input.codeUnitAt(m.start - 1) : 0;
    return _isDigit(prev) ? ' $frac' : frac;
  });
  b.replace(_wo, (_) => ' without ');
  b.replace(_w, (_) => ' with ');
  b.replace(RegExp('&'), (_) => ' and ');
  b.replace(_hyphenLetters, (_) => ' ');
  b.replace(_hyphenLetterDigit, (_) => '');
  // After the hyphen rules, so "2-percent" is "2% milk" and not a quantity.
  b.replace(_percent, (m) => '${m[1]}%');
  b.replace(RegExp('×'), (_) => ' × ');
  b.replace(_other, (_) => ' ');

  // A number touching letters is split (2.1), unless the whole word is one of
  // the names that keep digits. A word that starts with letters stays whole,
  // except x or × followed by digits, which is a multiplier.
  bool keep(String run) =>
      keepWhole.contains(run.toLowerCase().replaceAll(_trailingPeriods, ''));

  final split = <int>{};
  for (final m in _run.allMatches(b.s)) {
    final run = m[0]!;
    if (_startsWithLetter.hasMatch(run) || keep(run)) continue;
    for (var i = 0; i + 1 < run.length; i++) {
      if (_isDigit(run.codeUnitAt(i)) &&
          _letter.matchAsPrefix(run, i + 1) != null) {
        split.add(m.start + i);
      }
    }
  }
  b.insertSpaceAfter(split);

  final xSplit = <int>{};
  for (final m in _run.allMatches(b.s)) {
    if (_xDigits.hasMatch(m[0]!)) xSplit.add(m.start);
  }
  b.insertSpaceAfter(xSplit);

  b.replace(_manySpaces, (_) => ' ');
  b.replace(_edgeSpaces, (_) => '');
  return CleanText._(input, b.s, b.lo, b.hi);
}
