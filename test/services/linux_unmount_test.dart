import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/flash_service.dart';

void main() {
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
