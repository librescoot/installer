import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/models/board_state.dart';
import 'package:librescoot_installer/services/ssh_service.dart';

/// A finished install was reported as a rollback to the bootstrap image
/// because the probe that looks for the service stack threw, and the catch
/// returned false. "Could not ask" has to stay distinct from "no".
void main() {
  group('probe output', () {
    test('the two answers it is meant to give', () {
      expect(SshService.parseStackProbe('yes\n'), isTrue);
      expect(SshService.parseStackProbe('no\n'), isFalse);
    });

    test('shell noise before the answer does not hide it', () {
      // A login banner or a stray warning still leaves the answer last.
      expect(
        SshService.parseStackProbe('Warning: something\nyes\n'),
        isTrue,
      );
    });

    test('anything that is not an answer is unknown', () {
      for (final out in ['', '   ', '\n\n', 'Connection reset by peer']) {
        expect(SshService.parseStackProbe(out), isNull, reason: out);
      }
    });
  });

  group('bootstrap verdict', () {
    test('a stage-0 artifact name is enough on its own', () {
      expect(
        looksLikeBootstrapImage(
          artifactName: 'librescoot-unu-mdb-minimal-nightly-20260823t082958',
          hasServiceStack: true,
        ),
        isTrue,
      );
    });

    test('a release artifact with the stack present is a full image', () {
      expect(
        looksLikeBootstrapImage(
          artifactName: 'release-v1.2.1',
          hasServiceStack: true,
        ),
        isFalse,
      );
    });

    test('a release artifact with no stack is a rollback', () {
      // The case the check exists for: u-boot rolled back and the board came
      // up on stage 0 again.
      expect(
        looksLikeBootstrapImage(
          artifactName: 'release-v1.2.1',
          hasServiceStack: false,
        ),
        isTrue,
      );
    });

    test('an unanswered probe does not condemn a finished install', () {
      // What actually happened: os-release said v1.2.1, mender said
      // release-v1.2.1, and one timed-out systemctl outvoted both.
      expect(
        looksLikeBootstrapImage(
          artifactName: 'release-v1.2.1',
          hasServiceStack: null,
        ),
        isFalse,
      );
    });
  });
}
