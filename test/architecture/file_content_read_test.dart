import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// File-content read guard (ADR-067, supplements ADR-009).
///
/// `lib/features/**` and `lib/app/**` must not read file contents through
/// `dart:io`. Host → Dart data crosses the boundary as Pigeon fields; a file
/// path from Pigeon is for display ([Image.file] / [FileImage]) or presence
/// checks (`existsSync`), never for parsing its content format.
/// Writes (probe logs) are not scanned.
///
/// Every allowlist entry names its debt and must still match; remove the
/// entry when the debt is paid.
void main() {
  final packageRoot = _findPackageRoot();

  test('architecture: no dart:io file-content reads in features/app '
      '(ADR-067)', () {
    final violations = <String>[];
    final allowlistHits = <String, int>{
      for (final rel in _allowlist.keys) rel: 0,
    };

    for (final dir in const ['lib/features', 'lib/app']) {
      for (final file in _dartFilesUnder(
        Directory('${packageRoot.path}/$dir'),
      )) {
        final rel = _posixRel(packageRoot, file);
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (line.trimLeft().startsWith('//')) continue;
          for (final match in _fileContentRead.allMatches(line)) {
            if (allowlistHits.containsKey(rel)) {
              allowlistHits[rel] = allowlistHits[rel]! + 1;
              continue;
            }
            violations.add(
              '$rel:${i + 1}: `${match.group(0)}` — features/app must not '
              'read file contents; take the data as a Pigeon field '
              '(ADR-067)',
            );
          }
        }
      }
    }

    for (final entry in allowlistHits.entries) {
      if (entry.value == 0) {
        violations.add(
          '${entry.key}: allowlisted (${_allowlist[entry.key]}) but no '
          'file-content read left — remove the allowlist entry',
        );
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'ADR-067 file-content read violations:\n'
          '${violations.join('\n')}',
    );
  });
}

/// Path → debt that owns the exception.
const _allowlist = <String, String>{
  'lib/features/main_browse/cap24_minute_landmark.dart': 'debt 486',
};

/// Sync variants (`readAsBytesSync`, `openSync`, …) included.
final _fileContentRead = RegExp(
  r'\.(?:readAsBytes|readAsString|readAsLines|open)(?:Sync)?\s*\('
  r'|\.openRead\s*\('
  r'|\bRandomAccessFile\b',
);

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
