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

    test('a board that could not answer is not a board with no stack', () {
      // systemd lists no units at all for the first minute of a boot, so the
      // script says `unknown` rather than letting an empty list read as an
      // image with nothing on it.
      expect(SshService.parseStackProbe('unknown\n'), isNull);
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

    test('a release artifact outranks a probe that found no stack', () {
      // mender names the image that is running. A board can boot its new
      // rootfs and still be starting systemd, so the probe finds no vehicle
      // unit on an image that has one, and letting that outvote the artifact
      // name reported an installed, committed, running artifact as a failed
      // install. A genuine rollback is still caught: it comes up on the old
      // VERSION_ID, which the version check after this one compares.
      expect(
        looksLikeBootstrapImage(
          artifactName: 'release-v1.2.1',
          serviceStack: ServiceStack.none,
        ),
        isFalse,
      );
    });

    test('a stage-0 artifact is bootstrap whatever the probe says', () {
      for (final stack in [
        ServiceStack.librescoot,
        ServiceStack.stock,
        ServiceStack.none,
        null,
      ]) {
        expect(
          looksLikeBootstrapImage(
            artifactName: 'librescoot-unu-mdb-minimal-nightly-20260823t082958',
            serviceStack: stack,
          ),
          isTrue,
          reason: '$stack',
        );
      }
    });

    test('with no artifact name the probe decides', () {
      // A board with no mender at all, where the stack is the only evidence.
      expect(
        looksLikeBootstrapImage(
            artifactName: null, serviceStack: ServiceStack.none),
        isTrue,
      );
      expect(
        looksLikeBootstrapImage(artifactName: '', serviceStack: null),
        isFalse,
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

    test('the stock arm matches the unit name stock actually ships', () {
      // Measured on scooterOS v1.15.0: 209 unit files, every service carrying
      // an unu- prefix, no vehicle-service and no librescoot-. The probe
      // greppped for vehicle-service alone, so it fell through to `none` and
      // a healthy stock scooter was offered a recovery re-flash.
      expect(
        SshService.stackProbeScript,
        contains('unu-vehicle'),
        reason: 'stock v1.15.0 ships unu-vehicle.service',
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
