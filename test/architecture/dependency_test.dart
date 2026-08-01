import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Architecture boundary guards (ADR-009).
///
/// Pure [dart:io] + regex over `lib/**`. Missing layers are forward-armed
/// (no files → no violations). Zero allowlist for `platform/generated` imports:
/// only `lib/platform/**` (excluding generated itself) may import them.
void main() {
  final packageRoot = _findPackageRoot();
  final libRoot = Directory('${packageRoot.path}/lib');

  test('architecture: layer import boundaries (ADR-009)', () {
    final files = _dartFilesUnder(libRoot);
    final violations = <String>[];

    for (final file in files) {
      final rel = _posixRel(packageRoot, file);
      if (_isScanExempt(rel)) continue;

      final source = file.readAsStringSync();
      final layer = _layerOf(rel);

      if (layer == 'features') {
        for (final match in _colorHexLiteral.allMatches(source)) {
          violations.add(
            '$rel:${_lineNumber(source, match.start)}: '
            'features must not hard-code Color(0x…) (ADR-009 Slice-1)',
          );
        }
      }

      for (final directive in _importOrExportUris(source)) {
        final uri = directive.uri;
        final line = directive.line;

        if (layer == 'features' && _isDbPackage(uri)) {
          violations.add(
            '$rel:$line: features must not import DB package `$uri`',
          );
        }

        if (layer == 'domain' && _isRiverpodPackage(uri)) {
          violations.add(
            '$rel:$line: domain must not import Riverpod (`$uri`) — ADR-010',
          );
        }

        final target = _resolveWakatokTarget(
          packageRoot: packageRoot,
          fromFile: file,
          uri: uri,
        );

        if (target == null) continue;

        if (_isGeneratedImport(target)) {
          if (!_isPlatformNonGenerated(rel)) {
            violations.add(
              '$rel:$line: only lib/platform/** may import '
              'lib/platform/generated/** (`$uri`)',
            );
          }
        }

        if (layer == 'features') {
          if (_under(target, 'lib/platform/') ||
              _under(target, 'lib/data/')) {
            violations.add(
              '$rel:$line: features must not import `$uri` '
              '(use domain interfaces; wire at composition root)',
            );
          }
        }

        if (layer == 'domain') {
          if (_under(target, 'lib/features/') ||
              _under(target, 'lib/data/') ||
              _under(target, 'lib/platform/')) {
            violations.add(
              '$rel:$line: domain must not import `$uri`',
            );
          }
        }

        if (layer == 'core') {
          if (_under(target, 'lib/features/')) {
            violations.add(
              '$rel:$line: core must not import `$uri`',
            );
          }
        }

        if (layer == 'data' && _isGeneratedImport(target)) {
          violations.add(
            '$rel:$line: lib/data/** must not import generated '
            '(`$uri`); Pigeon gateways live under lib/platform/',
          );
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'ADR-009 architecture violations:\n${violations.join('\n')}',
    );
  });
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

List<File> _dartFilesUnder(Directory libRoot) {
  if (!libRoot.existsSync()) return const [];
  return libRoot
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

bool _isScanExempt(String rel) {
  if (rel == 'lib/main.dart') return true;
  if (rel.startsWith('lib/l10n/')) return true;
  if (rel.startsWith('lib/platform/generated/')) return true;
  if (rel.startsWith('lib/app/')) return true;
  return false;
}

String? _layerOf(String rel) {
  if (rel.startsWith('lib/features/')) return 'features';
  if (rel.startsWith('lib/domain/')) return 'domain';
  if (rel.startsWith('lib/core/')) return 'core';
  if (rel.startsWith('lib/data/')) return 'data';
  if (rel.startsWith('lib/platform/')) return 'platform';
  return null;
}

bool _isPlatformNonGenerated(String rel) {
  return rel.startsWith('lib/platform/') &&
      !rel.startsWith('lib/platform/generated/');
}

bool _under(String targetRel, String prefix) => targetRel.startsWith(prefix);

bool _isGeneratedImport(String targetRel) =>
    targetRel.startsWith('lib/platform/generated/');

// --- import / content parsing -----------------------------------------------

final _importOrExport = RegExp(
  r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''',
  multiLine: true,
);

final _colorHexLiteral = RegExp(r'Color\s*\(\s*0[xX]');

const _dbPackages = <String>{
  'sqflite',
  'drift',
  'sqlite3',
  'floor',
  'isar',
};

bool _isDbPackage(String uri) {
  if (!uri.startsWith('package:')) return false;
  final rest = uri.substring('package:'.length);
  final name = rest.split('/').first;
  return _dbPackages.contains(name);
}

bool _isRiverpodPackage(String uri) {
  if (!uri.startsWith('package:')) return false;
  final rest = uri.substring('package:'.length);
  final name = rest.split('/').first;
  return name == 'riverpod' ||
      name == 'flutter_riverpod' ||
      name.startsWith('riverpod_');
}

class _Directive {
  const _Directive({required this.uri, required this.line});
  final String uri;
  final int line;
}

Iterable<_Directive> _importOrExportUris(String source) sync* {
  for (final match in _importOrExport.allMatches(source)) {
    yield _Directive(
      uri: match.group(1)!,
      line: _lineNumber(source, match.start),
    );
  }
}

int _lineNumber(String source, int offset) {
  var line = 1;
  for (var i = 0; i < offset && i < source.length; i++) {
    if (source.codeUnitAt(i) == 0x0A) line++;
  }
  return line;
}

/// Resolves `package:waketok/...` or relative URIs to `lib/...` paths.
/// Returns null for non-waketok package imports.
String? _resolveWakatokTarget({
  required Directory packageRoot,
  required File fromFile,
  required String uri,
}) {
  if (uri.startsWith('package:waketok/')) {
    return 'lib/${uri.substring('package:waketok/'.length)}';
  }
  if (uri.startsWith('package:')) return null;
  if (uri.startsWith('dart:')) return null;

  // Relative import/export.
  final fromDir = fromFile.parent.uri;
  final resolved = fromDir.resolve(uri);
  final rootUri = packageRoot.uri;
  final resolvedPath = resolved.toFilePath();
  final rootPath = rootUri.toFilePath();
  if (!resolvedPath.startsWith(rootPath)) return null;
  var rel = resolvedPath.substring(rootPath.length).replaceAll('\\', '/');
  if (rel.startsWith('/')) rel = rel.substring(1);
  if (!rel.startsWith('lib/')) return null;
  return rel;
}
