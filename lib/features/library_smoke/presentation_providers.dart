import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/domain/presentation/presentation_metadata_repository.dart';

/// Bound at composition root ([PhotoLibraryGateway]).
final presentationMetadataRepositoryProvider =
    Provider<PresentationMetadataRepository>((ref) {
  throw UnimplementedError(
    'presentationMetadataRepositoryProvider must be overridden at '
    'the composition root',
  );
});
