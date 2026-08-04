import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/domain/source/source_reference.dart';

/// Cap 7.4 UI-only selected built-in source (no resolve — Cap 7.5/7.6).
final mainBrowseSelectedSourceProvider =
    NotifierProvider<MainBrowseSelectedSource, SourceReference>(
  MainBrowseSelectedSource.new,
);

class MainBrowseSelectedSource extends Notifier<SourceReference> {
  @override
  SourceReference build() => SourceReference.all;

  void select(SourceReference next) {
    if (next.kind == state.kind && next.id == state.id) {
      return;
    }
    // Pools is not a SourceReference — callers must not pass it.
    state = next;
  }
}

/// Bottom destinations for the Main Browse shell.
enum MainBrowseDestination {
  browse,
  clips,
  auto,
  settings,
}

final mainBrowseDestinationProvider =
    NotifierProvider<MainBrowseDestinationNotifier, MainBrowseDestination>(
  MainBrowseDestinationNotifier.new,
);

class MainBrowseDestinationNotifier extends Notifier<MainBrowseDestination> {
  @override
  MainBrowseDestination build() => MainBrowseDestination.browse;

  void select(MainBrowseDestination next) {
    state = next;
  }
}
