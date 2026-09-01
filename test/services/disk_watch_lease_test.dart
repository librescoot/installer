import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/disk_arbitration_service.dart';

class _FakeHelper extends DiskArbitrationService {
  _FakeHelper({this.startSucceeds = true, this.watchSucceeds = true});

  final bool startSucceeds;
  final bool watchSucceeds;
  final calls = <String>[];
  bool _running = false;

  @override
  bool get isRunning => _running;

  @override
  Future<bool> ensureStarted() async {
    calls.add('start');
    _running = startSucceeds;
    return startSucceeds;
  }

  @override
  Future<bool> watch(int vendorId, int productId) async {
    calls.add('watch ${vendorId.toRadixString(16)}:${productId.toRadixString(16)}');
    return watchSucceeds;
  }

  @override
  Future<bool> unwatch() async {
    calls.add('unwatch');
    return true;
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
    _running = false;
  }
}

void main() {
  test('arms once and disarms once however often it is called', () async {
    final helper = _FakeHelper();
    final lease = DiskWatchLease(service: helper, isMacOS: true);

    await lease.arm(0x0525, 0xA4A5);
    await lease.arm(0x0525, 0xA4A5);
    expect(lease.isArmed, isTrue);

    await lease.disarm();
    await lease.disarm();
    expect(lease.isArmed, isFalse);

    expect(helper.calls, ['start', 'watch 525:a4a5', 'unwatch', 'stop']);
  });

  test('the helper is exposed only while it is running', () async {
    final helper = _FakeHelper();
    final lease = DiskWatchLease(service: helper, isMacOS: true);

    expect(lease.helper, isNull);
    await lease.arm(0x0525, 0xA4A5);
    expect(lease.helper, same(helper));
    await lease.disarm();
    expect(lease.helper, isNull);
  });

  // A missing helper is the ordinary state of a bundle built without the
  // Xcode phase. It must not leave the lease believing it is armed, or the
  // disarm would report a watch that was never registered.
  test('a helper that will not start leaves the lease unarmed', () async {
    final helper = _FakeHelper(startSucceeds: false);
    final lease = DiskWatchLease(service: helper, isMacOS: true);

    await lease.arm(0x0525, 0xA4A5);

    expect(lease.isArmed, isFalse);
    expect(helper.calls, ['start']);
  });

  test('a refused watch leaves the lease unarmed', () async {
    final helper = _FakeHelper(watchSucceeds: false);
    final lease = DiskWatchLease(service: helper, isMacOS: true);

    await lease.arm(0x0525, 0xA4A5);

    expect(lease.isArmed, isFalse);
    expect(helper.calls, ['start', 'watch 525:a4a5']);
  });

  test('off macOS nothing is started at all', () async {
    final helper = _FakeHelper();
    final lease = DiskWatchLease(service: helper, isMacOS: false);

    await lease.arm(0x0525, 0xA4A5);
    await lease.disarm();

    expect(lease.isArmed, isFalse);
    expect(helper.calls, isEmpty);
  });

  // Disarm is queued behind arm rather than racing it, so a phase that fails
  // the moment it starts cannot leave a watch registered with nobody holding
  // the lease.
  test('a disarm issued before arm completes still runs after it', () async {
    final helper = _FakeHelper();
    final lease = DiskWatchLease(service: helper, isMacOS: true);

    final arming = lease.arm(0x0525, 0xA4A5);
    final disarming = lease.disarm();
    await Future.wait([arming, disarming]);

    expect(lease.isArmed, isFalse);
    expect(helper.calls, ['start', 'watch 525:a4a5', 'unwatch', 'stop']);
  });

  group('claim replies', () {
    test('a granted claim counts as held', () {
      expect(DiskArbitrationService.isClaimHeld('ok'), isTrue);
    });

    // The watch normally claims the disk as it enumerates, so by the time the
    // flash path asks the claim is already ours.
    test('a claim the watch already took counts as held', () {
      expect(DiskArbitrationService.isClaimHeld('already claimed'), isTrue);
    });

    test('a failure does not', () {
      expect(DiskArbitrationService.isClaimHeld('disk not found'), isFalse);
      expect(
        DiskArbitrationService.isClaimHeld('claim failed: 0xf8da0003'),
        isFalse,
      );
      expect(DiskArbitrationService.isClaimHeld('error: timeout'), isFalse);
    });
  });
}
