import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/models/board_state.dart';
import 'package:librescoot_installer/services/artifact_service.dart';

void main() {
  group('MenderOutputParser', () {
    late List<int> progress;
    late List<String> lines;
    late MenderOutputParser parser;

    setUp(() {
      progress = [];
      lines = [];
      parser = MenderOutputParser(
        onProgress: progress.add,
        onLine: lines.add,
      );
    });

    test('reads the carriage-return percentage form', () {
      parser.add('\r0%\r13%\r100%');
      parser.flush();
      expect(progress, [0, 13, 100]);
      expect(lines, isEmpty);
    });

    test('keeps a percentage split across two chunks', () {
      parser.add('\r4');
      parser.add('2%\r');
      parser.flush();
      expect(progress, [42]);
    });

    test('passes real messages through as lines', () {
      parser.add('Installing artifact...\n\r50%\n');
      parser.add('failed to open device\n');
      parser.flush();
      expect(progress, [50]);
      expect(lines, ['Installing artifact...', 'failed to open device']);
    });

    test('does not mistake a percentage in prose for progress', () {
      parser.add('device is 90% full\n');
      parser.flush();
      expect(progress, isEmpty);
      expect(lines, ['device is 90% full']);
    });

    test('rejects out-of-range numbers', () {
      parser.add('\r150%\n');
      parser.flush();
      expect(progress, isEmpty);
      expect(lines, ['150%']);
    });

    test('flush emits a trailing unterminated line', () {
      parser.add('no newline here');
      expect(lines, isEmpty);
      parser.flush();
      expect(lines, ['no newline here']);
    });
  });

  group('artifactSeedPath', () {
    test('is the path the OTA seed uses, per board', () {
      expect(
        artifactSeedPath(Board.mdb, 'librescoot-unu-mdb-v1.2.1.mender'),
        '/data/ota/mdb/librescoot-unu-mdb-v1.2.1.mender',
      );
      expect(
        artifactSeedPath(Board.dbc, 'librescoot-unu-dbc-v1.2.1.mender'),
        '/data/ota/dbc/librescoot-unu-dbc-v1.2.1.mender',
      );
    });
  });

  group('menderConsumedByBootstrap', () {
    test('spots the run mender spent on its own bootstrap Artifact', () {
      // Verbatim from a board flashed minutes earlier, whose datastore was
      // empty. Exit status was 0 and progress ran to 100%, so this line is
      // the only thing separating it from a real install.
      const output =
          'record_id=1 severity=info time="2026-Aug-21 12:57:38.172291" '
          'name="Global" msg="Installing the bootstrap Artifact"\n'
          'Update Module output (stdout): Blocks written:         12';
      expect(menderConsumedByBootstrap(output), isTrue);
    });

    test('a real install is not mistaken for one', () {
      const output =
          'Installing artifact...\n'
          'Update Module output (stdout): Blocks written:          3\n'
          'Installed, but not committed.\n'
          'At least one payload requested a reboot of the device it updated.';
      expect(menderConsumedByBootstrap(output), isFalse);
    });

    test('empty output is not a bootstrap run', () {
      expect(menderConsumedByBootstrap(''), isFalse);
    });
  });

  group('ArtifactPreflight', () {
    test('is ok with mender and room to spare', () {
      const p = ArtifactPreflight(
          hasMender: true, freeBytes: 500 * 1024 * 1024, requiredBytes: 163 * 1024 * 1024);
      expect(p.ok, isTrue);
      expect(p.problem, isNull);
    });

    test('fails without a mender client', () {
      const p = ArtifactPreflight(
          hasMender: false, freeBytes: 500 * 1024 * 1024, requiredBytes: 1);
      expect(p.ok, isFalse);
      expect(p.problem, ArtifactPreflightProblem.noMender);
    });

    test('fails when the artifact plus margin does not fit', () {
      const p = ArtifactPreflight(
          hasMender: true, freeBytes: 170 * 1024 * 1024, requiredBytes: 163 * 1024 * 1024);
      expect(p.ok, isFalse, reason: '64 MiB of margin is required on top');
      expect(p.problem, ArtifactPreflightProblem.notEnoughSpace);
      expect(p.freeMiB, 170);
      expect(p.neededMiB, 163 + 64);
    });

    test('passes when free space is unknown rather than blocking the install', () {
      const p = ArtifactPreflight(hasMender: true, freeBytes: null, requiredBytes: 1);
      expect(p.ok, isTrue);
    });

    test('a retry succeeds once the artifact is fully staged, even though '
        'free space alone would fail', () {
      const artifactBytes = 163 * 1024 * 1024;
      const p = ArtifactPreflight(
        hasMender: true,
        freeBytes: 100 * 1024 * 1024,
        requiredBytes: artifactBytes,
        existingBytes: artifactBytes,
      );
      expect(p.ok, isTrue,
          reason: 'the staged copy already accounts for its own size; '
              'only the margin is new demand');
    });

    test('a partial file only counts its shortfall against free space', () {
      const p = ArtifactPreflight(
        hasMender: true,
        freeBytes: 150 * 1024 * 1024,
        requiredBytes: 163 * 1024 * 1024,
        existingBytes: 100 * 1024 * 1024,
      );
      expect(p.ok, isTrue,
          reason: '63 MiB shortfall + 64 MiB margin = 127 MiB, '
              'under the 150 MiB free (the full 163 + 64 = 227 MiB would not be)');
    });

    test('refuses while the board is running its own OTA', () {
      for (final status in [
        'downloading',
        'preparing',
        'installing',
        'pending-reboot',
      ]) {
        final probe = ArtifactPreflight(
          hasMender: true,
          freeBytes: 4 * 1024 * 1024 * 1024,
          requiredBytes: 160 * 1024 * 1024,
          otaStatus: status,
        );
        expect(probe.problem, ArtifactPreflightProblem.otaInProgress,
            reason: '$status is mid-update');
      }
    });

    test('an idle or failed OTA is not in the way', () {
      for (final status in ['idle', 'error', 'ERROR', '']) {
        final probe = ArtifactPreflight(
          hasMender: true,
          freeBytes: 4 * 1024 * 1024 * 1024,
          requiredBytes: 160 * 1024 * 1024,
          otaStatus: status,
        );
        expect(probe.ok, isTrue, reason: 'status "$status" must not block');
      }
    });

    test('an unreadable ota hash does not block the install', () {
      // A stage-0 image has no redis and no update service at all.
      const probe = ArtifactPreflight(
        hasMender: true,
        freeBytes: 4 * 1024 * 1024 * 1024,
        requiredBytes: 160 * 1024 * 1024,
      );
      expect(probe.otaStatus, isNull);
      expect(probe.ok, isTrue);
    });

    test('a missing mender client still outranks a busy OTA', () {
      const probe = ArtifactPreflight(
        hasMender: false,
        freeBytes: 4 * 1024 * 1024 * 1024,
        requiredBytes: 160 * 1024 * 1024,
        otaStatus: 'installing',
      );
      expect(probe.problem, ArtifactPreflightProblem.noMender);
    });
  });
}
