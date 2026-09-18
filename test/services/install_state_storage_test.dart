import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/ssh_service.dart';

/// Answers the /data probe and records what the write asked the board for.
///
/// A stock board has no /data to write into, so the point of these tests is
/// what the service does *not* run afterwards.
class _ProbeSshService extends SshService {
  _ProbeSshService(this.probeAnswer, {this.probeThrows = false});

  final String probeAnswer;
  final bool probeThrows;
  final List<String> commands = [];
  final List<String> uploads = [];

  @override
  Future<String> runCommand(
    String command, {
    Duration timeout = const Duration(seconds: 60),
    bool replayOnDisconnect = false,
  }) async {
    commands.add(command);
    if (command.contains('test -d /data')) {
      if (probeThrows) throw Exception('Connection closed before reply');
      return probeAnswer;
    }
    return '';
  }

  @override
  Future<void> uploadFile(
    Uint8List content,
    String remotePath, {
    void Function(int bytesSent, int totalBytes)? onProgress,
  }) async {
    uploads.add(remotePath);
  }
}

const _runId = 'run-hmejiivqdt-7y4';

void main() {
  group('installer state is not written to a board that cannot hold it', () {
    test('a stock board with no /data is asked once and then left alone', () async {
      final ssh = _ProbeSshService('no\n');

      await ssh.writeInstallRunState(runId: _runId, content: 'x');
      await ssh.writeInstallRunState(runId: _runId, content: 'x');

      expect(ssh.commands, hasLength(1));
      expect(ssh.commands.single, contains('test -d /data'));
      expect(ssh.uploads, isEmpty);
      expect(
        ssh.commands.where((c) => c.contains('mkdir')),
        isEmpty,
        reason: 'the mkdir that fails with EPERM is what fills the log',
      );
    });

    test('a writable /data still gets the full record', () async {
      final ssh = _ProbeSshService('yes\n');

      await ssh.writeInstallRunState(
        runId: _runId,
        content: 'stage: healthCheck',
      );

      expect(ssh.commands.first, contains('test -d /data'));
      expect(
        ssh.commands[1],
        contains('mkdir -p /data/installer/history/$_runId'),
      );
      expect(ssh.uploads, ['/data/installer/history/$_runId/.record.tmp']);
      expect(ssh.commands.last, contains('/data/installer/history/$_runId/record'));
      expect(ssh.commands.last, contains('/data/installer/run-state'));
    });

    test('a probe that cannot answer falls through to the write', () async {
      final ssh = _ProbeSshService('', probeThrows: true);

      await ssh.writeInstallRunState(runId: _runId, content: 'x');

      expect(
        ssh.commands.any((c) => c.contains('mkdir')),
        isTrue,
        reason: 'an unanswered probe must not be read as "no /data"',
      );
    });

    test('an answer that is neither yes nor no fails closed', () async {
      final ssh = _ProbeSshService('sh: test: not found\n');

      await ssh.writeInstallRunState(runId: _runId, content: 'x');

      expect(ssh.commands, hasLength(1));
      expect(ssh.uploads, isEmpty);
    });

    test('an unsafe run id is refused before anything reaches the board', () async {
      final ssh = _ProbeSshService('yes\n');

      await expectLater(
        ssh.writeInstallRunState(runId: '../etc/passwd', content: 'x'),
        throwsA(isA<ArgumentError>()),
      );
      expect(ssh.commands, isEmpty);
    });
  });

  group('the /data probe only trusts an explicit yes', () {
    test('yes is the only answer that means writable', () {
      expect(SshService.parseInstallStateStorageProbe('yes\n'), isTrue);
      expect(SshService.parseInstallStateStorageProbe('no\n'), isFalse);
      expect(SshService.parseInstallStateStorageProbe(''), isFalse);
      expect(
        SshService.parseInstallStateStorageProbe('sh: test: not found\n'),
        isFalse,
      );
    });
  });
}
