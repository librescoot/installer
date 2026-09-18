import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/usb_detector.dart';

void main() {
  group('USB probes cannot pile up behind a device that stopped answering', () {
    final source = File('lib/services/usb_detector.dart').readAsStringSync();

    test('nothing runs a process unbounded', () {
      expect(source, isNot(contains('await Process.run(')));
      expect(source, isNot(contains('detectDevice().timeout(')));
      expect(
        RegExp(r'await runBounded\(').allMatches(source).length,
        greaterThanOrEqualTo(12),
      );
    });

    test('a missing binary still throws, so the fallback can try the next', () {
      final runner = source.substring(
        source.indexOf('Future<ProcessResult> runBounded('),
        source.indexOf(
          'class ',
          source.indexOf('Future<ProcessResult> runBounded('),
        ),
      );
      expect(runner, contains('on TimeoutException'));
      expect(runner, isNot(contains('catch (_)')));
      expect(runner, contains('proc?.kill(ProcessSignal.sigkill)'));
    });

    test(
      'a probe that will not return is killed and reads as failed',
      () async {
        final started = DateTime.now();
        final r = await runBounded('sh', [
          '-c',
          'sleep 30',
        ], timeout: const Duration(milliseconds: 200));
        expect(r.exitCode, -1);
        expect(r.stderr, 'timed out');
        expect(
          DateTime.now().difference(started),
          lessThan(const Duration(seconds: 5)),
          reason: 'it gave up on the child rather than waiting for it',
        );
      },
    );

    test(
      'a missing binary throws rather than coming back as a failure',
      () async {
        await expectLater(
          runBounded('definitely-not-a-real-binary-xyz', const []),
          throwsA(isA<ProcessException>()),
        );
      },
    );

    test('a child that exits on its own is reported as it exited', () async {
      final r = await runBounded('sh', ['-c', 'echo out; exit 7']);
      expect(r.exitCode, 7);
      expect(r.stdout.toString().trim(), 'out');
    });

    test('environment variables reach the child', () async {
      final r = await runBounded(
        'sh',
        ['-c', r'printf %s "$BOUNDED_TEST"'],
        environment: const {'BOUNDED_TEST': 'present'},
      );
      expect(r.exitCode, 0);
      expect(r.stdout, 'present');
    });
  });

  group('a slow machine is not a missing device', () {
    test('a probe that takes 11 s is answered, not killed', () async {
      // The field measurement this pins: a Windows 11 machine answered a
      // `Get-PnpDevice`/`Get-PnpDeviceProperty` probe in about 12 s. The old
      // 10 s default killed it, and a killed probe reads as an absent device,
      // so the installer reported the board disconnected while it was sitting
      // in U-Boot mass-storage mode waiting to be flashed.
      final started = DateTime.now();
      final r = await runBounded('sh', ['-c', 'sleep 11; echo slow-but-alive']);
      expect(r.exitCode, 0, reason: r.stderr.toString());
      expect(r.stdout.toString().trim(), 'slow-but-alive');
      expect(DateTime.now().difference(started), greaterThan(const Duration(seconds: 10)));
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  group('detection waits on rounds, not on every probe in turn', () {
    final source = File('lib/services/usb_detector.dart').readAsStringSync();

    String detect() => source.substring(
      source.indexOf('Future<UsbDevice?> _detectWindows() async {'),
      source.indexOf('Future<UsbDevice?> _detectWindowsEthernet()'),
    );

    test('each round is in flight together', () {
      final body = detect();
      expect(RegExp(r'await Future\.wait\(\[').allMatches(body).length, 2);
      expect(
        body,
        isNot(contains('await _detectWindowsEthernet();')),
        reason: 'sequentially awaited probes are round trips added together',
      );
    });

    test('precedence is the order of the checks, not who answers first', () {
      final body = detect();
      final order = [
        '_detectWindowsEthernet()',
        '_detectWindowsStorage()',
        '_detectWindowsPnpEthernet()',
        '_detectWindowsRecovery()',
      ].map(body.indexOf).toList();
      expect(order, orderedEquals([...order]..sort()));
      expect(order.every((i) => i >= 0), isTrue);
    });

    test('the storage probe starts both of its queries together', () {
      final body = source.substring(
        source.indexOf('if (pnpId.isNotEmpty) {'),
        source.indexOf('sizeBytes: sizeBytes,'),
      );
      final firstAwait = body.indexOf('await ');
      expect(body.indexOf('_windowsDiskSize('), lessThan(firstAwait));
      expect(body.indexOf('_windowsSystemDiskVerdict('), lessThan(firstAwait));
    });
  });

  group('AutoPlay suppression waits like the best-effort thing it is', () {
    final source = File('lib/services/driver_service.dart').readAsStringSync();

    test('net gets a bound', () {
      expect(source, contains('_netCommandTimeout = Duration(seconds: 10)'));
      final runner = source.substring(
        source.indexOf('static Future<ProcessResult> _defaultRunProcess('),
      );
      expect(runner.substring(0, 900), contains('exitCode.timeout('));
      expect(runner.substring(0, 900), contains('proc?.kill()'));
    });
  });

  group('an upload that runs out of time takes its writer with it', () {
    final source = File('lib/services/ssh_service.dart').readAsStringSync();

    test('the bound is inside the upload, not wrapped around it', () {
      final upload = source.substring(
        source.indexOf('Future<void> uploadFile('),
        source.indexOf('Future<void> _uploadViaSftp('),
      );
      expect(upload, isNot(contains('.timeout(timeout)')));
      expect(
        upload,
        contains('_uploadViaSftp(content, remotePath, onProgress, timeout)'),
      );
      expect(upload, contains('_uploadViaCat(content, remotePath, timeout)'));
    });

    test('the cat path unwinds the way runStreaming does', () {
      final cat = source.substring(
        source.indexOf('Future<void> _uploadViaCat('),
        source.indexOf('/// Upload fw_setenv'),
      );
      expect(cat, contains('session.kill(SSHSignal.TERM)'));
      expect(cat, contains('unawaited(stdoutDone.catchError((_) {}))'));
    });

    test('the sftp path bounds its write and its close', () {
      final sftp = source.substring(
        source.indexOf('Future<void> _uploadViaSftp('),
        source.indexOf('Future<void> _uploadViaCat('),
      );
      expect(sftp, contains('writer.done.timeout(timeout)'));
      expect(sftp, contains('file.close().timeout(channelOpenTimeout)'));
      expect(sftp, contains('_invalidateClient(client)'));
    });

    test('a timed out SFTP writer cannot be followed by a second writer', () {
      final upload = source.substring(
        source.indexOf('Future<void> uploadFile('),
        source.indexOf('Future<void> _uploadViaSftp('),
      );
      expect(upload, contains('_ensureConnected(\'upload fallback\')'));
      expect(
        source,
        contains('final client = _requireClient(\'SFTP upload\')'),
      );
      expect(source, contains('expected: client'));
    });

    test('closing a subscription stream cannot park the teardown', () {
      final stop = source.substring(
        source.indexOf('Future<void> stop() async {'),
        source.indexOf('return (events: controller.stream, stop: stop);'),
      );
      expect(stop, contains('unawaited(controller.close())'));
    });
  });
}
