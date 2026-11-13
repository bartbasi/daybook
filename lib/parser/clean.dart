// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'line.dart';
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

  /// Inserts one space after each character index in [positions].
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

final _vulgar = RegExp('(\\d)?([${vulgarFractions.keys.join()}])');
final _quotes = RegExp('[\'‘’‚‛“”„‟]');
final _wo = RegExp(
  r'(?<![\p{L}\d])w/o(?!\p{L})',
  caseSensitive: false,
  unicode: true,
);
final _w = RegExp(r'(?<![\p{L}\d])w/', caseSensitive: false, unicode: true);
final _percent = RegExp(
  r'(\d+(?:\.\d+)?|\.\d+)\s*percent\b',
  caseSensitive: false,
);
final _hyphenLetters = RegExp(r'(?<=\p{L})-(?=\p{L})', unicode: true);
final _hyphenLetterDigit = RegExp(
  r'(?<=\p{L})-(?=\d)|(?<=\d)-(?=\p{L})',
  unicode: true,
);
final _other = RegExp(r'[^\p{L}\d \n,;./%+\-~×]', unicode: true);
final _run = RegExp(r'[^\s,;+×]+');
final _manySpaces = RegExp(' {2,}');
final _edgeSpaces = RegExp('^ +| +\$', multiLine: true);

/// Grammar 2.1: the character clean-up that runs before anything else.
///
/// [userNames] are the user's own names (foods, saved meals, aliases). A word
/// of them that has digits stays whole when a number touches letters, as the
/// words of the synonym table and the built-in protected phrases do. The case
/// of the letters is kept, because `T` and `t` are different units.
CleanText cleanText(String input, {Iterable<String> userNames = const []}) {
  final b = _Buf(input);

  b.replace(RegExp('⁄'), (_) => '/');
  b.replace(_quotes, (_) => '');
  b.replace(_vulgar, (m) {
    final frac = vulgarFractions[m[2]]!;
    return m[1] == null ? frac : '${m[1]} $frac';
  });
  b.replace(_wo, (_) => ' without ');
  b.replace(_w, (_) => ' with ');
  b.replace(RegExp('&'), (_) => ' and ');
  b.replace(_percent, (m) => '${m[1]}%');
  b.replace(_hyphenLetters, (_) => ' ');
  b.replace(_hyphenLetterDigit, (_) => '');
  b.replace(RegExp('×'), (_) => ' × ');
  b.replace(_other, (_) => ' ');

  // A number touching letters is split (2.1), unless the whole word is one of
  // the names that keep digits. A word that starts with letters stays whole,
  // except x or × followed by digits, which is a multiplier.
  final whole = _wholeDigitWords(userNames);
  bool keep(String run) =>
      whole.contains(run.toLowerCase().replaceAll(RegExp(r'\.+$'), ''));

  final split = <int>{};
  for (final m in _run.allMatches(b.s)) {
    final run = m[0]!;
    if (RegExp(r'^\p{L}', unicode: true).hasMatch(run) || keep(run)) continue;
    for (var i = 0; i + 1 < run.length; i++) {
      if (RegExp(r'\d').hasMatch(run[i]) &&
          RegExp(r'\p{L}', unicode: true).hasMatch(run[i + 1])) {
        split.add(m.start + i);
      }
    }
  }
  b.insertSpaceAfter(split);

  final xSplit = <int>{};
  for (final m in _run.allMatches(b.s)) {
    if (RegExp(r'^[xX]\d[\d./]*\.*$').hasMatch(m[0]!)) xSplit.add(m.start);
  }
  b.insertSpaceAfter(xSplit);

  b.replace(_manySpaces, (_) => ' ');
  b.replace(_edgeSpaces, (_) => '');
  return CleanText._(input, b.s, b.lo, b.hi);
}

/// The lower case words that contain a digit and are listed by the synonym
/// table, the built-in protected phrases or the user's names.
Set<String> _wholeDigitWords(Iterable<String> userNames) {
  final out = <String>{};
  for (final phrase in [
    ...synonyms.keys,
    ...builtInProtectedPhrases,
    ...userNames,
  ]) {
    for (final w in phrase.toLowerCase().split(
      RegExp(r'[^\p{L}\d%]+', unicode: true),
    )) {
      if (RegExp(r'\d').hasMatch(w)) out.add(w);
    }
  }
  return out;
}
