import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/models/install_gate.dart';
import 'package:librescoot_installer/services/usb_detector.dart';

UsbDevice massStorage({String id = 'board', int? sizeBytes = 1024}) =>
    UsbDevice(
      id: id,
      name: 'MDB',
      path: r'\\.\PHYSICALDRIVE1',
      vendorId: UsbDetector.targetVendorId,
      productId: UsbDetector.massStoragePid,
      mode: DeviceMode.massStorage,
      sizeBytes: sizeBytes,
    );

void main() {
  group('welcome gating', () {
    test('local-only images are enabled without network channels or maps', () {
      expect(
        canStartWelcome(
          isProcessing: false,
          localImagesOnly: true,
          channelsLoading: true,
          channelsLoadFailed: true,
          hasChannels: false,
          wantsOfflineMaps: true,
          hasRegion: false,
        ),
        isTrue,
      );
    });

    test('network installs still require a channel and map region', () {
      expect(
        canStartWelcome(
          isProcessing: false,
          localImagesOnly: false,
          channelsLoading: false,
          channelsLoadFailed: false,
          hasChannels: true,
          wantsOfflineMaps: true,
          hasRegion: false,
        ),
        isFalse,
      );
    });
  });

  test('a changed target identity or path is rejected before flashing', () {
    final expected = massStorage();
    expect(
      UsbDetector.isSameMassStorageTarget(
        expected: expected,
        observed: massStorage(id: 'different'),
        expectedPath: expected.path,
        observedPath: expected.path,
      ),
      isFalse,
    );
    expect(
      UsbDetector.isSameMassStorageTarget(
        expected: expected,
        observed: massStorage(),
        expectedPath: expected.path,
        observedPath: r'\\.\PHYSICALDRIVE2',
      ),
      isFalse,
    );
    expect(
      UsbDetector.isSameMassStorageTarget(
        expected: expected,
        observed: massStorage(),
        expectedPath: expected.path,
        observedPath: expected.path,
      ),
      isTrue,
    );
  });

  test('pairing and keycard starts reject duplicate synchronous calls', () {
    expect(canStartBluetoothPairing(active: true, starting: false), isFalse);
    expect(canStartBluetoothPairing(active: false, starting: true), isFalse);
    expect(canStartKeycardLearning(learning: true, starting: false), isFalse);
    expect(canStartKeycardLearning(learning: false, starting: true), isFalse);
  });
}
