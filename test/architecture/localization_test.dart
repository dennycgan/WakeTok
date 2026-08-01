import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Localization guards (ADR-012 / kickoff ADR-U machine subset).
///
/// Pure [dart:io] + regex/JSON. Missing `lib/features` / `lib/app` → no
/// hardcoded-scan violations (forward-armed). ARB files must exist.
void main() {
  final packageRoot = _findPackageRoot();
  final libRoot = Directory('${packageRoot.path}/lib');

  test('localization: no hardcoded user-facing copy in features/app (ADR-012)',
      () {
    final violations = <String>[];
    for (final dirName in <String>['features', 'app']) {
      final dir = Directory('${libRoot.path}/$dirName');
      if (!dir.existsSync()) continue;
      for (final file in _dartFilesUnder(dir)) {
        final rel = _posixRel(packageRoot, file);
        final source = file.readAsStringSync();
        for (final match in _userFacingStringLiteral.allMatches(source)) {
          final literal = match.group(2)!;
          if (!_looksLikeHardcodedCopy(literal)) continue;
          violations.add(
            '$rel:${_lineNumber(source, match.start)}: '
            'hardcoded user-facing string literal (use AppLocalizations) '
            '— ADR-012',
          );
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'ADR-012 hardcoded-copy violations:\n${violations.join('\n')}',
    );
  });

  test('localization: app_en.arb and app_zh_Hans.arb key sets match (ADR-012)',
      () {
    final en = _loadArb(packageRoot, 'lib/l10n/app_en.arb');
    final zh = _loadArb(packageRoot, 'lib/l10n/app_zh_Hans.arb');
    final enKeys = _messageKeys(en);
    final zhKeys = _messageKeys(zh);

    final missingInZh = enKeys.difference(zhKeys).toList()..sort();
    final missingInEn = zhKeys.difference(enKeys).toList()..sort();

    expect(
      missingInZh,
      isEmpty,
      reason: 'Keys in app_en.arb missing from app_zh_Hans.arb: $missingInZh',
    );
    expect(
      missingInEn,
      isEmpty,
      reason: 'Keys in app_zh_Hans.arb missing from app_en.arb: $missingInEn',
    );
  });

  test(
      'localization: placeholder messages have @key.description (ADR-012)',
      () {
    final en = _loadArb(packageRoot, 'lib/l10n/app_en.arb');
    final violations = <String>[];

    for (final entry in en.entries) {
      final key = entry.key;
      if (key.startsWith('@')) continue;
      final value = entry.value;
      if (value is! String) continue;
      if (!_placeholderInMessage.hasMatch(value)) continue;

      final meta = en['@$key'];
      if (meta is! Map) {
        violations.add('$key: missing @$key metadata object');
        continue;
      }
      final description = meta['description'];
      if (description is! String || description.trim().isEmpty) {
        violations.add('$key: @$key.description must be a non-empty string');
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'ADR-012 placeholder description violations:\n${violations.join('\n')}',
    );
  });
}

// --- scanners ---------------------------------------------------------------

/// Common user-copy constructors: capture the first string literal argument.
/// Group 1 is the raw literal body (no surrounding quotes).
final _userFacingStringLiteral = RegExp(
  r'''(?:Text(?:\.rich)?|SnackBar|AlertDialog|SimpleDialog|ListTile|AppBar)\s*\(\s*(?:[a-zA-Z_][\w.]*\s*:\s*)?(['"])((?:\\.|(?!\1).)*)\1''',
  multiLine: true,
);

final _placeholderInMessage = RegExp(r'\{[a-zA-Z_][a-zA-Z0-9_]*\}');

final _latinWord = RegExp(r'[A-Za-z]{2,}');
final _cjk = RegExp(
  r'[\u3400-\u4DBF\u4E00-\u9FFF\uF900-\uFAFF]',
);

bool _looksLikeHardcodedCopy(String literalBody) {
  // Strip Dart string interpolations; leftover letters/CJK ⇒ product copy.
  final withoutInterpolation = literalBody
      .replaceAllMapped(RegExp(r'\$\{[^}]*\}'), (_) => '')
      .replaceAllMapped(RegExp(r'\$[a-zA-Z_][a-zA-Z0-9_]*'), (_) => '');
  if (_cjk.hasMatch(withoutInterpolation)) return true;
  if (_latinWord.hasMatch(withoutInterpolation)) return true;
  return false;
}

// --- ARB --------------------------------------------------------------------

Map<String, dynamic> _loadArb(Directory packageRoot, String relPath) {
  final file = File('${packageRoot.path}/$relPath');
  expect(file.existsSync(), isTrue, reason: 'Missing $relPath');
  final decoded = jsonDecode(file.readAsStringSync());
  expect(decoded, isA<Map<String, dynamic>>());
  return Map<String, dynamic>.from(decoded as Map);
}

Set<String> _messageKeys(Map<String, dynamic> arb) {
  return arb.keys.where((k) => !k.startsWith('@')).toSet();
}

// --- path helpers -----------------------------------------------------------

Directory _findPackageRoot() {
  var dir = Directory.current;
  while (true) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) return dir;
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('pubspec.yaml not found from ${Directory.current.path}');
    }
    dir = parent;
  }
}

List<File> _dartFilesUnder(Directory root) {
  if (!root.existsSync()) return const [];
  return root
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();
}

String _posixRel(Directory root, File file) {
  final rootPath = root.uri.resolve('.').path;
  final filePath = file.uri.resolve('.').path;
  var rel = filePath.substring(rootPath.length);
  if (rel.startsWith('/')) rel = rel.substring(1);
  return rel.replaceAll('\\', '/');
}

int _lineNumber(String source, int offset) {
  var line = 1;
  for (var i = 0; i < offset && i < source.length; i++) {
    if (source.codeUnitAt(i) == 0x0A) line++;
  }
  return line;
}
