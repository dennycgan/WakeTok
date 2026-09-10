import 'dart:typed_data';

/// Naked civil wall-clock from JPEG EXIF/TIFF (Cap 24.3 / ADR-050 D7).
///
/// Parses `DateTimeOriginal` (0x9003) else TIFF `DateTime` (0x0132) from an
/// APP1 Exif segment. Returns null for non-JPEG, missing tags, or malformed
/// payloads — callers fall back to Instant `~` (or omit).
class ExifNakedWallClock {
  const ExifNakedWallClock({
    required this.year,
    required this.month,
    required this.day,
    required this.hour,
    required this.minute,
    this.second,
  });

  final int year;
  final int month;
  final int day;
  final int hour;
  final int minute;
  final int? second;
}

/// See [ExifNakedWallClock].
ExifNakedWallClock? parseJpegExifNakedWallClock(Uint8List bytes) {
  if (bytes.length < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8) {
    return null;
  }
  var offset = 2;
  while (offset + 4 <= bytes.length) {
    if (bytes[offset] != 0xFF) {
      return null;
    }
    final marker = bytes[offset + 1];
    if (marker == 0xDA || marker == 0xD9) {
      return null;
    }
    final size = (bytes[offset + 2] << 8) | bytes[offset + 3];
    if (size < 2 || offset + 2 + size > bytes.length) {
      return null;
    }
    if (marker == 0xE1) {
      final segmentStart = offset + 4;
      final segmentEnd = offset + 2 + size;
      final parsed = _parseExifApp1(bytes, segmentStart, segmentEnd);
      if (parsed != null) {
        return parsed;
      }
    }
    offset += 2 + size;
  }
  return null;
}

ExifNakedWallClock? _parseExifApp1(Uint8List bytes, int start, int end) {
  // "Exif\0\0"
  if (end - start < 14) {
    return null;
  }
  if (bytes[start] != 0x45 ||
      bytes[start + 1] != 0x78 ||
      bytes[start + 2] != 0x69 ||
      bytes[start + 3] != 0x66 ||
      bytes[start + 4] != 0x00 ||
      bytes[start + 5] != 0x00) {
    return null;
  }
  final tiffStart = start + 6;
  final endianMark =
      String.fromCharCodes(bytes.sublist(tiffStart, tiffStart + 2));
  final littleEndian = endianMark == 'II';
  if (!littleEndian && endianMark != 'MM') {
    return null;
  }
  int u16(int at) {
    if (at + 2 > end) {
      return -1;
    }
    return littleEndian
        ? bytes[at] | (bytes[at + 1] << 8)
        : (bytes[at] << 8) | bytes[at + 1];
  }

  int u32(int at) {
    if (at + 4 > end) {
      return -1;
    }
    return littleEndian
        ? bytes[at] |
            (bytes[at + 1] << 8) |
            (bytes[at + 2] << 16) |
            (bytes[at + 3] << 24)
        : (bytes[at] << 24) |
            (bytes[at + 1] << 16) |
            (bytes[at + 2] << 8) |
            bytes[at + 3];
  }

  if (u16(tiffStart + 2) != 42) {
    return null;
  }
  final ifd0Offset = u32(tiffStart + 4);
  if (ifd0Offset < 0) {
    return null;
  }
  final ifd0 = tiffStart + ifd0Offset;
  String? dateTime;
  String? dateTimeOriginal;
  int? exifIfdOffset;
  final entryCount = u16(ifd0);
  if (entryCount < 0) {
    return null;
  }
  for (var i = 0; i < entryCount; i++) {
    final entry = ifd0 + 2 + i * 12;
    final tag = u16(entry);
    final type = u16(entry + 2);
    final count = u32(entry + 4);
    final valueOrOffset = u32(entry + 8);
    if (tag == 0x0132 && type == 2 && count > 0) {
      dateTime = _readAscii(
        bytes,
        tiffStart,
        end,
        valueOrOffset,
        count,
        littleEndian,
      );
    } else if (tag == 0x8769 && type == 4 && count == 1) {
      exifIfdOffset = valueOrOffset;
    }
  }
  if (exifIfdOffset != null) {
    final exifIfd = tiffStart + exifIfdOffset;
    final exifCount = u16(exifIfd);
    if (exifCount >= 0) {
      for (var i = 0; i < exifCount; i++) {
        final entry = exifIfd + 2 + i * 12;
        final tag = u16(entry);
        final type = u16(entry + 2);
        final count = u32(entry + 4);
        final valueOrOffset = u32(entry + 8);
        if (tag == 0x9003 && type == 2 && count > 0) {
          dateTimeOriginal = _readAscii(
            bytes,
            tiffStart,
            end,
            valueOrOffset,
            count,
            littleEndian,
          );
          break;
        }
      }
    }
  }
  final raw = dateTimeOriginal ?? dateTime;
  if (raw == null) {
    return null;
  }
  return _parseExifDateString(raw);
}

String? _readAscii(
  Uint8List bytes,
  int tiffStart,
  int end,
  int valueOrOffset,
  int count,
  bool littleEndian,
) {
  if (count <= 4) {
    final inline = Uint8List(4);
    if (littleEndian) {
      inline[0] = valueOrOffset & 0xFF;
      inline[1] = (valueOrOffset >> 8) & 0xFF;
      inline[2] = (valueOrOffset >> 16) & 0xFF;
      inline[3] = (valueOrOffset >> 24) & 0xFF;
    } else {
      inline[0] = (valueOrOffset >> 24) & 0xFF;
      inline[1] = (valueOrOffset >> 16) & 0xFF;
      inline[2] = (valueOrOffset >> 8) & 0xFF;
      inline[3] = valueOrOffset & 0xFF;
    }
    final endIndex = count.clamp(0, 4);
    var text = String.fromCharCodes(inline.sublist(0, endIndex));
    if (text.contains('\u0000')) {
      text = text.split('\u0000').first;
    }
    return text;
  }
  final dataAt = tiffStart + valueOrOffset;
  if (dataAt < tiffStart || dataAt + count > end) {
    return null;
  }
  var text = String.fromCharCodes(bytes.sublist(dataAt, dataAt + count));
  if (text.contains('\u0000')) {
    text = text.split('\u0000').first;
  }
  return text;
}

ExifNakedWallClock? _parseExifDateString(String raw) {
  final cleaned = raw.trim();
  final match = RegExp(
    r'^(\d{4}):(\d{2}):(\d{2}) (\d{2}):(\d{2})(?::(\d{2}))?',
  ).firstMatch(cleaned);
  if (match == null) {
    return null;
  }
  int? parsePart(int group) => int.tryParse(match.group(group)!);
  final year = parsePart(1);
  final month = parsePart(2);
  final day = parsePart(3);
  final hour = parsePart(4);
  final minute = parsePart(5);
  if (year == null ||
      month == null ||
      day == null ||
      hour == null ||
      minute == null) {
    return null;
  }
  final secondGroup = match.group(6);
  final second = secondGroup == null ? null : int.tryParse(secondGroup);
  return ExifNakedWallClock(
    year: year,
    month: month,
    day: day,
    hour: hour,
    minute: minute,
    second: second,
  );
}
