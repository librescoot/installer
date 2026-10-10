import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/flash_service.dart';

void main() {
  const raw =
      'TOTAL:196423680\n'
      'Bmap: 47955/342016 blocks mapped (14% of 1400897536 bytes), block size 4096\n'
      'PHASE:A\n'
      'PROGRESS:4194304\n'
      'VERIFY_PROGRESS:4194304\n'
      'ERROR: write at offset 29360128: write /dev/sdb: no such device\n'
      '\n'
      'Device stopped responding mid-write at 28.0 MB.\n';

  test('protocol noise is removed while the failure and explanation survive', () {
    // "14% of 1400897536 bytes" describes how much of the image has mapped
    // blocks. People read it as "it failed at 14%", which is a different
    // number entirely and sends them looking for the wrong problem.
    final out = FlashService.humanFlashErrorForTest(raw);
    expect(out, isNot(contains('14%')));
    expect(out, isNot(contains('Bmap:')));
    for (final marker in [
      'TOTAL:',
      'PHASE:',
      'PROGRESS:',
      'VERIFY_PROGRESS:',
    ]) {
      expect(out, isNot(contains(marker)));
    }
    expect(out, contains('write at offset 29360128'));
    expect(out, contains('Device stopped responding mid-write at 28.0 MB.'));
  });

  test('output with nothing but markers still says something', () {
    final out = FlashService.humanFlashErrorForTest('TOTAL:1\nPHASE:A\n');
    expect(out.trim(), isNotEmpty);
  });
}
