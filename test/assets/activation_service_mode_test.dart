import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/install_phase_scripts.dart';

void main() {
  late Directory root;
  late Directory data;
  late File phase;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('activation-service-mode-');
    data = await Directory('${root.path}/data').create();
    final scripts = await Directory(
      '${data.path}/installer/scripts',
    ).create(recursive: true);
    await File(
      '${scripts.path}/signal.sh',
    ).writeAsString('signal_error() { echo error-signal; }\n');
    await File(
      '${root.path}/cmdline',
    ).writeAsString('root=/dev/mmcblk1p2 quiet\n');
    final template = await File(
      'assets/reboot-phase.sh.template',
    ).readAsString();
    final rendered = RebootPhaseScript.render(
      template: template,
      runId: 'run-1',
    ).replaceAll('/data/', '${data.path}/');
    phase = File('${scripts.path}/80-reboot.sh');
    await phase.writeAsString(rendered);
  });
  tearDown(() => root.delete(recursive: true));

  Future<ProcessResult> run(String verdict) async {
    await File(
      '${data.path}/installer/mdb-artifact.result',
    ).writeAsString(verdict);
    return Process.run(
      'sh',
      [phase.path],
      environment: {'CMDLINE': '${root.path}/cmdline'},
    );
  }

  test(
    'activation persists service mode before retiring and requesting reboot',
    () async {
      final result = await run('ok');
      expect(result.exitCode, 75, reason: result.stderr.toString());
      final state = jsonDecode(
        await File('${data.path}/service-mode.json').readAsString(),
      );
      expect(state, {'active': true, 'name': 'service'});
      expect(await phase.exists(), isFalse);
      expect(
        await File('${data.path}/installer/previous-root').readAsString(),
        '/dev/mmcblk1p2\n',
      );
      expect(
        await File(
          '${data.path}/installer/history/run-1/reboot.log',
        ).readAsString(),
        contains('service mode armed for activation'),
      );
    },
  );

  test(
    'failed persistence refuses reboot and retains the activation phase',
    () async {
      await Directory('${data.path}/service-mode.json.run-1.tmp').create();
      final result = await run('ok');
      expect(result.exitCode, 1);
      expect(await phase.exists(), isTrue);
      expect(
        await File('${data.path}/installer/mdb-artifact.result').exists(),
        isTrue,
      );
      expect(
        await File('${data.path}/installer/trampoline-status').readAsString(),
        contains('error: could not persist service mode\nrun-id: run-1\n'),
      );
      expect(result.stdout, contains('error-signal'));
      expect(
        await File('${data.path}/installer/previous-root').exists(),
        isFalse,
      );
    },
  );

  test('no activation leaves existing service mode intact', () async {
    final state = File('${data.path}/service-mode.json');
    await state.writeAsString('{"active":true,"name":"service"}\n');
    final result = await run('skipped');
    expect(result.exitCode, 0);
    expect(await state.readAsString(), '{"active":true,"name":"service"}\n');
    expect(await phase.exists(), isFalse);
  });

  test('failed artifact cannot request an activation reboot', () async {
    final result = await run('error: install failed');
    expect(result.exitCode, 1);
    expect(await phase.exists(), isTrue);
    expect(await File('${data.path}/service-mode.json').exists(), isFalse);
  });
}
