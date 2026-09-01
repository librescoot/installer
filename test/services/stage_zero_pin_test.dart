import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/download_service.dart';

/// The stage-0 image is what the installer writes before it installs an
/// artifact, and it has to carry what the installer needs while it runs. Taking
/// it from the target release tied the installer's own features to whichever
/// firmware the user picked: installing stable 1.2.1 wrote a stage-0 with no
/// redis at all, so everything redis-backed was dead for that window.
///
/// The pin only ever replaces stage-0 images. Artifacts must keep coming from
/// the release the user chose, or the installer would quietly install the
/// wrong firmware.
void main() {
  bool stageZero(String name) => DownloadService.isStageZeroForTest(name);

  test('stage-0 images are the pinned ones', () {
    expect(stageZero('librescoot-unu-mdb-minimal-v1.2.1.sdimg.gz'), isTrue);
    expect(stageZero('librescoot-unu-mdb-minimal-v1.2.1.sdimg.bmap'), isTrue);
    expect(
        stageZero('librescoot-unu-dbc-minimal-nightly-20260823t021701.sdimg.gz'),
        isTrue);
  });

  test('artifacts are never taken from the pin', () {
    // The whole point of choosing a channel. A pinned artifact would install
    // a version the user did not ask for.
    expect(stageZero('librescoot-unu-mdb-v1.2.1.mender'), isFalse);
    expect(stageZero('librescoot-unu-dbc-nightly-20260823t021701.mender'),
        isFalse);
  });

  test('the full image is not a stage-0 image', () {
    // The fall-back path writes the full sdimg rather than stage 0, and that
    // one has to match the version being installed.
    expect(stageZero('librescoot-unu-mdb-v1.2.1.sdimg.gz'), isFalse);
    expect(stageZero('librescoot-unu-mdb-v1.2.1.sdimg.bmap'), isFalse);
  });

  test('unrelated assets are left alone', () {
    for (final name in [
      'librescoot-unu-mdb-minimal-v1.2.1.delta',
      'librescoot-unu-mdb-boot-v1.2.1.tar.gz',
      'checksums.txt',
      '',
    ]) {
      expect(stageZero(name), isFalse, reason: name);
    }
  });
}
