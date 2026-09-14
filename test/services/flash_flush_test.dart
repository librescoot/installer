import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The restart after a flash is a power cut, not a shutdown: whatever has not
/// reached the eMMC by then is gone, and a board missing the last of its
/// bootloader comes up in its boot ROM with nothing to start.
///
/// The dd path has always ended in sync. The Go flasher path did not, so the
/// two disagreed about whether the write was durable at the moment the user is
/// told to restart the scooter. Asserted on the source because the thing that
/// would regress is the call going missing, and there is no way to observe a
/// flush from a unit test.
void main() {
  late String source;

  setUpAll(() {
    source = File('lib/services/flash_service.dart').readAsStringSync();
  });

  test('the Go flasher path flushes before it reports completion', () {
    final flush = source.indexOf('await _flushDevice(devicePath);');
    final complete = source.indexOf("onProgress?.call(1.0, 'Flash complete');");
    expect(flush, greaterThanOrEqualTo(0), reason: 'the flush is gone');
    expect(complete, greaterThan(flush),
        reason: 'the write is reported durable before it was made durable');
  });

  test('the dd path still ends in a sync of its own', () {
    // Two write paths, one promise. If either stops flushing, the promise is
    // only true on the other one and which you got depends on your CPU.
    expect(source, contains('PHASE:SYNC'));
    final dd = source.substring(
      source.indexOf("throw Exception('dd fallback failed:"),
      source.indexOf("onProgress?.call(1.0, 'dd: complete');"),
    );
    expect(dd, contains('_syncOrCarryOn()'));
  });

  test('every platform is accounted for, including the one that does nothing',
      () {
    // Windows writes to PHYSICALDRIVE without a filesystem cache and has no
    // equivalent to call here. That is a decision, and it should read as one
    // rather than as a branch somebody forgot.
    final flushBody = source.substring(source.indexOf('Future<void> _flushDevice'));
    expect(flushBody, contains('Platform.isLinux'));
    expect(flushBody, contains('Platform.isMacOS'));
    expect(flushBody, contains('no host flush needed on this platform'));
  });
}
