import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/core/errors/app_error.dart';
import 'package:waketok/domain/source/asset_source_availability.dart';
import 'package:waketok/domain/source/asset_source_kind.dart';
import 'package:waketok/domain/source/resolved_source.dart';
import 'package:waketok/domain/source/source_reference.dart';
import 'package:waketok/domain/source/source_resolve_attempt.dart';
import 'package:waketok/features/library_smoke/source_resolve_attempt_mapping.dart';

import '../../library_smoke/fake_asset_source_repository.dart';

void main() {
  test('MAP-1 non-empty ResolvedSource becomes Success', () {
    const resolved = ResolvedSource(
      sourceId: 'photos',
      assetIdentifiers: ['a', 'b'],
    );
    final attempt = sourceResolveAttemptFromResolved(resolved);
    expect(attempt, isA<SourceResolveSuccess>());
    expect(
      (attempt as SourceResolveSuccess).assetIdentifiers,
      ['a', 'b'],
    );
  });

  test('MAP-2 empty ids are Success, not Failed', () {
    const resolved = ResolvedSource(
      sourceId: 'photos',
      assetIdentifiers: [],
    );
    final attempt = sourceResolveAttemptFromResolved(resolved);
    expect(attempt, isA<SourceResolveSuccess>());
    expect((attempt as SourceResolveSuccess).assetIdentifiers, isEmpty);
  });

  test('MAP-3 unauthorized PE maps to Failed(unauthorized)', () {
    final attempt = sourceResolveAttemptFromPlatformException(
      PlatformException(code: AppError.unauthorized.name),
    );
    expect(attempt, isA<SourceResolveFailed>());
    expect(
      (attempt as SourceResolveFailed).availability,
      AssetSourceAvailability.unauthorized,
    );
  });

  test('MAP-4 albumUnavailable PE maps to Failed(unavailable)', () {
    final attempt = sourceResolveAttemptFromPlatformException(
      PlatformException(code: AppError.albumUnavailable.name),
    );
    expect(attempt, isA<SourceResolveFailed>());
    expect(
      (attempt as SourceResolveFailed).availability,
      AssetSourceAvailability.unavailable,
    );
  });

  test('MAP-5 assetUnavailable PE is not mapped (caller rethrows)', () {
    expect(
      sourceResolveAttemptFromPlatformException(
        PlatformException(code: AppError.assetUnavailable.name),
      ),
      isNull,
    );
  });

  test('MAP-6 unknown PE is not mapped (caller rethrows)', () {
    expect(
      sourceResolveAttemptFromPlatformException(
        PlatformException(code: AppError.unknown.name),
      ),
      isNull,
    );
  });

  test('MAP-5 resolveOneFromRepository rethrows assetUnavailable', () async {
    final repo = FakeAssetSourceRepository();
    await expectLater(
      resolveOneFromRepository(
        repo,
        const SourceReference(
          kind: AssetSourceKind.entireLibrary,
          id: 'photos',
        ),
      ),
      throwsA(
        isA<PlatformException>().having(
          (e) => e.code,
          'code',
          AppError.assetUnavailable.name,
        ),
      ),
    );
  });

  test('MAP-6 resolveOneFromRepository rethrows unknown PE', () async {
    final repo = FakeAssetSourceRepository(
      resolveException: PlatformException(code: AppError.unknown.name),
    );
    await expectLater(
      resolveOneFromRepository(repo, SourceReference.photos),
      throwsA(
        isA<PlatformException>().having(
          (e) => e.code,
          'code',
          AppError.unknown.name,
        ),
      ),
    );
  });
}
