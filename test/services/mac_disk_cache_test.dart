import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/usb_detector.dart';

/// The macOS disk-probe cache holds the /dev node the flasher will be handed.
/// It is cleared when the device goes away, but a board switching gadget does
/// not go away: mass storage to ethernet keeps a non-null device, so the drop
/// on null was skipped and the node stayed cached for a board that no longer
/// presents one.
class ScriptedDetector extends UsbDetector {
  final calls = <Completer<UsbDevice?>>[];

  @override
  Future<UsbDevice?> detectDevice() {
    final completer = Completer<UsbDevice?>();
    calls.add(completer);
    return completer.future;
  }
}

UsbDevice device(DeviceMode mode) => UsbDevice(
      id: mode == DeviceMode.massStorage ? 'usb-0525-a4a5' : 'usb-0525-a4a2',
      name: 'Librescoot MDB',
      path: mode == DeviceMode.massStorage ? '/dev/rdisk16' : '',
      vendorId: UsbDetector.targetVendorId,
      productId: mode == DeviceMode.massStorage
          ? UsbDetector.massStoragePid
          : UsbDetector.ethernetPid,
      mode: mode,
    );

void main() {
  late ScriptedDetector detector;
  late StreamSubscription<UsbDevice?> sub;

  setUp(() {
    detector = ScriptedDetector();
    sub = detector.deviceStream.listen((_) {});
  });

  tearDown(() async {
    detector.stopMonitoring();
    await sub.cancel();
  });

  /// Complete the oldest poll still waiting. `calls.last` is wrong: the timer
  /// can queue another poll before the previous one is answered, and
  /// completing an already-completed future throws.
  Future<void> settle(UsbDevice? answer) async {
    for (var i = 0; i < 20; i++) {
      final pending =
          detector.calls.where((c) => !c.isCompleted).toList();
      if (pending.isNotEmpty) {
        pending.first.complete(answer);
        await Future<void>.delayed(Duration.zero);
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    fail('no poll was waiting to be answered');
  }

  test('a mode change clears the cached disk node', () async {
    detector.startMonitoring(interval: const Duration(milliseconds: 10));
    await settle(device(DeviceMode.massStorage));

    detector.seedMacDiskInfoForTest({'path': '/dev/rdisk16'});
    expect(detector.hasMacDiskInfoCache, isTrue);

    // The board switches gadget. It never becomes null, so the pre-existing
    // clear-on-null never fires.
    await settle(device(DeviceMode.ethernet));

    expect(detector.hasMacDiskInfoCache, isFalse,
        reason: 'mass storage to ethernet must not leave a disk node cached');
  });

  test('a device going away still clears it', () async {
    detector.startMonitoring(interval: const Duration(milliseconds: 10));
    await settle(device(DeviceMode.massStorage));
    detector.seedMacDiskInfoForTest({'path': '/dev/rdisk16'});

    await settle(null);

    expect(detector.hasMacDiskInfoCache, isFalse);
  });

  test('the same device seen again keeps the cache', () async {
    detector.startMonitoring(interval: const Duration(milliseconds: 10));
    await settle(device(DeviceMode.massStorage));
    detector.seedMacDiskInfoForTest({'path': '/dev/rdisk16'});

    await settle(device(DeviceMode.massStorage));

    expect(detector.hasMacDiskInfoCache, isTrue,
        reason: 'an unchanged device must not cost us a good probe result');
  });
}
