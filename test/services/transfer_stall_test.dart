import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('a transfer that stops moving is abandoned, not waited on', () {
    final source = File(
      'lib/services/trampoline_service.dart',
    ).readAsStringSync();
    final upload = source.substring(
      source.indexOf('Future<void> _uploadViaHttp('),
      source.indexOf('/// Upload one local file to [remotePath]'),
    );

    test('each chunk flush is bounded', () {
      expect(upload, contains('socket.flush().timeout(_uploadStallTimeout)'));
    });

    test('the bound is on silence, not on the length of the transfer', () {
      expect(source, contains('_uploadStallTimeout = Duration(seconds: 60)'));
    });

    test('connecting and reading the response are bounded too', () {
      expect(upload, contains('timeout: _uploadConnectTimeout'));
      final foldAt = upload.indexOf('.fold<List<int>>');
      expect(foldAt, greaterThan(-1), reason: 'the response read moved');
      final read = upload.substring(foldAt);
      expect(read.substring(0, read.indexOf(';')), contains('.timeout('));
    });

    test('the socket is destroyed rather than drained on the way out', () {
      expect(upload, contains('socket.destroy();'));
      expect(upload, isNot(contains('await socket.close()')));
    });

    test('the readiness probe has a deadline, not an attempt count', () {
      final probe = source.substring(
        source.indexOf('waiting for upload server'),
        source.indexOf(
          '_pythonServerStarted = true;',
          source.indexOf('waiting for upload server'),
        ),
      );
      expect(probe, contains('DateTime.now().isBefore(deadline)'));
      final getUrl = probe.substring(probe.indexOf('.getUrl('));
      expect(getUrl.substring(0, getUrl.indexOf(';')), contains('.timeout('));
      expect(source, isNot(contains('await resp.drain<void>();')));
    });
  });

  group('a flash that stops reporting is killed, not waited on', () {
    final source = File('lib/services/flash_service.dart').readAsStringSync();
    final go = source.substring(
      source.indexOf('final output = StringBuffer();'),
      source.indexOf('if (sawChecksumMismatch)'),
    );
    final macDd = source.substring(
      source.indexOf('Future<void> _writeMacOSDdFallback('),
      source.indexOf('String? _flasherBinaryName()'),
    );
    final linuxDd = source.substring(
      source.indexOf('Future<void> _writeTwoPhaseLinux('),
      source.lastIndexOf('\n}'),
    );

    test('stdout is drained, as the dd fallback already does', () {
      expect(go, contains('process.stdout.listen((_) {});'));
      expect(
        'process.stdout.listen((_) {});'.allMatches(source).length,
        2,
        reason: 'both the Go flasher and the dd fallback must drain stdout',
      );
    });

    test('silence past the bound kills the flasher and reports it', () {
      expect(go, contains('Timer(_flashStallTimeout'));
      expect(go, contains('process.kill()'));
      expect(source, contains('if (stalled) {'));
      expect(source, contains('write must not be retried'));
    });

    test('the watchdog is reset by output and cancelled on the way out', () {
      expect(go, contains('resetStall();'));
      expect(go, contains('resetStall();\n    try {'));
      expect(go, contains('stall?.cancel();'));
      expect(go, contains('FlashStalledException'));
    });

    test('both dd fallbacks have the same stalled-writer verdict', () {
      for (final fallback in [macDd, linuxDd]) {
        expect(fallback, contains('Timer(_flashStallTimeout'));
        expect(fallback, contains('process.kill(ProcessSignal.sigkill)'));
        expect(fallback, contains('FlashStalledException'));
      }
    });

    test('a stalled privileged writer has no retry path', () {
      final screen = File(
        'lib/screens/installer_screen.dart',
      ).readAsStringSync();
      final flash = screen.substring(
        screen.indexOf('Future<void> _flashMdb()'),
        screen.indexOf('Future<bool> _waitForMassStorageDevice'),
      );
      expect(flash, contains('if (e is FlashStalledException)'));
      expect(flash, contains('ownershipUncertain: true'));
      final panel = screen.substring(
        screen.indexOf('if (!_mdbFlashOwnershipUncertain)'),
        screen.indexOf('/// Ask the user to confirm the target'),
      );
      expect(panel, contains('if (!_mdbFlashOwnershipUncertain)'));
      expect(
        screen,
        contains(
          'if (!_mdbFlashOwnershipUncertain) DriverService.restoreAutoPlay',
        ),
      );
      expect(
        screen,
        contains(
          'if (!_mdbFlashOwnershipUncertain) DiskArbitrationService.disarmWatch',
        ),
      );
    });
  });
}
