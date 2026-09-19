import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/session/advance_mode.dart';
import 'package:waketok/domain/session/default_session_profile.dart';
import 'package:waketok/domain/session/derive_default_session_profile.dart';
import 'package:waketok/domain/session/order_policy.dart';
import 'package:waketok/domain/session/pool_profile_kind.dart';
import 'package:waketok/domain/session/repeat_policy.dart';
import 'package:waketok/domain/source/asset_source_availability.dart';
import 'package:waketok/domain/source/asset_source_kind.dart';
import 'package:waketok/domain/source/persistence_policy.dart';
import 'package:waketok/domain/source/resolved_pool_snapshot.dart';
import 'package:waketok/domain/source/source_pool_definition.dart';
import 'package:waketok/domain/source/source_reference.dart';
import 'package:waketok/domain/source/source_resolve_status.dart';

ResolvedPoolSnapshot _snapshot({
  required String id,
  required List<String> ids,
  required List<SourceResolveStatus> statuses,
}) {
  return ResolvedPoolSnapshot(
    id: id,
    coalescedAssetIds: ids,
    sourceStatuses: statuses,
  );
}

SourceResolveStatus _available(SourceReference ref, int count) {
  return SourceResolveStatus(
    reference: ref,
    availability: AssetSourceAvailability.available,
    rawCount: count,
    contributedCount: count,
  );
}

void main() {
  test('DPR-1 DefaultSessionProfile.generalMixed is Shuffle+Manual+RepeatAll',
      () {
    const c = DefaultSessionProfile.generalMixed;
    expect(c.orderPolicy, OrderPolicy.shuffle);
    expect(c.advanceMode, AdvanceMode.manual);
    expect(c.repeatPolicy, RepeatPolicy.repeatAll);
  });

  test(
    'DPR-2 DefaultSessionProfile.pureGeneratedClip is '
    'Sequential+Manual+RepeatAll',
    () {
      const c = DefaultSessionProfile.pureGeneratedClip;
      expect(c.orderPolicy, OrderPolicy.newestFirst);
      expect(c.advanceMode, AdvanceMode.manual);
      expect(c.repeatPolicy, RepeatPolicy.repeatAll);
    },
  );

  test('DPR-3 single-source built-in/album/smartAlbum → generalMixed', () {
    final cases = <SourceReference>[
      SourceReference.all,
      SourceReference.photos,
      SourceReference.videos,
      const SourceReference(kind: AssetSourceKind.album, id: 'album/x'),
      const SourceReference(kind: AssetSourceKind.smartAlbum, id: 'smart/y'),
    ];

    for (final ref in cases) {
      final def = SourcePoolDefinition(
        id: 'pool-${ref.kind.name}',
        persistencePolicy: PersistencePolicy.ephemeral,
        orderedSourceReferences: [ref],
      );
      final snap = _snapshot(
        id: def.id,
        ids: const ['a1', 'a2'],
        statuses: [_available(ref, 2)],
      );

      expect(
        classifyPoolProfile(definition: def, snapshot: snap),
        PoolProfileKind.generalMixed,
        reason: '${ref.kind.name} must classify Mixed',
      );
      expect(
        deriveDefaultSessionProfile(definition: def, snapshot: snap),
        DefaultSessionProfile.generalMixed,
        reason: '${ref.kind.name} must derive Mixed default',
      );
    }
  });

  test('DPR-4 empty SPD + empty Snapshot → still generalMixed', () {
    final def = SourcePoolDefinition(
      id: 'pool-empty',
      persistencePolicy: PersistencePolicy.ephemeral,
      orderedSourceReferences: const [],
    );
    final snap = _snapshot(
      id: def.id,
      ids: const [],
      statuses: const [],
    );

    expect(
      classifyPoolProfile(definition: def, snapshot: snap),
      PoolProfileKind.generalMixed,
    );
    expect(
      deriveDefaultSessionProfile(definition: def, snapshot: snap),
      DefaultSessionProfile.generalMixed,
    );
  });

  test('DPR-5 multi-source Photos+All → still generalMixed', () {
    final def = SourcePoolDefinition(
      id: 'pool-multi',
      persistencePolicy: PersistencePolicy.ephemeral,
      orderedSourceReferences: const [
        SourceReference.photos,
        SourceReference.all,
      ],
    );
    final snap = _snapshot(
      id: def.id,
      ids: const ['p1', 'a1', 'a2'],
      statuses: [
        _available(SourceReference.photos, 1),
        _available(SourceReference.all, 3),
      ],
    );

    expect(
      classifyPoolProfile(definition: def, snapshot: snap),
      PoolProfileKind.generalMixed,
    );
    expect(
      deriveDefaultSessionProfile(definition: def, snapshot: snap),
      DefaultSessionProfile.generalMixed,
    );
  });

  test('DPR-6 PoolProfileKind has generalMixed and pureGeneratedClip', () {
    expect(PoolProfileKind.values, hasLength(2));
    expect(PoolProfileKind.values, contains(PoolProfileKind.generalMixed));
    expect(
      PoolProfileKind.values,
      contains(PoolProfileKind.pureGeneratedClip),
    );
  });

  test('DPR-7 derive never returns Pure constant on Cap 12 fixtures', () {
    final fixtures = <(SourcePoolDefinition, ResolvedPoolSnapshot)>[
      (
        SourcePoolDefinition(
          id: 'all',
          persistencePolicy: PersistencePolicy.ephemeral,
          orderedSourceReferences: const [SourceReference.all],
        ),
        _snapshot(
          id: 'all',
          ids: const ['x'],
          statuses: [_available(SourceReference.all, 1)],
        ),
      ),
      (
        SourcePoolDefinition(
          id: 'empty',
          persistencePolicy: PersistencePolicy.ephemeral,
          orderedSourceReferences: const [],
        ),
        _snapshot(id: 'empty', ids: const [], statuses: const []),
      ),
      (
        SourcePoolDefinition(
          id: 'mix',
          persistencePolicy: PersistencePolicy.ephemeral,
          orderedSourceReferences: const [
            SourceReference.photos,
            SourceReference.videos,
          ],
        ),
        _snapshot(
          id: 'mix',
          ids: const ['p', 'v'],
          statuses: [
            _available(SourceReference.photos, 1),
            _available(SourceReference.videos, 1),
          ],
        ),
      ),
    ];

    for (final (def, snap) in fixtures) {
      final derived = deriveDefaultSessionProfile(
        definition: def,
        snapshot: snap,
      );
      expect(derived, isNot(DefaultSessionProfile.pureGeneratedClip));
      expect(derived, DefaultSessionProfile.generalMixed);
    }
  });
}
