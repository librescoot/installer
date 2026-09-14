import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/flash_service.dart';

void main() {
  final source = File('lib/services/flash_service.dart').readAsStringSync();
  final prep = source.substring(
    source.indexOf(
      'Future<void> _prepareLinuxTarget(String devicePath) async {',
    ),
    source.indexOf('// ---- Two-phase flash ----'),
  );

  group('releasing the target asks for as little as it can', () {
    test('the ordinary case needs no password at all', () {
      expect(prep, contains("'udisksctl'"));
      expect(
        prep,
        contains("'unmount', '-b', partition, '--no-user-interaction'"),
      );
      final plain = prep.indexOf("'umount', [");
      expect(
        plain,
        greaterThan(-1),
        reason: 'the unprivileged rung is what makes the order mean anything',
      );
      final udisks = prep.indexOf("'udisksctl'");
      final elevated = prep.indexOf('ElevationService.linuxRootPrefix()');
      expect(plain, lessThan(udisks), reason: 'cheapest first');
      expect(udisks, lessThan(elevated), reason: 'elevation is the last rung');
    });

    test('elevation happens once, not once per mount', () {
      expect(prep, contains('final stubborn = <String>[];'));
      expect(prep, contains("[...root.argv, 'sh', '-c', script]"));
      expect(prep, contains('.join('));
    });

    test('a mount point cannot carry a command into the shell', () {
      expect(prep, contains('shellQuote(t)'));
    });

    test('no way to ask is refused, not flashed over', () {
      expect(prep, contains('if (root == null) {'));
      expect(prep, contains('Refusing to flash:'));
    });

    test('the final check still gates the flash', () {
      expect(prep, contains('remains mounted at'));
    });

    test('partition and mount probes are bounded and fail closed', () {
      final source = File('lib/services/flash_service.dart').readAsStringSync();
      expect(source, contains("_runBounded('lsblk', 'lsblk'"));
      expect(source, contains("_runBounded('findmnt', 'findmnt'"));
      expect(source, contains('result == null'));
      expect(source, contains('command timed out'));
    });

    test('elevated unmount receives its askpass environment', () {
      expect(prep, contains('...Platform.environment'));
      expect(prep, contains('...root.environment'));
    });

    test('macOS refuses an unclaimed disk unless unmount succeeded', () {
      final source = File('lib/services/flash_service.dart').readAsStringSync();
      final macStart = source.indexOf("} else if (Platform.isMacOS)");
      final mac = source.substring(
        macStart,
        source.indexOf('// Linux: single pkexec elevation', macStart),
      );
      expect(mac, contains('!daClaimed && !unmountSucceeded'));
      expect(mac, contains('_macOSHasMountedVolumes(diskName)'));
      expect(mac, contains('writerMayRemain'));
    });
  });

  group('shell quoting survives what a desktop names a mount', () {
    const quote = FlashService.shellQuote;

    test('spaces and apostrophes round-trip', () async {
      for (final path in ['/media/user/BOOT', "/media/it's mine", '/mnt/a b']) {
        final r = await Process.run('sh', ['-c', 'printf %s ${quote(path)}']);
        expect(r.stdout, path, reason: path);
      }
    });

    test('a mount point cannot start a second command', () async {
      const nasty = r"/mnt/x'; echo pwned; :'";
      final r = await Process.run('sh', ['-c', 'printf %s ${quote(nasty)}']);
      expect(r.stdout, nasty);
      expect(r.stdout, isNot(contains('pwned\n')));
    });
  });
}
