import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Cap 29.4 — Documents probe for Photos Access manage / Open Settings soak.
///
/// Append-only log in App Documents (`cap29_access_scope.log`). Pull via
/// `devicectl device copy from` (`com.dennycgan.waketok`,
/// `Documents/cap29_access_scope.log`). Profile + Debug only; Release is a
/// no-op. Does **not** change product behaviour. Separate from Cap 28
/// `wtlive.log`.
const String kCap29AccessScopeProbeLogFileName = 'cap29_access_scope.log';

/// Profile + Debug only. Release builds are no-ops.
bool get cap29AccessScopeProbeEnabled => !kReleaseMode;

/// Serializes appends so concurrent events stay ordered on disk.
class Cap29AccessScopeProbe {
  Cap29AccessScopeProbe._();

  static Future<void>? _chain;
  static String? _path;

  /// Truncate the probe log (owner starts a fresh soak).
  static Future<void> clear() {
    if (!cap29AccessScopeProbeEnabled) {
      return Future<void>.value();
    }
    final previous = _chain ?? Future<void>.value();
    final next = previous.then((_) => _truncate());
    _chain = next.catchError((Object _, StackTrace __) {});
    return next;
  }

  static Future<void> log(
    String event, [
    Map<String, Object?> fields = const {},
  ]) {
    if (!cap29AccessScopeProbeEnabled) {
      return Future<void>.value();
    }
    final previous = _chain ?? Future<void>.value();
    final next = previous.then((_) => _append(event, fields));
    _chain = next.catchError((Object _, StackTrace __) {});
    return next;
  }

  static Future<void> _truncate() async {
    try {
      final path = await _ensurePath();
      await File(path).writeAsString(
        '${DateTime.now().toUtc().toIso8601String()} event=LOG_CLEARED\n',
        flush: true,
      );
    } catch (_) {
      // Probe must never break product paths.
    }
  }

  static Future<void> _append(String event, Map<String, Object?> fields) async {
    try {
      final path = await _ensurePath();
      final now = DateTime.now().toUtc();
      final buf = StringBuffer()
        ..write(now.toIso8601String())
        ..write(' epochMs=')
        ..write(now.millisecondsSinceEpoch)
        ..write(' event=')
        ..write(event);
      for (final e in fields.entries) {
        if (e.key == 'epochMs') {
          continue;
        }
        buf
          ..write(' ')
          ..write(e.key)
          ..write('=')
          ..write(_fmt(e.value));
      }
      buf.writeln();
      await File(path).writeAsString(
        buf.toString(),
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {
      // Probe must never break product paths.
    }
  }

  static Future<String> _ensurePath() async {
    if (_path != null) {
      return _path!;
    }
    final dir = await getApplicationDocumentsDirectory();
    _path = '${dir.path}/$kCap29AccessScopeProbeLogFileName';
    return _path!;
  }

  static String _fmt(Object? value) {
    if (value == null) {
      return 'null';
    }
    final s = value.toString().replaceAll(' ', '_');
    if (s.isEmpty) {
      return 'empty';
    }
    return s;
  }
}
