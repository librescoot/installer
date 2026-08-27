import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/ssh_service.dart';

/// The coordinator is the only installer file outside /data/installer, and the
/// only one that runs with nobody watching. What it does with the directory it
/// finds is the whole of the post-reboot contract.
void main() {
  late Directory root;
  late Directory scripts;

  /// The shim addresses /data directly, which is right on a scooter and
  /// unusable here.
  String rehomed() =>
      SshService.onbootShim.replaceAll('/data/', '${root.path}/');

  Future<void> phase(String name, String body) async {
    final f = File('${scripts.path}/$name');
    await f.writeAsString('#!/bin/sh\n$body\n');
  }

  Future<ProcessResult> boot() async {
    final f = File('${root.path}/onboot.sh');
    await f.writeAsString(rehomed());
    return Process.run('sh', [f.path]);
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('onboot-shim-');
    scripts = Directory('${root.path}/installer/scripts');
    await scripts.create(recursive: true);
  });
  tearDown(() => root.delete(recursive: true));

  test('it is valid shell', () async {
    final f = File('${root.path}/shim.sh');
    await f.writeAsString(SshService.onbootShim);
    final syntax = await Process.run('sh', ['-n', f.path]);
    expect(syntax.exitCode, 0, reason: syntax.stderr.toString());
  });

  test('it runs the numbered phases in order', () async {
    final order = '${root.path}/order';
    await phase('30-cleanup.sh', 'echo 30 >> $order; rm -f "\$0"');
    await phase('20-dbc.sh', 'echo 20 >> $order; rm -f "\$0"');
    final result = await boot();
    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(await File(order).readAsLines(), ['20', '30']);
  });

  test('it leaves an unnumbered script alone', () async {
    // The first phase is launched by the laptop and carries a DBC flash. A
    // board that died in the middle of one must not come back and re-flash a
    // dashboard with nobody watching.
    final ran = '${root.path}/ran';
    await phase('trampoline.sh', 'echo yes >> $ran');
    await phase('20-dbc.sh', 'rm -f "\$0"');
    await boot();
    expect(File(ran).existsSync(), isFalse);
    expect(File('${scripts.path}/trampoline.sh').existsSync(), isTrue,
        reason: 'and it is not deleted either');
  });

  test('a phase can abandon the run by deleting the ones after it', () async {
    // What an emergency reboot does. The coordinator has no abort case; it
    // just finds fewer phases than the glob captured.
    final order = '${root.path}/order';
    await phase('00-rescue.sh',
        'echo rescue >> $order; rm -f ${scripts.path}/30-cleanup.sh "\$0"');
    await phase('30-cleanup.sh', 'echo cleanup >> $order; rm -f "\$0"');
    final result = await boot();
    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(await File(order).readAsLines(), ['rescue']);
  });

  test('a phase that keeps failing is dropped after three attempts', () async {
    final tally = '${root.path}/tally';
    await phase('20-dbc.sh', 'echo run >> $tally; exit 1');
    for (var i = 0; i < 5; i++) {
      await boot();
    }
    expect((await File(tally).readAsLines()).length, 3,
        reason: 'three attempts, then the phase is given up on');
    expect(File('${scripts.path}/20-dbc.sh').existsSync(), isFalse);
  });

  test('the attempt is counted before it is made', () async {
    // A phase that wedges the boot never reaches its own end. Counting
    // afterwards counts the runs that already worked and retries forever the
    // ones that did not.
    await phase('20-dbc.sh', 'exit 0');
    await boot();
    final tries = File('${scripts.path}/20-dbc.sh.tries');
    expect(tries.existsSync(), isTrue);
    expect((await tries.readAsString()).trim(), '1');
  });

  test('it removes itself once no phases are left', () async {
    await phase('20-dbc.sh', 'rm -f "\$0"');
    await boot();
    expect(File('${root.path}/onboot.sh').existsSync(), isFalse);
  });

  test('it stays while a phase is still queued', () async {
    await phase('20-dbc.sh', 'rm -f "\$0"');
    await phase('30-cleanup.sh', 'exit 0');
    await boot();
    expect(File('${root.path}/onboot.sh').existsSync(), isTrue,
        reason: 'the cleanup still has to run on a later boot');
  });

  test('it gives a displaced onboot.sh back when it retires', () async {
    final backup = File('${root.path}/installer/onboot.sh.bak');
    await backup.writeAsString('#!/bin/sh\n# the user had their own\n');
    await phase('20-dbc.sh', 'rm -f "\$0"');
    await boot();
    final restored = File('${root.path}/onboot.sh');
    expect(restored.existsSync(), isTrue);
    expect(await restored.readAsString(), contains('the user had their own'));
    expect(backup.existsSync(), isFalse);
  });

  test('an empty scripts directory retires it rather than looping', () async {
    // The glob matches nothing and must not be run as a literal filename.
    final result = await boot();
    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(File('${root.path}/onboot.sh').existsSync(), isFalse);
  });
}
