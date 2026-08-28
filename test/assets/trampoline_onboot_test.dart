import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The trampoline writes its post-reboot phase through a quoted heredoc, which
/// inherits nothing from the script that writes it. Every helper onboot.sh
/// calls therefore has to be defined a second time inside that heredoc, and a
/// helper that is only defined in the outer half fails at run time, on the far
/// side of an MDB reboot, with the laptop already unplugged.
///
/// The signalling used to be nine of those doubled definitions. It is one
/// sourced file now, and what is checked here is that both halves source it;
/// the helpers themselves are exercised in signal_helpers_test.dart.
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
    final start =
        source.indexOf("""cat > "\$SCRIPTS_DIR/20-dbc.sh" << 'ONBOOT'""");
    expect(start, isNot(-1), reason: 'post-reboot phase heredoc not found');
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

  test('both halves source the signalling rather than carrying a copy', () {
    // The heredoc inherits nothing, so this is the one line that gives the
    // generated phase a bar to light. Without it every progress call in there
    // is a "not found" on a vehicle nobody is watching, which is exactly what
    // the phases the restructure added did.
    const source = r'. "$SCRIPTS_DIR/signal.sh"';
    expect(outer, contains(source),
        reason: 'the trampoline signals without sourcing the helpers');
    expect(onboot, contains(source),
        reason: 'the dashboard phase signals without sourcing the helpers');
  });

  test('the dashboard power and SSH helpers reach onboot.sh via device.sh',
      () {
    // dbc_ssh, wait_dbc_ssh and the dashboard power helpers used to be
    // defined a second time in here, the specific duplication that stranded
    // a dashboard when only one copy got a fix. They are sourced from
    // device.sh now, the same way the signalling is sourced from signal.sh.
    const source = r'. "$SCRIPTS_DIR/device.sh"';
    expect(outer, contains(source),
        reason: 'the trampoline talks to the DBC without sourcing device.sh');
    expect(onboot, contains(source),
        reason: 'the dashboard phase talks to the DBC without sourcing '
            'device.sh');

    final onbootHelpers = definitionsIn(onboot);
    for (final helper in [
      'dbc_power_on',
      'dbc_power_off',
      'dbc_power_on_wait',
      'dbc_power_set',
      'dbc_gpio_ready',
      'dbc_ssh',
      'wait_dbc_ssh',
    ]) {
      expect(onbootHelpers, isNot(contains(helper)),
          reason: '$helper should come from device.sh, not a local copy');
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
    final finalize = File('assets/finalize.sh.template').readAsStringSync();
    expect(finalize, contains('systemctl start librescoot-pm'),
        reason: 'pm-service is stopped on every connect and started by '
            'nothing else');
    expect(finalize, contains('systemctl restart librescoot-vehicle'),
        reason: 'vehicle-service has to re-claim the PWM channels the '
            'progress bar borrowed, or the blinkers stay dark');
    expect(finalize, contains('lsc set scooter.usb0-policy auto'));
    expect(finalize, contains('lpush scooter:state unlock'),
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

    // Lines inside a function body are deferred: shell resolves a call when
    // the function runs, not where it is written. install_tiles is defined
    // near the top so the artifact section can start it as a job, and its
    // body calls helpers defined much further down, which is legal and works.
    // Only top-level calls have to follow their definition.
    final inFunction = List<bool>.filled(lines.length, false);
    for (var i = 0; i < lines.length; i++) {
      if (!RegExp(r'^[a-z_][a-z0-9_]*\(\)[ \t]*\{').hasMatch(lines[i])) {
        continue;
      }
      // A one-line definition such as `install_tiles() { :; }` closes on its
      // own line. Scanning for a bare `}` after it would run to the next
      // unrelated function's brace and mark everything in between as deferred,
      // which silently turns the rest of this check off.
      final opens = '{'.allMatches(lines[i]).length;
      final closes = '}'.allMatches(lines[i]).length;
      if (opens <= closes) continue;
      for (var j = i + 1; j < lines.length; j++) {
        inFunction[j] = true;
        if (lines[j] == '}') break;
      }
    }

    final late = <String>[];
    for (final entry in defLine.entries) {
      final callRe = RegExp(
          r'(^|[;&|]|\bthen\b|\belse\b|\bdo\b|&&|\|\|)[ \t]*' +
              RegExp.escape(entry.key) +
              r'(?=[ \t;&|)\n]|$)');
      for (var i = 0; i < lines.length; i++) {
        if (i == entry.value || inFunction[i]) continue;
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

  test('the tile upload is joined before the dashboard reboots', () {
    // The upload runs alongside the artifact install to overlap the two, but
    // a dashboard that restarts mid-upload takes a truncated tile set with it,
    // so the reboot has to wait for the job.
    final job = onboot.indexOf(r'TILES_JOB=$!');
    final join = onboot.indexOf(r'wait "$TILES_JOB"');
    final reboot = onboot.indexOf('rebooting DBC into the new rootfs');
    expect(job, isNot(-1), reason: 'the upload should start as a job');
    expect(join, isNot(-1), reason: 'the job should be waited on');
    expect(join, lessThan(reboot),
        reason: 'the wait must come before the reboot, not after');
    expect(job, lessThan(join));
  });

  test('the tile error count survives the background job', () {
    // TILE_ERRORS is set inside a subshell, so the parent cannot read it back
    // as a variable. Losing it reports a failed tile install as a success.
    // Escaped, because it is written through an unquoted heredoc: the raw
    // template carries the backslashes and only the generated script does not.
    expect(onboot,
        contains(r'echo "\$TILE_ERRORS" > "\$INSTALLER_DIR/tile-errors"'));
    expect(onboot, contains(r'TILE_ERRORS=$(cat "$INSTALLER_DIR/tile-errors"'));
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
        r'''cat >>? [^\n]*20-dbc\.sh" << (')?([A-Z_]+)\1?\n([\s\S]*?)\n\2\n''');
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
            r'''cat >> [^\n]*20-dbc\.sh" << ONBOOT_VARS\n([\s\S]*?)\nONBOOT_VARS''')
        .firstMatch(source)!
        .group(1)!;
    for (final v in [
      'FINISH_ON_DEVICE',
      'FINISH_LANGUAGE',
      'FINISH_CHANNEL',
      'MDB_ACTION',
      'MDB_TARGET',
    ]) {
      expect(vars, contains('$v="\$$v"'), reason: '$v is not baked in');
    }
  });

  test('run progress survives staging cleanup in per-run state files', () {
    expect(onboot, contains(r'RUN_HISTORY_DIR="$INSTALLER_DIR/history"'));
    expect(onboot, contains(r'RUN_STATE_FILE="$INSTALLER_DIR/run-state"'));
    expect(onboot, contains('write_run_state()'));
    expect(onboot, contains(r'echo "run-id: $RUN_ID"'));
    expect(onboot,
        contains(r'mv -f "$history_tmp" "$RUN_HISTORY_DIR/$RUN_ID/record"'));
  });

  test('completion is written after the handover actions', () {
    // The record is what a returning laptop reads as the verdict, so it must
    // not land before the things it is a verdict on.
    final finalize = File('assets/finalize.sh.template').readAsStringSync();
    final record = finalize.indexOf('result: success');
    for (final earlier in [
      'lsc set scooter.usb0-policy auto',
      'systemctl start librescoot-pm',
      'systemctl restart librescoot-vehicle',
      'lpush scooter:state unlock',
    ]) {
      expect(finalize.indexOf(earlier), isNot(-1), reason: earlier);
      expect(record, greaterThan(finalize.indexOf(earlier)), reason: earlier);
    }
    expect(finalize, contains(r'mv -f "$INSTALLER_DIR/.last-install.tmp"'),
        reason: 'a reader must never see a half-written record');
  });

  test('a board left alone gets its parked settings back', () {
    // The installer parks auto-standby and the alarm at connect time, before
    // any plan exists, so a leave plan has modified settings and a backup to
    // restore from. Treating leave as "untouched" strands the alarm off; the
    // wildcard arm deletes settings on a board this install never wrote to.
    final finalize = File('assets/finalize.sh.template').readAsStringSync();
    expect(finalize, contains('upgrade|leave)'),
        reason: 'leave keeps /data like upgrade and must restore, not wipe '
            'and not skip');
    expect(finalize, isNot(contains('        leave)')),
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
    for (final gate in [
      'KC_MASTERS',
      'KC_CARDS',
      'keycard-master-count',
      'START_KEYCARD',
    ]) {
      expect(onboot, isNot(contains(gate)),
          reason: 'starting the reader must not depend on $gate');
    }
  });

  test('the finish keeps its own log out of the sweep', () {
    // The success path deletes the staging directory, and the trampoline's
    // log lives in it. A failed run keeps that directory for the installer to
    // read; a successful one used to delete the only account of the half of
    // the install the laptop never saw, which is the half nobody can produce
    // afterwards.
    final finishStart = onboot.indexOf('device_finish()');
    final finishEnd =
        onboot.indexOf('\n}\n\nif [ "\$ONBOOT_TRIES"', finishStart);
    final finish = onboot.substring(finishStart, finishEnd);
    final copy =
        finish.indexOf(r'cp "$LOG" "$RUN_HISTORY_DIR/$RUN_ID/trampoline.log"');
    final sweep = finish.indexOf(r'find "$INSTALLER_DIR" -mindepth 1');
    expect(copy, greaterThanOrEqualTo(0), reason: 'the log is not kept');
    expect(sweep, greaterThan(copy), reason: 'the sweep runs before the copy');
    // And the rest of the finish has somewhere to write: appending to a path
    // under a directory that no longer exists loses every line silently.
    final repoint =
        finish.indexOf(r'LOG="$RUN_HISTORY_DIR/$RUN_ID/trampoline.log"');
    expect(repoint, greaterThan(sweep));
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

  test('what was installed is recorded before the upload server goes away', () {
    // record_tiles reads the artifacts back over the same PUT server the
    // uploads used. Tearing that down first would leave it with only ssh, and
    // the metadata upload would fail on every run.
    final src = File('assets/trampoline.sh.template').readAsStringSync();
    final record = src.indexOf(RegExp(r'^record_tiles$', multiLine: true));
    final teardown = src.indexOf('Stop DBC Python upload server');
    expect(record, greaterThan(-1), reason: 'record_tiles is never called');
    expect(record, lessThan(teardown),
        reason: 'record_tiles runs after the upload server is stopped');
  });

  test('tile metadata is uploaded, not echoed through a remote shell', () {
    // The dashboard runs the bootstrap image during the tile phase and its
    // busybox has no base64 applet, so the record has to go over the PUT
    // server like every other file.
    final src = File('assets/trampoline.sh.template').readAsStringSync();
    expect(src, contains('"/maps/metadata.json"'),
        reason: 'metadata.json is not uploaded to the dashboard');
    // The word appears in the comment explaining why; what must not appear is
    // an actual invocation.
    expect(src, isNot(contains(RegExp(r'base64\s+-d'))),
        reason: 'base64 is not available on the bootstrap image');
  });

  test('the region reaches the recorded metadata', () {
    // Baked in from the region the user picked. Parsing it back out of the
    // staged filenames on the device would be a second source of truth.
    final src = File('assets/trampoline.sh.template').readAsStringSync();
    expect(src, contains('TILES_REGION="{{TILES_REGION}}"'));
    expect(src, contains('TILES_REGION_NAME="{{TILES_REGION_NAME}}"'));
    expect(src, contains(r'\\"region\\":\\"$TILES_REGION\\"'),
        reason: 'the region is not written into metadata.json');
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
      // busybox applets used to read back what was installed
      'sha256sum', 'stat', 'cut',
      // shipped explicitly by the bootstrap recipe
      'mender-update',
      // also shipped by the bootstrap recipe, for unpacking .tar.zst routing
      // tiles while the dashboard still runs it
      'zstd',
    };

    final source = File('assets/trampoline.sh.template').readAsStringSync();
    // The command argument may itself contain quotes, escaped or nested, so
    // the capture cannot stop at the first one. An earlier version did, and
    // silently checked only the leading word of any command that quoted an
    // argument, which let three unverified binaries through.
    final re = RegExp(
        r"""dbc_ssh(?:_bounded)?\s+(?:\d+\s+)?(["'])((?:\\.|(?!\1)[\s\S])*)\1""");
    final calls = re.allMatches(source).map((m) => m.group(2)!).toList();
    expect(calls, isNotEmpty, reason: 'no dashboard commands found to check');

    final unknown = <String>{};
    for (final c in calls) {
      // A nested single-quoted segment is an argument, not a command list:
      // fw_setenv stores a whole U-Boot script that way, and its `fuse` and
      // `ums` are U-Boot builtins that never run as binaries here. Drop those
      // segments before splitting, or the check reports words it invented.
      final flat = c.replaceAll(RegExp(r"'[^']*'"), ' ');
      for (final part in flat.split(RegExp(r'[;&|]'))) {
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
