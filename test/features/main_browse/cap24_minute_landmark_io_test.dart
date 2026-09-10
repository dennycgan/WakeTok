import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/features/main_browse/cap24_minute_landmark.dart';

void main() {
  test(
    'readCoverBytesForMinuteLandmark: missing file → null (FileSystemException), '
    'does not throw',
    () async {
      final missing =
          '${Directory.systemTemp.path}/waketok-cap24-missing-cover-'
          '${identityHashCode(Object())}.bin';
      expect(File(missing).existsSync(), isFalse);

      final bytes = await readCoverBytesForMinuteLandmark(missing);
      expect(bytes, isNull);
    },
  );

  test(
    'readCoverBytesForMinuteLandmark: existing empty file → empty bytes',
    () async {
      final file = File(
        '${Directory.systemTemp.path}/waketok-cap24-empty-cover.bin',
      );
      await file.writeAsBytes(const <int>[]);
      addTearDown(() {
        if (file.existsSync()) {
          file.deleteSync();
        }
      });

      final bytes = await readCoverBytesForMinuteLandmark(file.path);
      expect(bytes, isNotNull);
      expect(bytes, isEmpty);
    },
  );
}
