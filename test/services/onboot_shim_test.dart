import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/ssh_service.dart';

/// The coordinator is the only installer file outside /data/installer, and the
/// only one that runs with nobody watching. What it does with the directory it
/// finds is the whole of the post-reboot contract.
void main() {
  group('explicit retirement', retirementTests);
  group('installing it', installTests);
  group('what a run leaves behind', historyTests);

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

/// Retirement asked for explicitly, at the end of a run, rather than left to
/// the coordinator noticing on some later boot. The sweep that follows a
/// finish deletes the directory a displaced onboot.sh is saved in, so a run
/// that installed the coordinator and never queued a phase would take the
/// user's script with it.
void retirementTests() {
  late Directory root;
  late Directory scripts;

  String rehomed(String script) => script.replaceAll('/data/', '${root.path}/');

  Future<ProcessResult> retire() async {
    final f = File('${root.path}/retire.sh');
    await f.writeAsString(rehomed(SshService.onbootRetireCommand));
    return Process.run('sh', [f.path]);
  }

  Future<void> installShim() async {
    await File('${root.path}/onboot.sh').writeAsString(SshService.onbootShim);
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('onboot-retire-');
    scripts = Directory('${root.path}/installer/scripts');
    await scripts.create(recursive: true);
  });
  tearDown(() => root.delete(recursive: true));

  test('it hands back a displaced onboot.sh', () async {
    await installShim();
    final backup = File('${root.path}/installer/onboot.sh.bak');
    await backup.writeAsString('#!/bin/sh\n# the user had their own\n');
    final result = await retire();
    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(await File('${root.path}/onboot.sh').readAsString(),
        contains('the user had their own'));
    expect(backup.existsSync(), isFalse);
  });

  test('it declines while a phase is still queued', () async {
    await installShim();
    await File('${scripts.path}/30-cleanup.sh').writeAsString('#!/bin/sh\n');
    final result = await retire();
    expect(result.exitCode, 0);
    expect(File('${root.path}/onboot.sh').existsSync(), isTrue,
        reason: 'the queued phase still needs the coordinator to run it');
  });

  test('it leaves a script that is not ours alone', () async {
    final theirs = File('${root.path}/onboot.sh');
    await theirs.writeAsString('#!/bin/sh\n# somebody else entirely\n');
    final result = await retire();
    expect(result.exitCode, 0);
    expect(await theirs.readAsString(), contains('somebody else entirely'));
  });
}

/// What the coordinator displaces, and what it must not.
void installTests() {
  late Directory root;

  Future<ProcessResult> install() async {
    final f = File('${root.path}/install.sh');
    await f.writeAsString(
        SshService.onbootInstallCommand.replaceAll('/data/', '${root.path}/'));
    return Process.run('sh', [f.path]);
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('onboot-install-');
    await Directory('${root.path}/installer').create(recursive: true);
  });
  tearDown(() => root.delete(recursive: true));

  test('it saves a script that belongs to somebody else', () async {
    await File('${root.path}/onboot.sh')
        .writeAsString('#!/bin/sh\n# the user had their own\n');
    final result = await install();
    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(await File('${root.path}/installer/onboot.sh.bak').readAsString(),
        contains('the user had their own'));
    expect(await File('${root.path}/onboot.sh').readAsString(),
        contains('Installed by the Librescoot installer'));
  });

  test('it does not save its own shim over the saved script', () async {
    final backup = File('${root.path}/installer/onboot.sh.bak');
    await backup.writeAsString('#!/bin/sh\n# the user had their own\n');
    await File('${root.path}/onboot.sh').writeAsString(SshService.onbootShim);
    final result = await install();
    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(await backup.readAsString(), contains('the user had their own'),
        reason: 'a second install would otherwise bury what it displaced');
  });

  test('it does not mistake an older installer for the user', () async {
    // Installers before the coordinator wrote their post-reboot half straight
    // to this path. Saving one as if it were the user's script means handing
    // it back on retirement, which re-arms a dead run against a staging
    // directory that has since been swept.
    await File('${root.path}/onboot.sh').writeAsString(
        '#!/bin/sh\n# Auto-generated by installer trampoline\nexit 0\n');
    final result = await install();
    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(File('${root.path}/installer/onboot.sh.bak').existsSync(), isFalse,
        reason: 'a dead trampoline must not come back as the user\'s script');
  });
}

/// A successful install used to delete its own account of itself. What it
/// leaves behind now, and what stops that growing without bound.
void historyTests() {
  test('the sweep keeps the record, the phases and a displaced onboot', () async {
    final root = await Directory.systemTemp.createTemp('sweep-');
    addTearDown(() => root.delete(recursive: true));
    final installer = Directory('${root.path}/installer');
    for (final d in ['history/run-1', 'scripts', 'fwtools']) {
      await Directory('${installer.path}/$d').create(recursive: true);
    }
    for (final f in [
      'history/run-1/record',
      'history/run-1/installer.log',
      'scripts/90-finalize.sh',
      'onboot.sh.bak',
      'last-install',
      'run-state',
      'trampoline.log',
      'librescoot-unu-dbc.sdimg.gz',
    ]) {
      await File('${installer.path}/$f').writeAsString('x');
    }

    final script = File('${root.path}/sweep.sh');
    await script.writeAsString(
        SshService.installerSweepCommand.replaceAll('/data/', '${root.path}/'));
    final result = await Process.run('sh', [script.path]);
    expect(result.exitCode, 0, reason: result.stderr.toString());

    for (final kept in [
      'history/run-1/record',
      'history/run-1/installer.log',
      'scripts/90-finalize.sh',
      'onboot.sh.bak',
      'last-install',
      'run-state',
    ]) {
      expect(File('${installer.path}/$kept').existsSync(), isTrue,
          reason: '$kept should survive the sweep');
    }
    for (final gone in ['trampoline.log', 'librescoot-unu-dbc.sdimg.gz']) {
      expect(File('${installer.path}/$gone').existsSync(), isFalse,
          reason: '$gone is staging and should go');
    }
    expect(Directory('${installer.path}/fwtools').existsSync(), isFalse);
  });

  test('the record says what the run was asked to do', () {
    // "success" alone cannot answer why a scooter is on the channel it is on,
    // or which region its maps came from.
    final finalize = File('assets/finalize.sh.template').readAsStringSync();
    for (final field in [
      'result: success',
      'release:',
      'action-mdb:',
      'action-dbc:',
      'language:',
      'channel:',
      'region:',
      'finished:',
      'mdb:',
      'dbc:',
    ]) {
      expect(finalize, contains('echo "$field'),
          reason: 'the record should carry $field');
    }
  });
}
