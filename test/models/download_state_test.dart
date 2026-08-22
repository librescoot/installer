import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/models/download_state.dart';

DownloadItem _item(DownloadItemType type, {bool complete = true}) {
  final item = DownloadItem(
    type: type,
    url: 'https://example.com/${type.name}',
    filename: '${type.name}.bin',
    expectedSize: 10,
  );
  if (complete) {
    item.localPath = '/tmp/${type.name}.bin';
    item.bytesDownloaded = 10;
  }
  return item;
}

void main() {
  group('DownloadState.missingRequiredTypes', () {
    test('an empty queue is missing everything the run needs', () {
      final state = DownloadState()
        ..requiredTypes = DownloadState.defaultRequiredTypes;
      expect(state.missingRequiredTypes.length,
          DownloadState.defaultRequiredTypes.length);
      // The old allFirmwareReady said yes here, because `every` on an empty
      // iterable is true.
      expect(state.allReady, isTrue);
    });

    test('a release with no artifacts is caught before the plan screen', () {
      final state = DownloadState()
        ..requiredTypes = DownloadState.defaultRequiredTypes
        ..items = [
          _item(DownloadItemType.mdbFirmware),
          _item(DownloadItemType.dbcFirmware),
        ];
      expect(state.missingRequiredTypes,
          containsAll([DownloadItemType.mdbArtifact, DownloadItemType.dbcArtifact]));
    });

    test('a complete release is missing nothing', () {
      final state = DownloadState()
        ..requiredTypes = DownloadState.defaultRequiredTypes
        ..items = [
          for (final t in DownloadState.defaultRequiredTypes) _item(t),
        ];
      expect(state.missingRequiredTypes, isEmpty);
    });

    test('an item still downloading is present, not missing', () {
      final state = DownloadState()
        ..requiredTypes = {DownloadItemType.mdbArtifact}
        ..items = [_item(DownloadItemType.mdbArtifact, complete: false)];
      expect(state.missingRequiredTypes, isEmpty);
      expect(state.allReady, isFalse);
    });

    test('the local-image flags require only the boards they name', () {
      final state = DownloadState()
        ..requiredTypes = {DownloadItemType.dbcFirmware}
        ..items = [_item(DownloadItemType.dbcFirmware)];
      expect(state.missingRequiredTypes, isEmpty);
    });

    test('bmaps are not blocking: a missing one costs speed, not correctness',
        () {
      expect(DownloadState.defaultRequiredTypes,
          isNot(contains(DownloadItemType.mdbBmap)));
      expect(DownloadState.defaultRequiredTypes,
          isNot(contains(DownloadItemType.dbcBmap)));
    });
  });
}
