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
          runCommand: (command) async => 'absent root=/dev/mmcblk1p2',
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
        runCommand: (command) async => attempt++ == 0
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
          runCommand: (command) async =>
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

    test('cancels without throwing when the screen is disposed', () async {
      final result = await waitForMdbDataPartition(
        runCommand: (command) async => fail('must not probe after disposal'),
        isCancelled: () => true,
      );

      expect(result, DataPartitionWaitResult.cancelled);
    });
  });
}
