import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/domain/library/waketok_album_store.dart';

/// Bound at composition root to [WakeTokAlbumPreferencesStore] (Cap 19.3).
final wakeTokAlbumStoreProvider = Provider<WakeTokAlbumStore>(
  (ref) => throw UnimplementedError(
    'wakeTokAlbumStoreProvider must be overridden at the composition root',
  ),
);
