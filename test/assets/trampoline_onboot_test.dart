import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The trampoline writes `/data/onboot.sh` through a quoted heredoc, which
/// inherits nothing from the script that writes it. Every helper onboot.sh
/// calls therefore has to be defined a second time inside that heredoc, and a
/// helper that is only defined in the outer half fails at run time, on the far
/// side of an MDB reboot, with the laptop already unplugged.
void main() {
  final template = File('assets/trampoline.sh.template');

  late String outer;
  late String onboot;

  setUpAll(() {
    final source = template.readAsStringSync();
    // onboot.sh is assembled from several heredocs (ONBOOT, ONBOOT_VARS,
    // TILES, ONBOOT_END). Taking only the first would check a fraction of
    // the script, so the body runs from the first chunk to the last
    // terminator, and everything outside it is the trampoline's own half.
    final start = source.indexOf("cat > /data/onboot.sh << 'ONBOOT'");
    expect(start, isNot(-1), reason: 'onboot heredoc not found');
    final end = source.indexOf('\nONBOOT_END\n', start);
    expect(end, isNot(-1), reason: 'onboot heredoc is not terminated');

    onboot = source.substring(start, end);
    outer = source.substring(0, start) + source.substring(end);
  });

  final defRe = RegExp(r'^[ \t]*([a-z_][a-z0-9_]*)[ \t]*\(\)[ \t]*\{',
      multiLine: true);

  Set<String> definitionsIn(String body) =>
      defRe.allMatches(body).map((m) => m.group(1)!).toSet();

  test('onboot.sh defines every trampoline helper it calls', () {
    final outerHelpers = definitionsIn(outer);
    final onbootHelpers = definitionsIn(onboot);

    final missing = <String>[];
    for (final helper in outerHelpers) {
      if (onbootHelpers.contains(helper)) continue;
      // A call is the name at the start of a command: line start, or after
      // a separator. Excludes mentions inside comments and longer words.
      final callRe = RegExp(
          r'(^|[;&|]|\bthen\b|\belse\b|\bdo\b|&&|\|\|)[ \t]*' +
              RegExp.escape(helper) +
              r'(?=[ \t;&|)\n]|$)',
          multiLine: true);
      for (final line in onboot.split('\n')) {
        final code = line.split('#').first;
        if (callRe.hasMatch(code)) {
          missing.add(helper);
          break;
        }
      }
    }

    expect(missing, isEmpty,
        reason: 'onboot.sh calls these but never defines them, so they fail '
            'after the MDB reboot: ${missing.join(", ")}');
  });

  test('the dashboard power helpers reached onboot.sh', () {
    // The specific set that stranded a dashboard: onboot.sh cannot power the
    // board it is meant to install to without them.
    final onbootHelpers = definitionsIn(onboot);
    for (final helper in [
      'dbc_power_on',
      'dbc_power_off',
      'dbc_power_on_wait',
      'dbc_power_set',
      'dbc_gpio_ready',
    ]) {
      expect(onbootHelpers, contains(helper));
    }
  });

  test('onboot.sh logs to a file it has defined', () {
    // The outer half writes lsc output to $LOG_FILE, onboot.sh to $LOG.
    // Copying a helper across without swapping the variable loses the output.
    expect(onboot.contains(r'LOG_FILE'), isFalse,
        reason: r'onboot.sh has no $LOG_FILE; it uses $LOG');
  });

  test('every unit the trampoline masks is unmasked and started again', () {
    // The flash used to reboot the MDB halfway through, which restarted
    // whatever had been stopped. Without it, anything masked has to be put
    // back explicitly or the scooter is handed over with services missing.
    Set<String> units(String body, String verb) {
      final out = <String>{};
      final re = RegExp(r'systemctl\s+(?:--\S+\s+)?' + verb + r'\s+([^\n|;&]+)');
      for (final m in re.allMatches(body)) {
        for (final tok in m.group(1)!.split(RegExp(r'\s+'))) {
          if (tok.isEmpty) continue;
          if (tok.startsWith('-') || tok.startsWith('2>') || tok.startsWith('>')) break;
          out.add(tok.replaceAll('.service', ''));
        }
      }
      return out;
    }

    final whole = outer + onboot;
    final masked = units(whole, 'mask');
    final unmasked = units(whole, 'unmask');
    final started = units(whole, 'start');

    for (final unit in masked) {
      expect(unmasked, contains(unit),
          reason: '$unit is masked and never unmasked');
      expect(started, contains(unit),
          reason: '$unit is masked and never started again');
    }
    // keycard-service is the one whose start is conditional: on a board with
    // no master card it auto-enters master-learning and would teach in
    // whatever card is tapped first, so it only starts when cards were
    // already paired. It must still be unmasked unconditionally.
    expect(unmasked, contains('librescoot-keycard'));
  });

  test('the finish restores what it stopped and hands back a usable scooter',
      () {
    // The finish used to reboot, which restored pm-service, applied the usb0
    // policy and released the LED in one go. It ends by unlocking instead,
    // and a reboot would come back locked, so each of those has to be done
    // directly. Any one of them dropped is silent: no power management on a
    // parked scooter, or blinkers that stay dark.
    expect(onboot, contains('systemctl start librescoot-pm'),
        reason: 'pm-service is stopped on every connect and started by '
            'nothing else');
    expect(onboot, contains('systemctl restart librescoot-vehicle'),
        reason: 'vehicle-service has to re-claim the PWM channels the '
            'progress bar borrowed, or the blinkers stay dark');
    expect(onboot, contains('lsc set scooter.usb0-policy auto'));
    expect(onboot, contains('lpush scooter:state unlock'),
        reason: 'the unlock is the success signal');
    expect(outer.contains('if restore_gadget; then'), isTrue,
        reason: 'the mid-flash handover should restore the role, not reboot');
  });

  test('onboot.sh defines every function before it calls it', () {
    // Shell binds at execution, so a definition below its first call is a
    // "command not found" that only appears on the device, after the MDB
    // reboot, with the laptop unplugged.
    final defLine = <String, int>{};
    final lines = onboot.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final m = defRe.firstMatch(lines[i]);
      if (m != null) defLine.putIfAbsent(m.group(1)!, () => i);
    }

    final late = <String>[];
    for (final entry in defLine.entries) {
      final callRe = RegExp(
          r'(^|[;&|]|\bthen\b|\belse\b|\bdo\b|&&|\|\|)[ \t]*' +
              RegExp.escape(entry.key) +
              r'(?=[ \t;&|)\n]|$)');
      for (var i = 0; i < lines.length; i++) {
        if (i == entry.value) continue;
        final code = lines[i].split('#').first;
        if (code.trimLeft().startsWith(entry.key) &&
            code.contains('${entry.key}()')) {
          continue;
        }
        if (callRe.hasMatch(code)) {
          if (i < entry.value) {
            late.add('${entry.key} (called line $i, '
                'defined line ${entry.value})');
          }
          break;
        }
      }
    }

    expect(late, isEmpty,
        reason: 'called before they are defined: ${late.join(", ")}');
  });

  test('every substituted value onboot.sh reads is baked into it', () {
    // onboot.sh is built from heredocs. A quoted one keeps $VAR literal, so
    // the variable is read when onboot.sh runs and must have been written into
    // the file; an unquoted one expands at generation time and needs nothing.
    // A value left out is empty at runtime, and an empty string fails every
    // test silently rather than erroring.
    final source = File('assets/trampoline.sh.template').readAsStringSync();

    final substituted = RegExp(r'^([A-Z0-9_]+)="\{\{[A-Z0-9_]+\}\}"',
            multiLine: true)
        .allMatches(source)
        .map((m) => m.group(1)!)
        .toSet();
    expect(substituted, isNotEmpty, reason: 'no substituted values found');

    final chunkRe = RegExp(
        r"cat >>? /data/onboot\.sh << (')?([A-Z_]+)\1?\n([\s\S]*?)\n\2\n");
    final baked = <String>{};
    final assigned = <String>{};
    final readAtRuntime = <String>{};

    for (final m in chunkRe.allMatches(source)) {
      final quoted = m.group(1) == "'";
      final body = m.group(3)!;
      if (!quoted) {
        baked.addAll(RegExp(r'^([A-Z0-9_]+)=', multiLine: true)
            .allMatches(body)
            .map((x) => x.group(1)!));
      } else {
        assigned.addAll(RegExp(r'^\s*([A-Z0-9_]+)=', multiLine: true)
            .allMatches(body)
            .map((x) => x.group(1)!));
        readAtRuntime.addAll(RegExp(r'\$\{?([A-Z0-9_]+)')
            .allMatches(body)
            .map((x) => x.group(1)!));
      }
    }

    final missing = readAtRuntime
        .intersection(substituted)
        .where((v) => !baked.contains(v) && !assigned.contains(v))
        .toList()
      ..sort();

    expect(missing, isEmpty,
        reason: 'onboot.sh reads these but nothing writes them into it, so '
            'they are empty on the device: ${missing.join(", ")}');
  });

  test('the finish flag specifically reaches onboot.sh', () {
    // The one whose absence is silent: both finish blocks compare it against
    // "true", so an empty value hands back to the laptop while the LED still
    // reports the install as done.
    final source = File('assets/trampoline.sh.template').readAsStringSync();
    final vars = RegExp(
            r'cat >> /data/onboot\.sh << ONBOOT_VARS\n([\s\S]*?)\nONBOOT_VARS')
        .firstMatch(source)!
        .group(1)!;
    for (final v in [
      'FINISH_ON_DEVICE',
      'FINISH_LANGUAGE',
      'FINISH_CHANNEL',
      'START_KEYCARD',
      'MDB_ACTION',
      'MDB_TARGET',
    ]) {
      expect(vars, contains('$v="\$$v"'), reason: '$v is not baked in');
    }
  });

  test('a board left alone gets its parked settings back', () {
    // The installer parks auto-standby and the alarm at connect time, before
    // any plan exists, so a leave plan has modified settings and a backup to
    // restore from. Treating leave as "untouched" strands the alarm off; the
    // wildcard arm deletes settings on a board this install never wrote to.
    expect(onboot, contains('upgrade|leave)'),
        reason: 'leave keeps /data like upgrade and must restore, not wipe '
            'and not skip');
    expect(onboot, isNot(contains('        leave)')),
        reason: 'leave must not have its own do-nothing arm');
  });

  test('the finish starts keycard-service unconditionally', () {
    // The install is over, so the board runs what a board runs. Gating this on
    // a master card left the reader dead on a board that had cards but no
    // master, with no laptop attached to start it and no reboot coming.
    expect(
      onboot,
      contains('systemctl start librescoot-keycard'),
      reason: 'the finish must start the keycard reader',
    );
    for (final gate in ['KC_MASTERS', 'KC_CARDS', 'keycard-master-count']) {
      expect(onboot, isNot(contains(gate)),
          reason: 'starting the reader must not depend on $gate');
    }
  });

  test('no remote command on the dashboard is wrapped in timeout', () {
    // The dashboard image has no timeout binary. A remote command wrapped in
    // one fails instantly with "timeout: not found", which killed the artifact
    // install outright. Any ceiling has to be applied on this side, where the
    // binary exists.
    final offenders = <String>[];
    for (final line in onboot.split('\n')) {
      final code = line.split('#').first;
      if (RegExp(r'dbc_ssh\s+"[^"]*\btimeout\s').hasMatch(code) ||
          RegExp(r'dbc_ssh\s+.\s*timeout\s').hasMatch(code)) {
        offenders.add(line.trim());
      }
    }
    expect(offenders, isEmpty,
        reason: 'these run timeout on the dashboard, which does not have it: '
            '${offenders.join(" | ")}');
  });

  test('the long remote command is bounded from this side instead', () {
    expect(onboot, contains('dbc_ssh_bounded'),
        reason: 'the mender install needs a ceiling, applied on the MDB');
  });

  test('commands sent to the dashboard use binaries it actually has', () {
    // The dashboard spends most of the install running a bootstrap image: a
    // core-image with dropbear, data-server, the mender client and busybox,
    // and not much else. Its busybox has no timeout applet, which is how a
    // ceiling added on that side killed the artifact install after a
    // successful 212 MB transfer.
    //
    // Anything new here has to be a deliberate decision, so the set is fixed.
    // Add to it only after checking the image recipe.
    const known = {
      // busybox
      'cat', 'chmod', 'df', 'echo', 'grep', 'kill', 'mkdir', 'mv', 'printf',
      'rm', 'sync', 'test', 'reboot', 'sh', 'true',
      // systemd, in the image
      'systemctl',
      // shipped explicitly by the bootstrap recipe
      'mender-update',
      // only ever run after the dashboard reboots onto the full image
      'zstd',
    };

    final source = File('assets/trampoline.sh.template').readAsStringSync();
    final re = RegExp(
        r"""dbc_ssh(?:_bounded)?\s+(?:\d+\s+)?["']([^"']+)["']""");
    final calls = re.allMatches(source).map((m) => m.group(1)!).toList();
    expect(calls, isNotEmpty, reason: 'no dashboard commands found to check');

    final unknown = <String>{};
    for (final c in calls) {
      for (final part in c.split(RegExp(r'[;&|]'))) {
        final t = part.trim();
        if (t.isEmpty) continue;
        final word = t.split(RegExp(r'\s+')).first;
        if (!RegExp(r'^[a-z][a-z0-9._-]*$').hasMatch(word)) continue;
        if (!known.contains(word)) unknown.add(word);
      }
    }

    expect(unknown, isEmpty,
        reason: 'these run on the dashboard and are not known to exist there: '
            '${unknown.join(", ")}. Check the bootstrap image recipe, then '
            'either add them to the list or guard the call.');
  });
}
