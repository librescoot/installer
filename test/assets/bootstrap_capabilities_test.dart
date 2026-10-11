import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late String validation;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('bootstrap-capabilities-');
    final template = await File('assets/trampoline.sh.template').readAsString();
    final start = template.indexOf('case "\$MODE" in flash|upgrade)');
    validation = template.substring(
      start,
      template.indexOf('WAIT_KEYCARD_UNITS=""', start),
    );
    await File('${root.path}/image.gz').writeAsString('image');
  });
  tearDown(() => root.delete(recursive: true));

  Future<ProcessResult> run({String mode = 'flash', bool ddFlags = false}) =>
      Process.run('sh', [
        '-c',
        '''
INSTALLER_DIR='${root.path}'
DBC_IMAGE="\$INSTALLER_DIR/image.gz"
DBC_MENDER=''
MODE=$mode
fail() { echo "\$*" >&2; exit 1; }
dd() { echo '${ddFlags ? 'iflag=fullblock oflag=direct' : 'Usage: dd [if=FILE] [of=FILE] [bs=N] [count=N]'}'; }
$validation
''',
      ]);

  test(
    'minimal dd cannot authorize raw-image flashing without bundled flasher',
    () async {
      final result = await run();
      expect(result.exitCode, 1);
      expect(result.stderr, contains('Bundled flasher is required'));
    },
  );

  test(
    'bundled flasher permits raw-image flashing on minimal bootstrap',
    () async {
      final flasher = File('${root.path}/librescoot-flasher');
      await flasher.writeAsString('#!/bin/sh\nexit 0\n');
      await Process.run('chmod', ['+x', flasher.path]);
      expect((await run()).exitCode, 0);
    },
  );

  test(
    'capable dd permits the fallback and upgrade needs neither flasher',
    () async {
      expect((await run(ddFlags: true)).exitCode, 0);
      expect((await run(mode: 'upgrade')).exitCode, 0);
    },
  );

  test('sparse UMS backing store needs no truncate command', () async {
    final template = await File('assets/trampoline.sh.template').readAsString();
    final line = template
        .split('\n')
        .firstWhere((line) => line.contains('seek=1073741824'));
    final command = line
        .trim()
        .replaceFirst('if ', '')
        .replaceFirst(' &&', '')
        .replaceFirst('/data/usb.drive', '${root.path}/usb.drive');
    final result = await Process.run('sh', ['-c', command]);
    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(await File('${root.path}/usb.drive').length(), 1073741824);
  });
}
