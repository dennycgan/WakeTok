import 'package:waketok/l10n/app_localizations.dart';

/// Formats [fileSizeBytes] for Overlay row 3; null/negative → empty (not zero).
///
/// Uses decimal SI steps (1000) so labels match iOS Photos Info (e.g. 2.9 MB),
/// not binary MiB (1024).
String formatOverlayFileSize({
  required AppLocalizations l10n,
  required int? fileSizeBytes,
}) {
  if (fileSizeBytes == null || fileSizeBytes < 0) {
    return '';
  }
  if (fileSizeBytes < 1000) {
    return l10n.mediaInfoFileSizeBytes(fileSizeBytes.toString());
  }
  final kb = fileSizeBytes / 1000;
  if (kb < 1000) {
    return l10n.mediaInfoFileSizeKb(_oneDecimal(kb));
  }
  final mb = kb / 1000;
  if (mb < 1000) {
    return l10n.mediaInfoFileSizeMb(_oneDecimal(mb));
  }
  final gb = mb / 1000;
  return l10n.mediaInfoFileSizeGb(_oneDecimal(gb));
}

String _oneDecimal(double value) {
  final rounded = (value * 10).round() / 10;
  if (rounded == rounded.roundToDouble()) {
    return rounded.toInt().toString();
  }
  return rounded.toStringAsFixed(1);
}
