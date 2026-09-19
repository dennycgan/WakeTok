import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/domain/session/order_policy.dart';

/// Cap 27 / ADR-056 D6: process-lifetime order preference (`null` until first
/// Confirm). Never persisted. Does **not** include Advance/Repeat/Eligibility.
final browseOrderPreferenceProvider =
    NotifierProvider<BrowseOrderPreferenceNotifier, OrderPolicy?>(
      BrowseOrderPreferenceNotifier.new,
    );

class BrowseOrderPreferenceNotifier extends Notifier<OrderPolicy?> {
  @override
  OrderPolicy? build() => null;

  void setPreference(OrderPolicy policy) {
    if (state == policy) {
      return;
    }
    state = policy;
  }
}
