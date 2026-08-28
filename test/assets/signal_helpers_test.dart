import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/install_phase_scripts.dart';

/// Everything the vehicle says about an install in progress, run for real
/// against stubbed binaries.
///
/// The signalling is the only account of the install the owner gets between the
/// cable swap and the unlock, it runs on a board nobody can reach, and the
/// scripts that drive it are spread across the trampoline, four phases and the
/// coordinator. So it is exercised rather than grepped.
void main() {
  late Directory root;
  late Directory bin;
  late String helpers;

  String calls() => File('${root.path}/calls').existsSync()
      ? File('${root.path}/calls').readAsStringSync()
      : '';

  List<String> callLines() =>
      calls().split('\n').where((l) => l.isNotEmpty).toList();

  Future<void> stub(String name, String body) async {
    final f = File('${bin.path}/$name');
    await f.writeAsString('#!/bin/sh\n$body\n');
    await Process.run('chmod', ['+x', f.path]);
  }

  /// Sources the helpers and runs [script] against them, the way every phase
  /// on the board does.
  Future<ProcessResult> run(String script, {bool withIoctl = true}) async {
    if (!withIoctl) await File('${bin.path}/ioctl').delete();
    final f = File('${root.path}/case.sh');
    await f.writeAsString(
      '. ${root.path}/installer/scripts/signal.sh\n$script\n',
    );
    return Process.run(
      'sh',
      [f.path],
      environment: {
        'PATH': '${bin.path}:${Platform.environment['PATH']}',
        'CALLS': '${root.path}/calls',
      },
    );
  }

  String state() {
    final f = File('${root.path}/installer/trampoline-phase');
    return f.existsSync() ? f.readAsStringSync().trim() : '';
  }

  setUpAll(() => helpers = File(SignalHelpers.assetPath).readAsStringSync());

  setUp(() async {
    root = await Directory.systemTemp.createTemp('signal-');
    bin = Directory('${root.path}/bin');
    await bin.create(recursive: true);
    await Directory('${root.path}/installer/scripts').create(recursive: true);
    await File('${root.path}/installer/scripts/signal.sh')
        .writeAsString(helpers.replaceAll('/data/', '${root.path}/'));
    for (final tool in ['ioctl', 'i2cset', 'systemctl']) {
      await stub(tool, 'echo "$tool \$*" >> "\$CALLS"');
    }
    // systemd-run's payload is a whole script, and `sh` after it is only the
    // $0 the inner shell is given. The unit and the arguments after that are
    // what identify which loop was started and on which channels.
    await stub(
      'systemd-run',
      r'''unit=""
args=""
for a in "$@"; do
  case "$a" in
    --unit=*) unit="${a#--unit=}" ;;
    --*|/bin/sh|-c|sh) ;;
    *) case "$a" in
         *while*|*i2cset*) ;;
         *) args="$args $a" ;;
       esac ;;
  esac
done
echo "systemd-run $unit$args" >> "$CALLS"''',
    );
    await stub('sleep', 'exit 0');
  });
  tearDown(() => root.delete(recursive: true));

  group('the bar', () {
    test('two segments can be lit at once', () async {
      // The main board writes its own artifact while the dashboard is being
      // flashed and uploaded to, and 80-reboot.sh joins the two. A bar that
      // only ever has one active segment cannot say that, and the half that
      // was not showing looks like a run that stalled.
      await run('progress_set 2 active\nprogress_set 3 active');
      expect(state(), '-**-');
      // Segments 2 and 3 are channels 7 and 4, and both go to the same loop so
      // they breathe in step.
      expect(callLines().last, 'systemd-run librescoot-progress-breathe'
          ' ${bin.path}/ioctl 7 4');
    });

    test('a half that finishes first fills while the other keeps breathing',
        () async {
      // Either half can win. Holding the finished one active until its
      // neighbour catches up would report work as still running for minutes
      // after it was done.
      await run('progress_set 2 active\nprogress_set 3 active\n'
          'progress_set 2 done');
      expect(state(), '-#*-');
      // Channel 7 filled at the static glow, channel 4 still the only one in
      // the breathing loop.
      expect(calls(), contains('ioctl /dev/pwm_led7 0x0000754A -v 150'));
      expect(callLines().last,
          'systemd-run librescoot-progress-breathe ${bin.path}/ioctl 4');
    });

    test('the bar fills left to right past stages the plan skipped', () async {
      // An upgrade writes no stage-0 image and a plan that leaves the main
      // board alone installs no artifact. The state file records that, but
      // the bar is drawn filled up to the furthest lit segment: a dark gap
      // before a breathing segment reads as a fault, not as a skipped stage.
      await run('progress_set 3 active');
      expect(state(), '--*-');
      for (final ch in ['3', '7']) {
        expect(calls(), contains('ioctl /dev/pwm_led$ch 0x0000754A -v 150'),
            reason: 'channel $ch should be filled behind the active segment');
      }
      // Nothing after the furthest lit segment is touched.
      expect(calls(), isNot(contains('ioctl /dev/pwm_led6 0x0000754A -v 150')));
      expect(callLines().last,
          'systemd-run librescoot-progress-breathe ${bin.path}/ioctl 4');
    });

    test('the state survives a fresh source, which is the reboot', () async {
      // 80-reboot.sh asks the coordinator for the one reboot in the middle of
      // the run. Everything in memory goes with it, so the bar the vehicle
      // comes back up with can only come from the file.
      await run('progress_set 2 done\nprogress_set 3 done\n'
          'progress_set 4 active');
      final after = await run('progress_render');
      expect(after.exitCode, 0, reason: after.stderr.toString());
      expect(state(), '-##*');
      expect(calls(), contains('ioctl /dev/pwm_led7 0x0000754A -v 150'));
      expect(calls(), contains('ioctl /dev/pwm_led4 0x0000754A -v 150'));
      expect(callLines().last,
          'systemd-run librescoot-progress-breathe ${bin.path}/ioctl 6');
    });

    test('a state file from another installer lights nothing', () async {
      // Before this the file held a phase number, and a resumed board can
      // still be carrying one. Reading a 2 as a bar would light two segments
      // for a run that has not started.
      await File('${root.path}/installer/trampoline-phase').writeAsString('2\n');
      await run('progress_render');
      expect(calls(), isNot(contains('-v 150')));
      expect(
          callLines().where((l) => l.startsWith('systemd-run librescoot-progress')),
          isEmpty);
    });

    test('the breathing runs as a transient unit, not a child of the phase',
        () async {
      // The coordinator runs phases with sh under librescoot-onboot.service,
      // which is Type=oneshot with the default KillMode=control-group: every
      // descendant dies when the phase returns. A background subshell would
      // take the animation with it and leave a frozen blinker behind.
      await run('progress_set 1 active');
      expect(callLines(),
          contains('systemd-run librescoot-progress-breathe ${bin.path}/ioctl 3'));
      expect(callLines(),
          contains('systemctl stop librescoot-progress-breathe.service'),
          reason: 'one loop at a time, or two fight over the same channel');
    });

    test('a lock nobody released does not wedge the bar', () async {
      // Two halves of the run write this file, so the read-modify-write is
      // locked. A phase killed mid-write leaves the lock behind, and a bar
      // that waited on it forever would strand every later stage dark.
      await Directory('${root.path}/installer/trampoline-phase.lock')
          .create(recursive: true);
      final r = await run('progress_set 2 done');
      expect(r.exitCode, 0, reason: r.stderr.toString());
      expect(state(), '-#--');
    });

    test('clearing the bar leaves the channels claimable', () async {
      // In the driver the active flag gates the PWM output, and
      // vehicle-service sets it once at its own Init and only loads duties
      // afterwards. A channel deactivated here stays dark through every
      // blinker the owner signals until vehicle-service re-inits.
      await run('progress_set 2 done\nprogress_off');
      expect(state(), '');
      expect(calls(), contains('ioctl /dev/pwm_led7 0x0000754A -v 0'));
      expect(calls(), isNot(contains('ioctl /dev/pwm_led7 0x00007549 -v 0')));
    });
  });

  group('the front light', () {
    test('pulses on its own channel, and only while the dashboard is awaited',
        () async {
      // It is the one signal that asks the owner for something: the cable has
      // to move onto the dashboard before anything else can happen. Sharing a
      // blinker channel with the bar would make that instruction unreadable.
      await run('front_pulse_start');
      expect(callLines().last,
          'systemd-run librescoot-front-pulse ${bin.path}/ioctl 1');

      await File('${root.path}/calls').delete();
      await run('front_pulse_stop');
      expect(callLines(), contains('systemctl stop librescoot-front-pulse.service'));
      expect(calls(), contains('ioctl /dev/pwm_led1 0x0000754A -v 0'));
    });
  });

  group('the dashboard LED', () {
    test('an install in progress is amber and stays amber', () async {
      // vehicle-service drives the same LP5562 for blinker brightness and
      // cannot be masked, so a single write is stomped by the next blinker.
      await run('signal_install_start');
      expect(calls(), contains('i2cset -f -y 2 0x30 0x02 0xFF'));
      expect(callLines(),
          contains('systemd-run librescoot-bootled-guard'));
    });

    test('a run that worked ends dark, not green', () async {
      // The vehicle unlocks itself at the end, and that is the success signal.
      // A green LED left blinking on a parked scooter is a second, quieter
      // claim that somebody has to find and interpret.
      final r = await run('signal_install_done');
      expect(r.exitCode, 0, reason: r.stderr.toString());
      expect(calls(), contains('systemctl stop librescoot-bootled-guard.service'));
      expect(calls().trim().split('\n').last, 'i2cset -f -y 2 0x30 0x04 0x00');
      expect(helpers, isNot(contains('bootled_blink_green')),
          reason: 'green is not a state this signalling has any more');
    });

    test('a run that failed goes red and flashes the hazards', () async {
      // Nobody is at the laptop by then. Red on the dashboard is only visible
      // to somebody already looking at it; four blinkers in unison is visible
      // from across a courtyard.
      await run('progress_set 3 active\nsignal_error');
      expect(state(), '', reason: 'the bar was describing a run that stopped');
      expect(callLines(),
          contains('systemd-run librescoot-bootled-blink'));
      expect(callLines(),
          contains('systemd-run librescoot-bootled-hazards ${bin.path}/ioctl'));
      expect(calls(), contains('systemctl stop librescoot-bootled-guard.service'),
          reason: 'the guard would re-assert amber over the red every 2s');
    });
  });

  group('an image with no LED tooling', () {
    test('is survivable, and says so in the log', () async {
      // ioctl and i2c-tools ship in the full image and in neither bootstrap
      // one, and the autonomous half of an install runs on whichever the board
      // happens to be on. A run that cannot light anything must still install,
      // and the log is the only place that can explain the dark scooter.
      final r = await run(
        'progress_set 2 active\nprogress_render\nsignal_install_start\n'
        'front_pulse_start\nsignal_install_done\necho survived',
        withIoctl: false,
      );
      expect(r.exitCode, 0, reason: r.stderr.toString());
      expect(r.stdout.toString(), contains('survived'));
      expect(
        File('${root.path}/installer/trampoline.log').readAsStringSync(),
        contains('no ioctl on this image'),
      );
    });
  });

  group('one definition, everywhere', () {
    test('every script that signals sources this file', () async {
      // These were defined twice, in the trampoline and again inside the
      // heredoc that writes the dashboard phase, and the two drifted. The
      // phases the restructure added defined them nowhere at all, which is why
      // a run went dark the moment the trampoline handed over.
      const sources = [
        'assets/trampoline.sh.template',
        'assets/mdb-artifact.sh.template',
        'assets/reboot-phase.sh.template',
        'assets/finalize.sh.template',
      ];
      for (final path in sources) {
        expect(File(path).readAsStringSync(), contains('signal.sh'),
            reason: '$path signals without sourcing the helpers');
      }
    });

    test('nothing else defines a helper this file owns', () {
      // A second definition anywhere is the drift this replaced. It also wins
      // over the sourced one, so the copy that gets fixed is not the copy that
      // runs.
      final owned = RegExp(r'^([a-z_][a-z0-9_]*)\(\)', multiLine: true)
          .allMatches(helpers)
          .map((m) => m.group(1)!)
          .toSet();
      expect(owned, contains('progress_set'));
      expect(owned, contains('bootled_guard_start'));

      for (final path in [
        'assets/trampoline.sh.template',
        'assets/mdb-artifact.sh.template',
        'assets/reboot-phase.sh.template',
        'assets/finalize.sh.template',
      ]) {
        final body = File(path).readAsStringSync();
        for (final name in owned) {
          expect(body, isNot(contains(RegExp('^ *$name\\(\\)', multiLine: true))),
              reason: '$path redefines $name');
        }
      }
    });
  });
}
