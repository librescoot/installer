import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/services/flash_service.dart').readAsStringSync();

  group('the helpers around the write cannot wait forever', () {
    test('nothing that touches the board runs unbounded', () {
      for (final call in [
        "Process.run('sync'",
        "Process.run('umount'",
        "Process.run('diskutil'",
        "Process.run('blockdev'",
      ]) {
        expect(source, isNot(contains(call)), reason: call);
      }
    });

    test('the bounded runner drains before it waits', () {
      final runner = source.substring(
        source.indexOf('static Future<ProcessResult?> _runBounded('),
        source.indexOf('static Future<void> _syncOrCarryOn()'),
      );
      expect(runner, contains('proc.stdout.transform'));
      expect(runner, contains('proc.stderr.transform'));
      final drain = runner.indexOf('proc.stdout.transform');
      final wait = runner.indexOf('proc.exitCode.timeout');
      expect(drain, lessThan(wait));
      expect(runner, contains('proc?.kill(ProcessSignal.sigkill)'));
    });
  });

  group('a flush and an unmount get opposite verdicts on timeout', () {
    test('a flush that will not finish is logged and stepped over', () {
      final sync = source.substring(
        source.indexOf('static Future<void> _syncOrCarryOn()'),
        source.indexOf('Future<void> _prepareLinuxTarget'),
      );
      expect(sync, contains('continuing without it'));
      expect(sync, isNot(contains('throw')));
    });

    test('an unmount that will not finish refuses the flash', () {
      final prep = source.substring(
        source.indexOf('Future<void> _prepareLinuxTarget'),
        source.indexOf('Refusing to flash: \$partition remains mounted'),
      );
      expect(prep, contains('if (elevated == null) {'));
      expect(prep, contains('Refusing to flash: unmounting'));
    });
  });

  group('the flush names the device where it can', () {
    test('the elevated script flushes the device, with a fallback', () {
      expect(source, contains(r'sync $devicePath 2>/dev/null || sync'));
    });

    test('macOS does not pretend it can scope it', () {
      final flush = source.substring(
        source.indexOf('Future<void> _flushDevice(String devicePath)'),
        source.indexOf('no host flush needed on this platform'),
      );
      final mac = flush.substring(flush.indexOf('Platform.isMacOS'));
      expect(mac, contains('_syncOrCarryOn()'));
      expect(mac, isNot(contains("'sync', [devicePath]")));
    });
  });

  group('the stall watchdog ends the wait, not just the process', () {
    final source = File('lib/services/flash_service.dart').readAsStringSync();
    final go = source.substring(
      source.indexOf('Timer? stall;'),
      source.indexOf('if (sawChecksumMismatch)'),
    );

    test('it does not depend on the kill working', () {
      expect(go, contains('final finished = Completer<void>();'));
      expect(go, contains('await finished.future;'));
      expect(go, contains('await stderrSub.cancel();'));
      expect(go, isNot(contains('await for (')));
    });

    test('the signal is attempted but not relied on', () {
      expect(go, contains('process.kill()'));
      final kill = go.substring(go.indexOf('process.kill()'));
      expect(kill.substring(0, 200), contains('endWait()'));
    });

    test('waiting for the exit code is bounded too', () {
      expect(go, contains('process.exitCode.timeout('));
    });
  });
}
