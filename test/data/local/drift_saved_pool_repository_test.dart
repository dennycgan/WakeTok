import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/data/local/drift_saved_pool_repository.dart';
import 'package:waketok/data/local/waketok_database.dart';
import 'package:waketok/domain/source/asset_source_kind.dart';
import 'package:waketok/domain/source/source_reference.dart';

import '../../domain/source/saved_pool_repository_contract.dart';

void main() {
  savedPoolRepositoryContract(
    'DriftSavedPoolRepository',
    ({required clock, required createId}) {
      final db = WaketokDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      return DriftSavedPoolRepository(
        db,
        clock: clock,
        createId: createId,
      );
    },
  );

  test('file-backed save survives close and reopen', () async {
    final file = File(
      '${Directory.systemTemp.path}/waketok_22_2_${identityHashCode(Object())}.sqlite',
    );
    addTearDown(() async {
      if (file.existsSync()) {
        file.deleteSync();
      }
    });

    final first = WaketokDatabase(NativeDatabase(file));
    final repo = DriftSavedPoolRepository(
      first,
      clock: () => DateTime.utc(2026, 9, 8),
      createId: () => 'persisted-1',
    );
    await repo.save(
      displayName: 'Keep',
      orderedSourceReferences: [
        SourceReference(kind: AssetSourceKind.album, id: 'album/keep'),
      ],
    );
    await first.close();

    final second = WaketokDatabase(NativeDatabase(file));
    addTearDown(second.close);
    final reopened = DriftSavedPoolRepository(second);
    final all = await reopened.loadAll();
    expect(all, hasLength(1));
    expect(all.single.id, 'persisted-1');
    expect(all.single.displayName, 'Keep');
    expect(all.single.orderedSourceReferences.single.id, 'album/keep');
  });

  test('delete cascades source rows', () async {
    final db = WaketokDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = DriftSavedPoolRepository(
      db,
      createId: () => 'cascade-1',
    );
    await repo.save(
      displayName: 'Cascade',
      orderedSourceReferences: [
        SourceReference(kind: AssetSourceKind.album, id: 'a'),
        SourceReference(kind: AssetSourceKind.smartAlbum, id: 's'),
      ],
    );
    expect(await db.select(db.savedPoolSources).get(), hasLength(2));
    await repo.delete('cascade-1');
    expect(await db.select(db.savedPoolSources).get(), isEmpty);
  });
}
