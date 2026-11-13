// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

// Checks on the promises in code (see CLAUDE.md): no logging of user data,
// no network package outside the barcode client, every dependency recorded.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Files that may call print, debugPrint or log.
const _logAllowed = {'lib/error_log.dart'};

/// Files that may import package:http.
const _httpAllowed = {
  'lib/data/off_client.dart',
  // Temporary Phase 2 screen. Task 2.13 deletes it, then remove this line.
  'lib/screens/data_check_screen.dart',
};

/// Entries in pubspec.yaml that are part of the Flutter SDK and need no row.
const _sdkPackages = {
  'flutter',
  'flutter_test',
  'flutter_localizations',
  'flutter_web_plugins',
};

final _logCall = RegExp(
  r'(?<![\w$])(print|debugPrint\w*|log)\(|\b(stdout|stderr)\b',
);
final _netUse = RegExp(
  r'\b(HttpClient|HttpServer|(Raw|Secure)?Socket|WebSocket|RawDatagramSocket)\b',
);
// flutter_zxing can fetch an image from a web address, with these functions:
// readBarcodeImageUrl, readBarcodesImageUrl, zxingReadBarcodeImageUrl and
// zxingReadBarcodesImageUrl. Any name with ImageUrl in it is refused.
final _imageUrl = RegExp('imageurl', caseSensitive: false);
final _httpImport = RegExp('''^\\s*(import|export)\\s+['"]package:http/''');

/// Dart files under lib/ as 'lib/a/b.dart' paths, without generated files.
List<File> _libFiles() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'))
    .toList()
  ..sort((a, b) => a.path.compareTo(b.path));

String _name(File f) => f.path.replaceAll(r'\', '/');

/// The source with comments and string contents blanked out, one entry per
/// line, so `// print(x)` and `'log('` do not count and line numbers hold.
List<String> _codeLines(String source) {
  final lines = <String>[];
  final out = StringBuffer();
  var inBlock = false;
  String? quote; // ', ", ''' or """ while inside a string
  var i = 0;
  while (i < source.length) {
    final c = source[i];
    if (c == '\n') {
      lines.add(out.toString());
      out.clear();
      if (quote != null && quote.length == 1) quote = null;
      i++;
    } else if (inBlock) {
      if (source.startsWith('*/', i)) {
        inBlock = false;
        i += 2;
      } else {
        i++;
      }
    } else if (quote != null) {
      if (c == r'\') {
        i += 2;
      } else if (source.startsWith(quote, i)) {
        i += quote.length;
        quote = null;
      } else {
        i++;
      }
    } else if (source.startsWith('//', i)) {
      while (i < source.length && source[i] != '\n') {
        i++;
      }
    } else if (source.startsWith('/*', i)) {
      inBlock = true;
      i += 2;
    } else if (c == "'" || c == '"') {
      quote = source.startsWith(c * 3, i) ? c * 3 : c;
      i += quote.length;
    } else {
      out.write(c);
      i++;
    }
  }
  lines.add(out.toString());
  return lines;
}

/// Package names listed under [section] in pubspec.yaml.
Set<String> _pubspecPackages(String section) {
  final names = <String>{};
  var inSection = false;
  for (final line in File('pubspec.yaml').readAsLinesSync()) {
    if (RegExp(r'^\S').hasMatch(line)) {
      inSection = line.startsWith('$section:');
    } else if (inSection) {
      final m = RegExp(r'^  ([A-Za-z0-9_]+):').firstMatch(line);
      if (m != null) names.add(m.group(1)!);
    }
  }
  return names;
}

/// Package names in the first column of the tables in docs/dependencies.md.
/// A cell may list several packages and may end with a note like "(SDK)".
Set<String> _documentedPackages() {
  final names = <String>{};
  for (final line in File('docs/dependencies.md').readAsLinesSync()) {
    if (!line.startsWith('|')) continue;
    final cell = line.split('|')[1];
    for (final part in cell.split(',')) {
      names.add(part.replaceAll(RegExp(r'\(.*?\)'), '').trim());
    }
  }
  return names;
}

void main() {
  test('no print, debugPrint or log call in lib/ outside error_log.dart', () {
    final found = <String>[];
    for (final file in _libFiles()) {
      if (_logAllowed.contains(_name(file))) continue;
      final lines = _codeLines(file.readAsStringSync());
      for (var n = 0; n < lines.length; n++) {
        final m = _logCall.firstMatch(lines[n]);
        if (m != null) found.add('${_name(file)}:${n + 1} uses ${m[0]}');
      }
    }
    expect(
      found,
      isEmpty,
      reason: 'Logging is only allowed in lib/error_log.dart:\n'
          '${found.join('\n')}',
    );
  });

  test('package:http is imported only by the barcode client', () {
    final found = <String>[];
    for (final file in _libFiles()) {
      if (_httpAllowed.contains(_name(file))) continue;
      final lines = file.readAsLinesSync();
      for (var n = 0; n < lines.length; n++) {
        if (_httpImport.hasMatch(lines[n])) {
          found.add('${_name(file)}:${n + 1} imports package:http');
        }
      }
    }
    expect(
      found,
      isEmpty,
      reason: 'The only network code is lib/data/off_client.dart:\n'
          '${found.join('\n')}',
    );
  });

  test('dart:io networking is used only by the barcode client', () {
    final found = <String>[];
    for (final file in _libFiles()) {
      if (_httpAllowed.contains(_name(file))) continue;
      final lines = _codeLines(file.readAsStringSync());
      for (var n = 0; n < lines.length; n++) {
        final m = _netUse.firstMatch(lines[n]);
        if (m != null) found.add('${_name(file)}:${n + 1} uses ${m[0]}');
      }
    }
    expect(
      found,
      isEmpty,
      reason: 'The only network code is lib/data/off_client.dart:\n'
          '${found.join('\n')}',
    );
  });

  test('the barcode plugin image download is never called', () {
    // Daybook fetches no product image, so no ImageUrl name may appear in
    // lib/.
    final found = <String>[];
    for (final file in _libFiles()) {
      final lines = _codeLines(file.readAsStringSync());
      for (var n = 0; n < lines.length; n++) {
        if (_imageUrl.hasMatch(lines[n])) {
          found.add('${_name(file)}:${n + 1} uses an ImageUrl function');
        }
      }
    }
    expect(
      found,
      isEmpty,
      reason: 'No product image is ever fetched:\n${found.join('\n')}',
    );
  });

  test('every allow-listed file still exists', () {
    for (final path in {..._logAllowed, ..._httpAllowed}) {
      expect(
        File(path).existsSync(),
        isTrue,
        reason: '$path is on an allow list in test/guards_test.dart but no '
            'longer exists. Remove it from the list.',
      );
    }
  });

  test('every package in pubspec.yaml has a row in docs/dependencies.md', () {
    final documented = _documentedPackages();
    final missing = <String>[
      for (final section in ['dependencies', 'dev_dependencies'])
        for (final name in _pubspecPackages(section))
          if (!_sdkPackages.contains(name) && !documented.contains(name))
            '$name (in $section)',
    ];
    expect(
      missing,
      isEmpty,
      reason: 'Add a row with its license to docs/dependencies.md for:\n'
          '${missing.join('\n')}',
    );
  });

  test('the checks themselves see what they should', () {
    // Guard against a check that silently looks at nothing.
    expect(_libFiles(), isNotEmpty);
    expect(_pubspecPackages('dependencies'), contains('http'));
    expect(_pubspecPackages('dev_dependencies'), contains('flutter_lints'));
    expect(_documentedPackages(), contains('http'));
    expect(_logCall.hasMatch('catalog(x)'), isFalse);
    expect(_logCall.hasMatch('  debugPrint(s);'), isTrue);
    expect(_logCall.hasMatch('debugPrintStack(x)'), isTrue);
    expect(_logCall.hasMatch('stderr.writeln(x)'), isTrue);
    expect(_netUse.hasMatch('final c = HttpClient();'), isTrue);
    expect(_netUse.hasMatch('MySocketThing()'), isFalse);
    for (final name in [
      'readBarcodeImageUrl',
      'readBarcodesImageUrl',
      'zxingReadBarcodeImageUrl',
      'zxingReadBarcodesImageUrl',
    ]) {
      expect(_imageUrl.hasMatch('  zx.$name(u, p);'), isTrue, reason: name);
    }
    expect(_imageUrl.hasMatch('readBarcode(image)'), isFalse);
    final code = _codeLines("// print(1)\nfinal a = 'log(';\n/* log(\n*/ log(2);");
    expect(code.where(_logCall.hasMatch), hasLength(1));
  });
}
