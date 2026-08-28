import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/flash_service.dart';

void main() {
  const local = '/local-images/librescoot-unu-mdb-minimal-'
      'nightly-20260828T122741.sdimg.gz';

  test('a bmap belonging to the image is kept', () {
    const bmap = '/local-images/librescoot-unu-mdb-minimal-'
        'nightly-20260828T122741.sdimg.bmap';
    expect(FlashService.bmapFor(local, bmap), bmap);
  });

  test('a bmap from another build is refused', () {
    // The pair that flashed a board unbootable: same recipe, different build.
    const stale = '/cache/librescoot-unu-mdb-minimal-'
        'nightly-20260828T093455.sdimg.bmap';
    expect(FlashService.bmapFor(local, stale), isNull);
  });

  test('no bmap stays no bmap', () {
    expect(FlashService.bmapFor(local, null), isNull);
  });
}
