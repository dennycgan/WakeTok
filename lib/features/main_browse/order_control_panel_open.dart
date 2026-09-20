import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Cap 27.4 / ADR-055: order-control half-sheet open flag.
///
/// Independent of [cap19ActionsPanelOpenProvider] /
/// [cap24MorePanelOpenProvider]. Used to disarm Live long-press / left-swipe
/// while the sheet is up. Does **not** set [browseCoveringRouteOpenProvider]
/// (that path is full-screen Build-a-Pool user-intent pause).
final orderControlPanelOpenProvider =
    NotifierProvider<OrderControlPanelOpenNotifier, bool>(
      OrderControlPanelOpenNotifier.new,
    );

class OrderControlPanelOpenNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setOpen(bool open) {
    if (state == open) {
      return;
    }
    state = open;
  }
}
