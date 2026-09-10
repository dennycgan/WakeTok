import 'package:flutter_riverpod/flutter_riverpod.dart';

/// True while the Cap 24 `"…"` more half-sheet route is open.
///
/// Independent of [cap19ActionsPanelOpenProvider] (ADR-050 / Cap 24.3 Q5=A).
final cap24MorePanelOpenProvider =
    NotifierProvider<Cap24MorePanelOpenNotifier, bool>(
  Cap24MorePanelOpenNotifier.new,
);

class Cap24MorePanelOpenNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setOpen(bool value) => state = value;
}
