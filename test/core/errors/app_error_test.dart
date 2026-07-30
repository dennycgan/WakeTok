import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/core/errors/app_error.dart';

void main() {
  test('AppError names match kickoff codes plus unknown', () {
    expect(
      AppError.values.map((e) => e.name).toSet(),
      equals(<String>{
        'unauthorized',
        'assetUnavailable',
        'iCloudDownloadRequired',
        'iCloudDownloadFailed',
        'unsupportedMedia',
        'noPlayableAudioTrack',
        'insufficientStorage',
        'exportFailed',
        'photosImportFailed',
        'albumUnavailable',
        'albumNotWritable',
        'operationCancelled',
        'unknown',
      }),
    );
    expect(AppError.values, hasLength(13));
    expect(
      AppError.values.map((e) => e.name),
      isNot(contains('inCloudUnavailable')),
    );
  });
}
