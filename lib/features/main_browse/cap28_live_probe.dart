import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Cap 28.1 — live file probe for Settings round-trip / black-frame diagnosis.
///
/// Append-only log in App Documents (`wtlive.log`). Pull via
/// `devicectl device copy from` (`com.dennycgan.waketok`,
/// `Documents/wtlive.log`). Profile + Debug only; Release is a no-op
/// (no Documents I/O). Does **not** change product behaviour.
const String kCap28LiveProbeLogFileName = 'wtlive.log';

/// Profile + Debug only. Release builds are no-ops.
bool get cap28LiveProbeEnabled => !kReleaseMode;

/// Serializes appends so concurrent events stay ordered on disk.
class Cap28LiveProbe {
  Cap28LiveProbe._();

  static Future<void>? _chain;
  static String? _path;

  /// Truncate the live log (owner starts a fresh soak).
  static Future<void> clear() {
    if (!cap28LiveProbeEnabled) {
      return Future<void>.value();
    }
    final previous = _chain ?? Future<void>.value();
    final next = previous.then((_) => _truncate());
    _chain = next.catchError((Object _, StackTrace __) {});
    return next;
  }

  /// Owner saw L1↔L2 one-frame black (or similar) on this return.
  static Future<void> markBlackFrame({
    Map<String, Object?> extra = const {},
  }) {
    return log('OWNER_MARK_BLACK_FRAME', extra);
  }

  /// Owner saw clean return (still sharp / video OK) on this return.
  static Future<void> markReturnOk({Map<String, Object?> extra = const {}}) {
    return log('OWNER_MARK_RETURN_OK', extra);
  }

  static Future<void> log(
    String event, [
    Map<String, Object?> fields = const {},
  ]) {
    if (!cap28LiveProbeEnabled) {
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
      // Probe must never break Browse.
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
      // Probe must never break Browse.
    }
  }

  static Future<String> _ensurePath() async {
    if (_path != null) {
      return _path!;
    }
    final dir = await getApplicationDocumentsDirectory();
    _path = '${dir.path}/$kCap28LiveProbeLogFileName';
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
