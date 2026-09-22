import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Cap 29.3 / ADR-058 D4 / ADR-059 — in-app access-scope restart allowlist.
///
/// Locks: do not add a third in-app-scope `restartSession` path beside
/// [AccessScopeAuthorityNotifier]. Origin (and kin) may still call
/// `restartSession` inside `browse_session_providers.dart` (ADR-057).
void main() {
  final packageRoot = _findPackageRoot();
  final libRoot = Directory('${packageRoot.path}/lib');

  test(
    'architecture: lib/features/** must not call .restartSession( (Cap 29.3)',
    () {
      final violations = _scanFeaturesRestartCalls(packageRoot, libRoot);
      expect(violations, isEmpty, reason: violations.join('\n'));
    },
  );

  test(
    'architecture: .restartSession( only in access_scope_authority + '
    'browse_session_providers (Cap 29.3)',
    () {
      final violations = _scanLibRestartCallsOutsideAllowlist(
        packageRoot,
        libRoot,
      );
      expect(violations, isEmpty, reason: violations.join('\n'));
    },
  );

  test(
    'architecture: Photos Access Settings must not restart or notify '
    'authority directly (Cap 29.3 / ADR-059)',
    () {
      final file = File(
        '${libRoot.path}/features/authorization/'
        'photos_access_settings_section.dart',
      );
      expect(file.existsSync(), isTrue);
      final violations = _scanPhotosAccessSettingsForbidden(file);
      expect(violations, isEmpty, reason: violations.join('\n'));
    },
  );

  // --- Negative / calibration (proves the scanner is not a no-op) ---

  test(
    'negative: regex matches .restartSession( call, not dartdoc / bare name',
    () {
      expect(
        restartSessionCallPattern.hasMatch(
          'await ref.read(n).restartSession();',
        ),
        isTrue,
      );
      expect(
        restartSessionCallPattern.hasMatch('n.restartSession ();'),
        isTrue,
      );
      // Dartdoc / identifier without call paren — must NOT match.
      expect(
        restartSessionCallPattern.hasMatch(
          'only consumer allowed to call '
          '[BrowseSessionNotifier.restartSession]',
        ),
        isFalse,
      );
      expect(restartSessionCallPattern.hasMatch('restartSession()'), isFalse);
      expect(
        restartSessionCallPattern.hasMatch('void restartSession() async'),
        isFalse,
      );
    },
  );

  test(
    'negative: allowlist scan flags temp-dir dart file with call',
    () {
      final tempDir = Directory.systemTemp.createTempSync(
        'waketok_cap29_3_restart_',
      );
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });
      // Path key must look like a lib/features file for the allowlist check;
      // on-disk location stays under systemTemp (never under package lib/).
      final evilRel = 'lib/features/evil_probe.dart';
      final evilFile = File('${tempDir.path}/evil_probe.dart')
        ..writeAsStringSync(
          'await ref.read(browseSessionProvider.notifier)'
          '.restartSession();\n',
        );
      final allowedAuthority = File('${tempDir.path}/access_scope_authority.dart')
        ..writeAsStringSync(
          'await ref.read(browseSessionProvider.notifier)'
          '.restartSession();\n',
        );

      final pathToSource = <String, String>{
        evilRel: evilFile.readAsStringSync(),
        'lib/app/browse/access_scope_authority.dart':
            allowedAuthority.readAsStringSync(),
        'lib/app/browse/browse_session_providers.dart':
            'unawaited(restartSession());\n',
      };
      // Prove files existed on disk under systemTemp for this probe.
      expect(evilFile.existsSync(), isTrue);
      expect(tempDir.path.contains(Directory.systemTemp.path), isTrue);
      expect(
        tempDir.path.contains('${_findPackageRoot().path}/lib'),
        isFalse,
      );

      final violations = collectRestartCallsOutsideAllowlist(pathToSource);
      expect(violations, isNotEmpty);
      expect(
        violations.any((v) => v.startsWith('$evilRel:')),
        isTrue,
      );
      expect(
        violations.any(
          (v) => v.startsWith('lib/app/browse/access_scope_authority.dart:'),
        ),
        isFalse,
      );
      expect(
        violations.any(
          (v) => v.startsWith('lib/app/browse/browse_session_providers.dart:'),
        ),
        isFalse,
      );
    },
  );

  test(
    'negative: Photos Access Settings scanner flags forbidden tokens',
    () {
      final tempDir = Directory.systemTemp.createTempSync(
        'waketok_cap29_3_settings_',
      );
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });
      final dirty = File('${tempDir.path}/dirty.dart')
        ..writeAsStringSync(
          "// probe\n"
          "void evil() {\n"
          "  ref.read(accessScopeAuthorityProvider.notifier)"
          ".notifyAccessScopePossiblyChanged();\n"
          "  // also banned word:\n"
          "  // restartSession\n"
          "}\n",
        );
      expect(tempDir.path.contains(Directory.systemTemp.path), isTrue);

      final violations = _scanPhotosAccessSettingsForbidden(dirty);
      expect(violations.length, greaterThanOrEqualTo(2));
      expect(
        violations.any((v) => v.contains('accessScopeAuthorityProvider')),
        isTrue,
      );
      expect(violations.any((v) => v.contains('restartSession')), isTrue);
    },
  );

  test(
    'negative: Photos Access Settings scanner accepts clean sample',
    () {
      final tempDir = Directory.systemTemp.createTempSync(
        'waketok_cap29_3_settings_clean_',
      );
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });
      final clean = File('${tempDir.path}/clean.dart')
        ..writeAsStringSync(
          "// clean Settings-shaped sample\n"
          "void onManage() {\n"
          "  ref.read(photosAuthorizationProvider.notifier)"
          ".presentLimitedLibraryPicker();\n"
          "}\n"
          "void onOpen() {\n"
          "  ref.read(openAppSettingsProvider)();\n"
          "}\n",
        );
      expect(_scanPhotosAccessSettingsForbidden(clean), isEmpty);
    },
  );
}

/// Literal call shape: `.restartSession(` (optional space before `(`).
/// Does **not** match bare `restartSession` in dartdoc / method decls.
final restartSessionCallPattern = RegExp(r'\.restartSession\s*\(');

const restartSessionAllowlist = <String>{
  'lib/app/browse/access_scope_authority.dart',
  'lib/app/browse/browse_session_providers.dart',
};

List<String> collectRestartCallsOutsideAllowlist(
  Map<String, String> pathToSource,
) {
  final violations = <String>[];
  for (final entry in pathToSource.entries) {
    final rel = entry.key;
    if (restartSessionAllowlist.contains(rel)) continue;
    for (final match in restartSessionCallPattern.allMatches(entry.value)) {
      violations.add(
        '$rel:${_lineNumber(entry.value, match.start)}: '
        '.restartSession( outside allowlist $restartSessionAllowlist',
      );
    }
  }
  return violations;
}

List<String> _scanFeaturesRestartCalls(
  Directory packageRoot,
  Directory libRoot,
) {
  final violations = <String>[];
  for (final file in _dartFilesUnder(Directory('${libRoot.path}/features'))) {
    final rel = _posixRel(packageRoot, file);
    final source = file.readAsStringSync();
    for (final match in restartSessionCallPattern.allMatches(source)) {
      violations.add(
        '$rel:${_lineNumber(source, match.start)}: '
        'features must not call .restartSession( — '
        'in-app access-scope uses AccessScopeAuthorityNotifier '
        '(ADR-058 D4 / Cap 29.3)',
      );
    }
  }
  return violations;
}

List<String> _scanLibRestartCallsOutsideAllowlist(
  Directory packageRoot,
  Directory libRoot,
) {
  final pathToSource = <String, String>{};
  for (final file in _dartFilesUnder(libRoot)) {
    pathToSource[_posixRel(packageRoot, file)] = file.readAsStringSync();
  }
  return collectRestartCallsOutsideAllowlist(pathToSource);
}

List<String> _scanPhotosAccessSettingsForbidden(File file) {
  final source = file.readAsStringSync();
  final violations = <String>[];
  if (source.contains('restartSession')) {
    violations.add(
      'photos_access_settings_section.dart must not mention '
      'restartSession — Manage uses presentLimitedLibraryPicker only',
    );
  }
  if (source.contains('accessScopeAuthorityProvider')) {
    violations.add(
      'photos_access_settings_section.dart must not read '
      'accessScopeAuthorityProvider — notifier owns notify',
    );
  }
  if (source.contains('notifyAccessScopePossiblyChanged')) {
    violations.add(
      'photos_access_settings_section.dart must not call '
      'notifyAccessScopePossiblyChanged',
    );
  }
  return violations;
}

List<File> _dartFilesUnder(Directory root) {
  if (!root.existsSync()) return const [];
  return root
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();
}

String _posixRel(Directory packageRoot, File file) {
  return file.path
      .substring(packageRoot.path.length + 1)
      .replaceAll(r'\', '/');
}

int _lineNumber(String source, int offset) {
  var line = 1;
  for (var i = 0; i < offset && i < source.length; i++) {
    if (source.codeUnitAt(i) == 0x0A) line++;
  }
  return line;
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
