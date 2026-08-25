import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/driver_service.dart';

void main() {
  test('a running service is stopped once and restored once', () async {
    final calls = <String>[];
    final lease = AutoPlayServiceLease(
      isWindows: true,
      runProcess: (executable, arguments) async {
        calls.add('$executable ${arguments.join(' ')}');
        if (executable == 'powershell.exe') {
          return ProcessResult(1, 0, '4\r\n', '');
        }
        return ProcessResult(1, 0, '', '');
      },
    );

    await lease.suppress();
    await lease.suppress();
    await lease.restore();
    await lease.restore();

    expect(calls.where((call) => call.contains('Get-Service')), hasLength(1));
    expect(
      calls.where((call) => call == 'net stop ShellHWDetection'),
      hasLength(1),
    );
    expect(
      calls.where((call) => call == 'net start ShellHWDetection'),
      hasLength(1),
    );
  });

  test('an initially stopped service is never started', () async {
    final calls = <String>[];
    final lease = AutoPlayServiceLease(
      isWindows: true,
      runProcess: (executable, arguments) async {
        calls.add('$executable ${arguments.join(' ')}');
        return ProcessResult(1, 0, '1\r\n', '');
      },
    );

    await lease.suppress();
    await lease.restore();

    expect(calls.where((call) => call.startsWith('net ')), isEmpty);
  });

  test('a failed restore remains retryable', () async {
    final calls = <String>[];
    var startAttempts = 0;
    final lease = AutoPlayServiceLease(
      isWindows: true,
      runProcess: (executable, arguments) async {
        final call = '$executable ${arguments.join(' ')}';
        calls.add(call);
        if (executable == 'powershell.exe') {
          return ProcessResult(1, 0, '4\r\n', '');
        }
        if (call == 'net start ShellHWDetection') {
          startAttempts++;
          return ProcessResult(1, startAttempts == 1 ? 1 : 0, '', '');
        }
        return ProcessResult(1, 0, '', '');
      },
    );

    await lease.suppress();
    await lease.restore();
    await lease.restore();

    expect(
      calls.where((call) => call == 'net start ShellHWDetection'),
      hasLength(2),
    );
  });

  test('non-Windows platforms never inspect the service', () async {
    var calls = 0;
    final lease = AutoPlayServiceLease(
      isWindows: false,
      runProcess: (_, __) async {
        calls++;
        return ProcessResult(1, 0, '', '');
      },
    );

    await lease.suppress();
    await lease.restore();

    expect(calls, 0);
  });

  test('restore requested during suppression runs after the stop', () async {
    final queryStarted = Completer<void>();
    final releaseQuery = Completer<void>();
    final calls = <String>[];
    final lease = AutoPlayServiceLease(
      isWindows: true,
      runProcess: (executable, arguments) async {
        final call = '$executable ${arguments.join(' ')}';
        calls.add(call);
        if (executable == 'powershell.exe') {
          queryStarted.complete();
          await releaseQuery.future;
          return ProcessResult(1, 0, '4\r\n', '');
        }
        return ProcessResult(1, 0, '', '');
      },
    );

    final suppress = lease.suppress();
    await queryStarted.future;
    final restore = lease.restore();
    releaseQuery.complete();
    await Future.wait([suppress, restore]);

    expect(calls.where((call) => call.startsWith('net ')).toList(), [
      'net stop ShellHWDetection',
      'net start ShellHWDetection',
    ]);
  });
}
