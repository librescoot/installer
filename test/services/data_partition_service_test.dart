import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/data_partition_service.dart';

void main() {
  group('MDB data partition probe', () {
    test('requires the expected device, filesystem, and a distinct root', () {
      expect(mdbDataPartitionProbeCommand, contains('/dev/mmcblk1p4'));
      expect(mdbDataPartitionProbeCommand, contains('data != root'));
      expect(mdbDataPartitionProbeCommand, contains('type == "ext4"'));
    });

    test('parses a ready partition', () {
      final probe = parseDataPartitionProbe(
        'ready root=/dev/mmcblk1p2 data=/dev/mmcblk1p4 type=ext4\n',
      );
      expect(probe.status, DataPartitionProbeStatus.ready);
    });

    test('parses an absent mount', () {
      final probe = parseDataPartitionProbe('absent root=/dev/mmcblk1p2\n');
      expect(probe.status, DataPartitionProbeStatus.absent);
    });

    test('parses a wrong filesystem', () {
      final probe = parseDataPartitionProbe(
        'wrong root=/dev/mmcblk1p2 data=/dev/mmcblk1p3 type=ext4\n',
      );
      expect(probe.status, DataPartitionProbeStatus.wrong);
      expect(probe.diagnostic, contains('/dev/mmcblk1p3'));
    });
  });

  group('waitForMdbDataPartition', () {
    test('throws with diagnostics when the mount stays absent', () async {
      await expectLater(
        waitForMdbDataPartition(
          runCommand: (command, timeout) async => 'absent root=/dev/mmcblk1p2',
          maxAttempts: 1,
        ),
        throwsA(
          isA<DataPartitionWaitException>().having(
            (error) => error.toString(),
            'message',
            contains('absent root=/dev/mmcblk1p2'),
          ),
        ),
      );
    });

    test('accepts a partition that mounts late', () async {
      var attempt = 0;
      var delays = 0;
      final result = await waitForMdbDataPartition(
        runCommand: (command, timeout) async => attempt++ == 0
            ? 'absent root=/dev/mmcblk1p2'
            : 'ready root=/dev/mmcblk1p2 data=/dev/mmcblk1p4 type=ext4',
        maxAttempts: 2,
        delay: (duration) async => delays++,
      );

      expect(result, DataPartitionWaitResult.ready);
      expect(delays, 1);
    });

    test('rejects a mounted wrong filesystem', () async {
      await expectLater(
        waitForMdbDataPartition(
          runCommand: (command, timeout) async =>
              'wrong root=/dev/mmcblk1p2 data=tmpfs type=tmpfs',
          maxAttempts: 1,
        ),
        throwsA(
          isA<DataPartitionWaitException>().having(
            (error) => error.toString(),
            'message',
            contains('data=tmpfs type=tmpfs'),
          ),
        ),
      );
    });

    test('an unreachable board is not reported as a bad filesystem', () async {
      // The wait that ends because SSH died never read /proc/mounts, so it
      // has no verdict about /data to give. Claiming one sends whoever reads
      // the log to repartition a board whose only problem is the link.
      await expectLater(
        waitForMdbDataPartition(
          runCommand: (command, timeout) async =>
              throw Exception('SSH session lost before command'),
          maxAttempts: 1,
        ),
        throwsA(
          isA<DataPartitionWaitException>().having(
            (error) => error.toString(),
            'message',
            allOf(
              contains('stopped answering'),
              contains('SSH session lost before command'),
              isNot(contains('did not mount as ext4')),
            ),
          ),
        ),
      );
    });

    test('passes the probe timeout to the command runner', () async {
      Duration? seenTimeout;
      await expectLater(
        waitForMdbDataPartition(
          runCommand: (command, timeout) async {
            seenTimeout = timeout;
            return 'absent root=/dev/mmcblk1p2';
          },
          maxAttempts: 1,
          probeTimeout: const Duration(seconds: 3),
        ),
        throwsA(isA<DataPartitionWaitException>()),
      );
      expect(seenTimeout, const Duration(seconds: 3));
    });

    test('rejects a zero probe timeout', () async {
      await expectLater(
        waitForMdbDataPartition(
          runCommand: (command, timeout) async => 'ready',
          probeTimeout: Duration.zero,
        ),
        throwsArgumentError,
      );
    });

    test('cancels without throwing when the screen is disposed', () async {
      final result = await waitForMdbDataPartition(
        runCommand: (command, timeout) async =>
            fail('must not probe after disposal'),
        isCancelled: () => true,
      );

      expect(result, DataPartitionWaitResult.cancelled);
    });
  });
}
