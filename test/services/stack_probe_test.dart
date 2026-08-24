import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/models/board_state.dart';
import 'package:librescoot_installer/services/ssh_service.dart';

/// A finished install was reported as a rollback to the bootstrap image
/// because the probe that looks for the service stack threw, and the catch
/// returned false. "Could not ask" has to stay distinct from "no".
void main() {
  group('probe output', () {
    test('the three answers it is meant to give', () {
      expect(
        SshService.parseStackProbe('librescoot\n'),
        ServiceStack.librescoot,
      );
      expect(SshService.parseStackProbe('stock\n'), ServiceStack.stock);
      expect(SshService.parseStackProbe('none\n'), ServiceStack.none);
    });

    test('shell noise before the answer does not hide it', () {
      // A login banner or a stray warning still leaves the answer last.
      expect(
        SshService.parseStackProbe('Warning: something\nlibrescoot\n'),
        ServiceStack.librescoot,
      );
    });

    test('anything that is not an answer is unknown', () {
      for (final out in ['', '   ', '\n\n', 'Connection reset by peer', 'yes']) {
        expect(SshService.parseStackProbe(out), isNull, reason: out);
      }
    });
  });

  group('bootstrap verdict', () {
    test('a stage-0 artifact name is enough on its own', () {
      expect(
        looksLikeBootstrapImage(
          artifactName: 'librescoot-unu-mdb-minimal-nightly-20260823t082958',
          serviceStack: ServiceStack.librescoot,
        ),
        isTrue,
      );
    });

    test('a release artifact with the stack present is a full image', () {
      expect(
        looksLikeBootstrapImage(
          artifactName: 'release-v1.2.1',
          serviceStack: ServiceStack.librescoot,
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
          serviceStack: ServiceStack.none,
        ),
        isTrue,
      );
    });

    test('an unanswered probe does not condemn a finished install', () {
      expect(
        looksLikeBootstrapImage(
          artifactName: 'release-v1.2.1',
          serviceStack: null,
        ),
        isFalse,
      );
    });

    test('a healthy stock board is not a bootstrap image', () {
      // Stock has a working vehicle stack under its own unit names and no
      // mender artifact at all. Reading that as a damaged Librescoot install
      // told the user to re-flash a scooter with nothing wrong with it.
      expect(
        looksLikeBootstrapImage(
          artifactName: null,
          serviceStack: ServiceStack.stock,
        ),
        isFalse,
      );
    });
  });
}
