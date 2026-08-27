import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/finalize_script.dart';

/// The last thing that runs on a scooter, on both paths, frequently with
/// nobody watching. What it does with a failed install matters as much as what
/// it does with a good one.
void main() {
  final templateFile = File('assets/finalize.sh.template');
  late String template;

  setUpAll(() => template = templateFile.readAsStringSync());

  String render({
    String mdbAction = 'upgrade',
    String runId = 'run-test-1',
    String mode = 'upgrade',
    String language = 'de',
    String channel = 'stable',
  }) =>
      FinalizeScript.render(
        template: template,
        mdbAction: mdbAction,
        runId: runId,
        mode: mode,
        language: language,
        channel: channel,
        mdbVersion: 'v1.2.1',
        dbcVersion: 'v1.2.1',
      );

  group('rendering', () {
    test('a rendered script has nothing left to fill', () {
      expect(FinalizeScript.unresolvedPlaceholders(render()), isEmpty);
    });

    test('it refuses rather than shipping a hole', () {
      // An unfilled placeholder is valid shell in most of the places one
      // appears, so the script would run and take the wrong branch.
      expect(
        () => FinalizeScript.render(
          template: '$template\nEXTRA="{{SOMETHING_NEW}}"\n',
          mdbAction: 'upgrade',
          runId: 'r',
          mode: 'upgrade',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('every placeholder the template carries is one we fill', () {
      expect(FinalizeScript.unresolvedPlaceholders(render()), isEmpty,
          reason: 'the template gained a placeholder the renderer ignores');
    });
  });

  group('running it', () {
    late Directory root;
    late String calls;

    Future<void> stubs({String serviceModeActive = 'false'}) async {
      final bin = Directory('${root.path}/bin');
      await bin.create(recursive: true);
      final entries = {
        'redis-cli': '''#!/bin/sh
echo "redis-cli \$*" >> "\$CALLS"
case "\$*" in
  *"hget settings dashboard.service-mode-active"*) echo $serviceModeActive ;;
esac
''',
        'lsc': '#!/bin/sh\necho "lsc \$*" >> "\$CALLS"\n',
        'systemctl': '''#!/bin/sh
echo "systemctl \$*" >> "\$CALLS"
case "\$1" in is-active) echo active ;; esac
''',
        'sleep': '#!/bin/sh\nexit 0\n',
      };
      for (final e in entries.entries) {
        final f = File('${bin.path}/${e.key}');
        await f.writeAsString(e.value);
        await Process.run('chmod', ['+x', f.path]);
      }
    }

    Future<ProcessResult> run({
      String mdbAction = 'upgrade',
      String? status,
      String serviceModeActive = 'false',
      String runId = 'run-test-1',
    }) async {
      await stubs(serviceModeActive: serviceModeActive);
      await Directory('${root.path}/installer').create(recursive: true);
      if (status != null) {
        await File('${root.path}/installer/trampoline-status')
            .writeAsString('$status\n');
      }
      final script = File('${root.path}/installer/scripts/90-finalize.sh');
      await script.parent.create(recursive: true);
      await script.writeAsString(
        render(mdbAction: mdbAction, runId: runId)
            .replaceAll('/data/', '${root.path}/'),
      );
      return Process.run('sh', [
        script.path
      ], environment: {
        'PATH': '${root.path}/bin:${Platform.environment['PATH']}',
        'CALLS': calls,
      });
    }

    Future<List<String>> callLog() async =>
        File(calls).existsSync() ? File(calls).readAsLines() : <String>[];

    setUp(() async {
      root = await Directory.systemTemp.createTemp('finalize-');
      calls = '${root.path}/calls.log';
    });
    tearDown(() => root.delete(recursive: true));

    test('an upgrade gets the pre-install settings back', () async {
      await Directory('${root.path}/installer').create(recursive: true);
      await File('${root.path}/settings.toml.preinstall')
          .writeAsString('# the user had these\n');
      final result = await run(mdbAction: 'upgrade');
      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(await File('${root.path}/settings.toml').readAsString(),
          contains('the user had these'));
    });

    test('a clean install wipes them instead', () async {
      await Directory('${root.path}/installer').create(recursive: true);
      await File('${root.path}/settings.toml').writeAsString('# ours\n');
      final result = await run(mdbAction: 'cleanInstall');
      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(File('${root.path}/settings.toml').existsSync(), isFalse);
    });

    test('with no backup and a live overlay it writes no defaults', () async {
      // settings-service reads a non-overlay value written to an overlaid key
      // as a deliberate edit, moves its captured base to it, and hands that
      // back on the clear. Writing 900 here loses whatever was configured.
      final result = await run(mdbAction: 'upgrade', serviceModeActive: 'true');
      expect(result.exitCode, 0, reason: result.stderr.toString());
      final log = await callLog();
      expect(log.any((l) => l.contains('auto-standby-seconds 900')), isFalse);
      expect(log.any((l) => l.contains('alarm.enabled true')), isFalse);
    });

    test('with no backup and no overlay it does reset the two keys', () async {
      final result = await run(mdbAction: 'upgrade', serviceModeActive: 'false');
      expect(result.exitCode, 0, reason: result.stderr.toString());
      final log = await callLog();
      expect(log.any((l) => l.contains('auto-standby-seconds 900')), isTrue);
      expect(log.any((l) => l.contains('alarm.enabled true')), isTrue);
    });

    test('service mode ends before the policy is restored', () async {
      final result = await run();
      expect(result.exitCode, 0, reason: result.stderr.toString());
      final log = await callLog();
      final clear = log.indexWhere((l) => l.contains('clear:service'));
      final policy = log.indexWhere((l) => l.contains('usb0-policy auto'));
      expect(clear, isNot(-1));
      expect(policy, greaterThan(clear),
          reason: 'a policy write before the clear lands gets re-asserted');
      expect(File('${root.path}/service-mode.json').existsSync(), isFalse);
    });

    test('a good run unlocks and records what it installed', () async {
      final result = await run(status: 'success', runId: 'run-good');
      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect((await callLog()).any((l) => l.contains('scooter:state unlock')),
          isTrue);
      final record = await File(
              '${root.path}/installer/history/run-good/record')
          .readAsString();
      expect(record, contains('result: success'));
      expect(record, contains('run-id: run-good'));
      expect(record, contains('mdb: v1.2.1'));
      expect(await File('${root.path}/installer/last-install').readAsString(),
          contains('run-id: run-good'));
    });

    test('a failed run is handed back but not claimed as a success', () async {
      // The settings still go back and service mode still ends, because a
      // scooter left in service mode has no hibernation timer and no alarm.
      // Nothing here says the install worked.
      final result = await run(status: 'error: dbc never answered');
      expect(result.exitCode, 0, reason: result.stderr.toString());
      final log = await callLog();
      expect(log.any((l) => l.contains('clear:service')), isTrue);
      expect(log.any((l) => l.contains('usb0-policy auto')), isTrue);
      expect(log.any((l) => l.contains('scooter:state unlock')), isFalse,
          reason: 'unlocking contradicts the error the user is looking at');
      expect(
          File('${root.path}/installer/history/run-test-1/record').existsSync(),
          isFalse,
          reason: 'no success record for a run that did not succeed');
    });

    test('it removes itself so the coordinator can retire', () async {
      await run();
      expect(
          File('${root.path}/installer/scripts/90-finalize.sh').existsSync(),
          isFalse);
    });
  });
}
