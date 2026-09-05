import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/usb_detector.dart';

/// A detector whose probe finishes when the test says so, standing in for the
/// ioreg / system_profiler / PowerShell chain that can outlast the poll
/// interval on a real host.
class ScriptedDetector extends UsbDetector {
  final calls = <Completer<UsbDevice?>>[];

  @override
  Future<UsbDevice?> detectDevice() {
    final completer = Completer<UsbDevice?>();
    calls.add(completer);
    return completer.future;
  }
}

UsbDevice device(String id, {DeviceMode mode = DeviceMode.massStorage}) =>
    UsbDevice(
      id: id,
      name: 'Librescoot MDB',
      path: '/dev/$id',
      vendorId: UsbDetector.targetVendorId,
      productId: UsbDetector.massStoragePid,
      mode: mode,
    );

void main() {
  late ScriptedDetector detector;
  late List<UsbDevice?> emitted;
  late StreamSubscription<UsbDevice?> sub;

  setUp(() {
    detector = ScriptedDetector();
    emitted = [];
    sub = detector.deviceStream.listen(emitted.add);
  });

  tearDown(() async {
    await sub.cancel();
    detector.dispose();
  });

  test('a normal poll advances the accepted device generation', () async {
    expect(detector.deviceEventGeneration, 0);
    detector.startMonitoring(interval: const Duration(milliseconds: 10));
    expect(detector.calls, hasLength(1));

    detector.calls.first.complete(device('a4a5'));
    await pumpEventQueue();

    expect(detector.currentDevice?.id, 'a4a5');
    expect(detector.deviceEventGeneration, 1);
    expect(emitted, hasLength(1));
  });

  test(
    'a retry rejects the pre-failure identity until a fresh target arrives',
    () {
      final target = device('a4a5');
      expect(
        UsbDetector.acceptsFreshMassStorageTarget(
          failureGeneration: 4,
          currentGeneration: 4,
          device: target,
          path: '/dev/a4a5',
        ),
        isFalse,
      );
      expect(
        UsbDetector.acceptsFreshMassStorageTarget(
          failureGeneration: 4,
          currentGeneration: 5,
          device: target,
          path: '',
        ),
        isFalse,
      );
      expect(
        UsbDetector.acceptsFreshMassStorageTarget(
          failureGeneration: 4,
          currentGeneration: 5,
          device: target,
          path: '/dev/a4a5',
        ),
        isTrue,
      );
    },
  );

  test('a stale macOS probe loses both ownership generations', () {
    expect(
      UsbDetector.macDiskProbeResultBelongsTo(
        probePollingGeneration: 3,
        currentPollingGeneration: 3,
        probeDeviceGeneration: 7,
        currentDeviceGeneration: 8,
        probeDeviceIdentity: 'usb-0525-a4-a5',
        currentDeviceIdentity: 'usb-0525-a4-a5',
      ),
      isFalse,
    );
    expect(
      UsbDetector.macDiskProbeResultBelongsTo(
        probePollingGeneration: 3,
        currentPollingGeneration: 4,
        probeDeviceGeneration: 7,
        currentDeviceGeneration: 7,
        probeDeviceIdentity: 'usb-0525-a4-a5',
        currentDeviceIdentity: 'usb-0525-a4-a5',
      ),
      isFalse,
    );
    expect(
      UsbDetector.macDiskProbeResultBelongsTo(
        probePollingGeneration: 3,
        currentPollingGeneration: 3,
        probeDeviceGeneration: 7,
        currentDeviceGeneration: 7,
        probeDeviceIdentity: 'usb-0525-a4-a5',
        currentDeviceIdentity: 'usb-other',
      ),
      isFalse,
    );
  });

  test(
    'a tick during an in-flight poll does not start a second probe',
    () async {
      detector.startMonitoring(interval: const Duration(milliseconds: 10));
      expect(detector.calls, hasLength(1));

      // Several intervals pass with the first probe still out there.
      await Future.delayed(const Duration(milliseconds: 60));
      expect(detector.calls, hasLength(1));

      detector.calls.first.complete(device('a4a5'));
      await pumpEventQueue();

      // Only once the probe lands can the next tick run.
      await Future.delayed(const Duration(milliseconds: 30));
      expect(detector.calls.length, greaterThan(1));
    },
  );

  test('a poll still in flight when monitoring stops writes nothing', () async {
    detector.startMonitoring(interval: const Duration(milliseconds: 10));
    final inFlight = detector.calls.first;

    detector.stopMonitoring();
    inFlight.complete(device('a4a5'));
    await pumpEventQueue();

    expect(detector.currentDevice, isNull);
    expect(emitted, isEmpty);
  });

  test('a stale poll cannot undo what a newer one established', () async {
    // The reversal this guards against: the slow probe was started first and
    // still holds the device, the state has since moved on to disconnected.
    detector.startMonitoring(interval: const Duration(milliseconds: 10));
    final slow = detector.calls.first;

    detector.stopMonitoring();
    detector.startMonitoring(interval: const Duration(milliseconds: 10));
    final fresh = detector.calls.last;

    fresh.complete(null);
    await pumpEventQueue();
    expect(detector.currentDevice, isNull);

    // The old probe finally answers, carrying the pre-disconnect device.
    slow.complete(device('a4a5'));
    await pumpEventQueue();

    expect(detector.currentDevice, isNull, reason: 'stale result was applied');
    expect(emitted, isEmpty, reason: 'stale result reached the UI');
  });

  test(
    'a poll in flight across a restart does not block the new one',
    () async {
      detector.startMonitoring(interval: const Duration(milliseconds: 10));
      expect(detector.calls, hasLength(1));

      detector.stopMonitoring();
      detector.startMonitoring(interval: const Duration(milliseconds: 10));

      // The orphan is still unresolved, and the restart polled anyway.
      expect(detector.calls, hasLength(2));
    },
  );

  test('a poll landing after dispose writes nothing', () async {
    detector.startMonitoring(interval: const Duration(milliseconds: 10));
    final inFlight = detector.calls.first;

    detector.dispose();
    inFlight.complete(device('a4a5'));
    await pumpEventQueue();

    expect(detector.currentDevice, isNull);
    expect(emitted, isEmpty);
  });
}
