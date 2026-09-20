import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Cap 27 — L1-stall + L2-ready observability probe (debts 468/477 closed;
/// kept for Open debt **478** non-`deviceLocal` / iCloud remount soak).
///
/// Append-only log in App Documents. Pull via `devicectl appDataContainer`
/// (`com.dennycgan.waketok`). Profile + Debug only ([cap27L1StallProbeEnabled]);
/// Release builds are no-ops (no Documents I/O). Settings UI lives in
/// `cap27_l1_stall_probe_settings.dart` under Browse → Settings when
/// `!kReleaseMode`.
const String kCap27L1StallProbeLogFileName = 'cap27_l1_stall_probe.log';

/// Profile + Debug only. Release builds are no-ops.
bool get cap27L1StallProbeEnabled => !kReleaseMode;

/// Serializes appends so concurrent events stay ordered on disk.
class Cap27L1StallProbe {
  Cap27L1StallProbe._();

  static Future<void>? _chain;
  static String? _path;

  /// Human mark: owner sees L1 stuck (before swipe heal).
  static Future<void> markStuck({Map<String, Object?> extra = const {}}) {
    return log('OWNER_MARK_STUCK', extra);
  }

  /// Human mark: after swipe-away + swipe-back, L2 recovered.
  static Future<void> markHealed({Map<String, Object?> extra = const {}}) {
    return log('OWNER_MARK_HEALED', extra);
  }

  static Future<void> log(String event, [Map<String, Object?> fields = const {}]) {
    if (!cap27L1StallProbeEnabled) {
      return Future<void>.value();
    }
    final previous = _chain ?? Future<void>.value();
    final next = previous.then((_) => _append(event, fields));
    _chain = next.catchError((Object _, StackTrace __) {});
    return next;
  }

  static Future<void> _append(String event, Map<String, Object?> fields) async {
    try {
      final path = await _ensurePath();
      final buf = StringBuffer()
        ..write(DateTime.now().toUtc().toIso8601String())
        ..write(' event=')
        ..write(event);
      for (final e in fields.entries) {
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
    _path = '${dir.path}/$kCap27L1StallProbeLogFileName';
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
