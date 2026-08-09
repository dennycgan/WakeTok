import 'package:waketok/features/main_browse/feed_media_request_gate.dart';

/// Begins metadata + current-page display gates in one call (Cap 8.5).
///
/// Hard constraint: both [FeedMediaRequestGate.begin] calls happen in the same
/// synchronous activation path so the two gates cannot skew across microtasks.
class FeedActivationCoordinator {
  final FeedMediaRequestGate metadataGate = FeedMediaRequestGate();
  final FeedMediaRequestGate currentDisplayGate = FeedMediaRequestGate();

  ({int metadata, int display}) beginCurrentItem() {
    return (
      metadata: metadataGate.begin(),
      display: currentDisplayGate.begin(),
    );
  }
}
