import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/spikes/poc_09/poc_09_duration.dart';

void main() {
  test('isOriginalObviouslyLonger requires > 2.0s delta', () {
    expect(
      isOriginalObviouslyLonger(originalSec: 10, currentSec: 8.1),
      isFalse,
    );
    expect(
      isOriginalObviouslyLonger(originalSec: 10, currentSec: 7.9),
      isTrue,
    );
  });

  test('isExportMatchingCurrent within 0.25s', () {
    expect(
      isExportMatchingCurrent(exportSec: 8.0, currentSec: 8.2),
      isTrue,
    );
    expect(
      isExportMatchingCurrent(exportSec: 8.0, currentSec: 8.3),
      isFalse,
    );
  });

  test('formatProbeSummary includes advisory flag', () {
    final s = formatProbeSummary(
      phAssetDurationSec: 8,
      currentAvDurationSec: 8,
      originalAvDurationSec: 30,
      exportDurationSec: 8,
      audioTrackCount: 1,
      textTrackCount: 0,
    );
    expect(s.contains('origLonger(>2s)=true'), isTrue);
  });

  test('formatTrimGateSummary PASS when longer and export matches', () {
    final s = formatTrimGateSummary(
      currentAvDurationSec: 8,
      originalAvDurationSec: 30,
      exportDurationSec: 8.1,
    );
    expect(s.contains('trimGate=PASS'), isTrue);
    expect(s.contains('origLonger(>2s)=true'), isTrue);
    expect(s.contains('exp≈cur(±0.25s)=true'), isTrue);
  });

  test('formatTrimGateSummary CHECK when not longer', () {
    final s = formatTrimGateSummary(
      currentAvDurationSec: 37.48,
      originalAvDurationSec: 37.48,
      exportDurationSec: 37.48,
    );
    expect(s.contains('trimGate=CHECK'), isTrue);
    expect(s.contains('origLonger(>2s)=false'), isTrue);
  });

  test('formatSloMoGateSummary N/A when not HFR', () {
    final s = formatSloMoGateSummary(
      isHighFrameRate: false,
      phAssetDurationSec: 10,
      currentAvDurationSec: 10,
      exportDurationSec: 10,
    );
    expect(s.contains('sloMoGate=N/A'), isTrue);
  });

  test('formatSloMoGateSummary PASS when HFR and durations align', () {
    final s = formatSloMoGateSummary(
      isHighFrameRate: true,
      phAssetDurationSec: 12.0,
      currentAvDurationSec: 12.0,
      exportDurationSec: 12.1,
    );
    expect(s.contains('sloMoGate=PASS'), isTrue);
    expect(s.contains('HFR=true'), isTrue);
  });

  test('formatAudioGateSummary PASS when tracks and export exist', () {
    final s = formatAudioGateSummary(
      audioTrackCount: 1,
      exportPath: '/tmp/out.mp4',
      exportDurationSec: 10,
    );
    expect(s.contains('audioGate=PASS'), isTrue);
  });

  test('formatAudioGateSummary FAIL when no audio tracks', () {
    final s = formatAudioGateSummary(
      audioTrackCount: 0,
      exportPath: '/tmp/out.mp4',
      exportDurationSec: 10,
    );
    expect(s.contains('audioGate=FAIL'), isTrue);
  });

  test('formatFailGateSummary PASS for inCloudUnavailable without path', () {
    final s = formatFailGateSummary(
      networkAccessAllowed: false,
      errorCode: 'inCloudUnavailable',
      exportPath: null,
    );
    expect(s.contains('failGate=PASS'), isTrue);
  });

  test('formatFailGateSummary FAIL when export path set', () {
    final s = formatFailGateSummary(
      networkAccessAllowed: false,
      errorCode: 'inCloudUnavailable',
      exportPath: '/tmp/out.mp4',
    );
    expect(s.contains('failGate=FAIL'), isTrue);
  });

  test('formatFailGateSummary CHECK for other errors', () {
    final s = formatFailGateSummary(
      networkAccessAllowed: false,
      errorCode: 'currentObtainFailed',
      exportPath: null,
    );
    expect(s.contains('failGate=CHECK'), isTrue);
  });

  test('formatFailGateSummary N/A when network on', () {
    final s = formatFailGateSummary(
      networkAccessAllowed: true,
      errorCode: 'inCloudUnavailable',
      exportPath: null,
    );
    expect(s.contains('failGate=N/A'), isTrue);
  });

  test('formatControlGateSummary PASS when network on and export OK', () {
    final s = formatControlGateSummary(
      networkAccessAllowed: true,
      errorCode: null,
      exportPath: '/tmp/out.mp4',
      exportDurationSec: 12,
    );
    expect(s.contains('controlGate=PASS'), isTrue);
  });

  test('formatControlGateSummary CHECK when network on but failed', () {
    final s = formatControlGateSummary(
      networkAccessAllowed: true,
      errorCode: 'inCloudUnavailable',
      exportPath: null,
      exportDurationSec: null,
    );
    expect(s.contains('controlGate=CHECK'), isTrue);
  });

  test('formatControlGateSummary N/A when network off', () {
    final s = formatControlGateSummary(
      networkAccessAllowed: false,
      errorCode: 'inCloudUnavailable',
      exportPath: null,
      exportDurationSec: null,
    );
    expect(s.contains('controlGate=N/A'), isTrue);
  });
}
