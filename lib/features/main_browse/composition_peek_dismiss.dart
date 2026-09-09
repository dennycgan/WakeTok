import 'package:flutter/foundation.dart';

/// Registry so naming / capacity dialogs can dismiss an open composition
/// peek (OverlayEntry) without importing the peek UI (avoids cycles).
///
/// Covers **Temp chip → Save this pool → naming / capacity**. Saved chip
/// peek has no Save footer; center Saved Info (menu i) does not register.
VoidCallback? _compositionPeekDismiss;

void registerCompositionPeekDismiss(VoidCallback? dismiss) {
  _compositionPeekDismiss = dismiss;
}

/// No-op when no ephemeral composition peek is open.
void dismissCompositionPeekIfOpen() {
  final dismiss = _compositionPeekDismiss;
  if (dismiss == null) {
    return;
  }
  dismiss();
}
