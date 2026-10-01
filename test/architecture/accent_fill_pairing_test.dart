import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Accent fill pairing guard (ADR-069).
///
/// In `lib/features/**` and `lib/app/**`, a call whose direct argument is
/// `backgroundColor: <...>accent` must also pass `foregroundColor:
/// <...>onAccent` as a direct argument of the same call.
///
/// Source scan only: it sees fill and text set in one call (e.g.
/// `FilledButton.styleFrom`). It does not see a fill and its text set in
/// different widgets (`Container(color: accent)` + `Text(style: …)`), values
/// routed through local variables, or theme overrides — review covers those.
void main() {
  final packageRoot = _findPackageRoot();

  test('architecture: accent fill takes onAccent text (ADR-069)', () {
    final violations = <String>[];
    for (final dir in const ['lib/features', 'lib/app']) {
      for (final file in _dartFilesUnder(
        Directory('${packageRoot.path}/$dir'),
      )) {
        final rel = _posixRel(packageRoot, file);
        for (final v in accentFillViolations(file.readAsStringSync())) {
          violations.add('$rel:$v');
        }
      }
    }
    expect(
      violations,
      isEmpty,
      reason: 'ADR-069 accent fill pairing violations:\n'
          '${violations.join('\n')}',
    );
  });

  group('accentFillViolations matcher', () {
    test('accent fill with onAccent text passes', () {
      expect(
        accentFillViolations(
          'FilledButton.styleFrom(backgroundColor: tokens.accent, '
          'foregroundColor: tokens.onAccent)',
        ),
        isEmpty,
      );
    });

    test('accent fill with onMedia text fails', () {
      expect(
        accentFillViolations(
          'FilledButton.styleFrom(backgroundColor: tokens.accent, '
          'foregroundColor: tokens.onMedia)',
        ),
        hasLength(1),
      );
    });

    test('accent fill without foregroundColor fails', () {
      expect(
        accentFillViolations(
          'FilledButton.styleFrom(backgroundColor: tokens.accent)',
        ),
        hasLength(1),
      );
    });

    test('onAccent in a nested call does not satisfy the outer call', () {
      expect(
        accentFillViolations(
          'FilledButton.styleFrom(backgroundColor: tokens.accent, '
          'side: Foo(foregroundColor: tokens.onAccent))',
        ),
        hasLength(1),
      );
    });

    test('comments, strings and non-accent fills are ignored', () {
      expect(
        accentFillViolations(
          '// backgroundColor: tokens.accent\n'
          "final s = 'backgroundColor: tokens.accent';\n"
          'FilledButton.styleFrom(backgroundColor: tokens.surface, '
          'disabledBackgroundColor: tokens.accent)',
        ),
        isEmpty,
      );
    });
  });
}

final _accentFill = RegExp(r'\bbackgroundColor\s*:\s*(?:[\w.]+\.)?accent\b');
final _foreground = RegExp(r'\bforegroundColor\s*:\s*([\w.]+)');
final _onAccent = RegExp(r'(?:^|\.)onAccent$');

/// Returns `line: message` for every accent fill whose enclosing call does
/// not pass `foregroundColor: <...>onAccent` as a direct argument.
List<String> accentFillViolations(String source) {
  final enclosing = _enclosingOpenParens(source);

  final foregroundByCall = <int, List<String>>{};
  for (final m in _foreground.allMatches(source)) {
    final call = enclosing[m.start];
    if (call == null) continue;
    foregroundByCall.putIfAbsent(call, () => []).add(m.group(1)!);
  }

  final violations = <String>[];
  for (final m in _accentFill.allMatches(source)) {
    final call = enclosing[m.start];
    if (call == null) continue;
    final foregrounds = foregroundByCall[call] ?? const <String>[];
    if (foregrounds.length == 1 && _onAccent.hasMatch(foregrounds.single)) {
      continue;
    }
    final line = '\n'.allMatches(source.substring(0, m.start)).length + 1;
    final got = foregrounds.isEmpty ? 'none' : foregrounds.join(', ');
    violations.add(
      '$line: `${m.group(0)}` needs `foregroundColor: …onAccent` in the '
      'same call (got: $got)',
    );
  }
  return violations;
}

/// Maps each code offset (outside strings and comments) to the offset of the
/// innermost unclosed `(` before it. Offsets inside strings / comments and
/// at top level are absent.
Map<int, int> _enclosingOpenParens(String s) {
  final result = <int, int>{};
  final stack = <int>[];
  var i = 0;
  while (i < s.length) {
    final c = s[i];
    final next = i + 1 < s.length ? s[i + 1] : '';
    if (c == '/' && next == '/') {
      final end = s.indexOf('\n', i);
      i = end < 0 ? s.length : end;
      continue;
    }
    if (c == '/' && next == '*') {
      final end = s.indexOf('*/', i + 2);
      i = end < 0 ? s.length : end + 2;
      continue;
    }
    if (c == "'" || c == '"') {
      final triple = s.startsWith(c * 3, i);
      final quote = triple ? c * 3 : c;
      var j = i + quote.length;
      while (j < s.length && !s.startsWith(quote, j)) {
        j += s[j] == r'\' ? 2 : 1;
      }
      i = j + quote.length;
      continue;
    }
    if (stack.isNotEmpty) result[i] = stack.last;
    if (c == '(') {
      stack.add(i);
    } else if (c == ')' && stack.isNotEmpty) {
      stack.removeLast();
    }
    i++;
  }
  return result;
}

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
  var rel = file.uri.path.substring(rootPath.length);
  if (rel.startsWith('/')) rel = rel.substring(1);
  return rel.replaceAll('\\', '/');
}
