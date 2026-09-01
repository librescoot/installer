import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The laptop never reboots the MDB. It hands off to the coordinator, which
/// owns the run's single reboot and the handover after it.
///
/// The MDB stays on the bootstrap image for the whole attended phase, so an
/// artifact written to slot B is not live until something reboots. That reboot
/// is 80-reboot.sh, on the board, and 90-finalize.sh runs on the far side of
/// it: librescoot-pm is started (every connect stops it and nothing else
/// starts it again), vehicle-service is restarted so it re-claims the blinker
/// PWM channels the progress bar borrowed, usb0-policy goes back to auto, and
/// the scooter unlocks.
///
/// The unlock is still the success signal, and it is still the last thing to
/// happen; what changed is that the vehicle is on its real image by then.
void main() {
  late String finish;

  setUpAll(() {
    final source =
        File('lib/screens/installer_screen.dart').readAsStringSync();
    final start = source.indexOf('Future<void> _onEnterFinish() async {');
    expect(start, isNot(-1), reason: '_onEnterFinish not found');
    // Runs to the next method at the same indentation, which is the doc
    // comment that introduces _deviceReportedFinished.
    final end = source.indexOf('\n  /// Whether the device wrote', start);
    expect(end, isNot(-1), reason: 'could not find the end of _onEnterFinish');
    // Comments in here legitimately discuss rebooting; only the code is
    // under test, so the prose goes before anything is matched.
    finish = source
        .substring(start, end)
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');
  });

  test('the attended finish does not reboot the MDB', () {
    // `reboot` as a command word, so identifiers that merely contain it do
    // not trip the match.
    final rebootCall = RegExp(r"[;'\s]reboot\b");
    expect(
      rebootCall.hasMatch(finish),
      isFalse,
      reason: 'the finish sends a reboot; it should restore services and '
          'unlock instead, the way the trampoline finish does',
    );
  });

  test('the attended finish restores what the install stopped', () {
    // The work is 90-finalize.sh, and the coordinator runs it either way now.
    // What this checks is that a run which never handed off to the trampoline
    // still queues every phase it needs and then starts the coordinator, or a
    // dashboard-less plan would stage an artifact and never install it.
    expect(finish, contains('FinalizeScript.render('),
        reason: 'the finish has to stage the phase it hands off to');
    expect(finish, contains('MdbArtifactScript.render('),
        reason: 'a run with no trampoline still has to install the artifact');
    expect(finish, contains('RebootPhaseScript.render('),
        reason: 'and still has to activate it');
    expect(finish, contains('startInstallPhasesDetached()'),
        reason: 'usb0-policy is forced to always-on at connect, so something '
            'has to put the vehicle back');
    final finalize = File('assets/finalize.sh.template').readAsStringSync();
    expect(finalize, contains('systemctl start librescoot-pm'),
        reason: 'pm-service is stopped on every connect and started nowhere '
            'else, so without this the scooter never suspends again');
    expect(finalize, contains('systemctl restart librescoot-vehicle'),
        reason: 'vehicle-service has to re-claim the blinker PWM channels, '
            'which are left deactivated by the progress bar');
  });

  test('the attended finish unlocks the scooter as its success signal', () {
    final finalize = File('assets/finalize.sh.template').readAsStringSync();
    expect(finalize, contains('lpush scooter:state unlock'),
        reason: 'a scooter that unlocks itself is the signal the install '
            'worked; an LED the owner has to interpret is not');
  });

  test('the handover survives everything it takes down', () {
    // Three things sever the link in turn: the reboot in 80-reboot.sh, and
    // then restoring usb0-policy in 90-finalize.sh, which makes
    // vehicle-service tear down the USB gadget synchronously. A handoff that
    // is not detached dies at the first of them and takes the rest with it.
    final source = File('lib/services/ssh_service.dart').readAsStringSync();
    final start =
        source.indexOf('Future<void> startInstallPhasesDetached() async {');
    expect(start, isNot(-1), reason: 'startInstallPhasesDetached not found');
    final body = source.substring(start, source.indexOf('\n  }', start));
    expect(body, contains('systemd-run'),
        reason: 'the phases outlive this session, so they need their own unit');
    expect(body, contains('nohup'),
        reason: 'and a fallback for a board where systemd-run will not start');
    expect(body, contains('onboot.sh'));
  });

  test('the coordinator is installed where phases are queued, not earlier', () {
    // It was installed from _startPlan, which runs before the bootstrap flash.
    // On the stock image that write fails outright ("mkdir: cannot create
    // directory '/data': Operation not permitted") and a clean install
    // reformats /data anyway, so the coordinator was never on the board that
    // needed it. Both places that queue phases run after the flash.
    final source = File('lib/screens/installer_screen.dart').readAsStringSync();
    final tramp =
        File('lib/services/trampoline_service.dart').readAsStringSync();

    final calls = RegExp(r'installOnbootShim\(\)').allMatches(source).length +
        RegExp(r'installOnbootShim\(\)').allMatches(tramp).length;
    expect(calls, 1, reason: 'one definition, so it cannot drift');
    expect(source,
        contains('Future<void> _armInstallPhases({required bool expectDbcPhase})'));

    final planStart = source.indexOf('Future<void> _startPlan() async {');
    final planEnd = source.indexOf('\n  /// ', planStart);
    expect(source.substring(planStart, planEnd),
        isNot(contains('installOnbootShim')),
        reason: '_startPlan is before the flash that wipes /data');

    // Armed on both routes: a dashboard-less plan never reaches the trampoline.
    expect(
        RegExp(r'await _armInstallPhases\(\n?\s*expectDbcPhase:')
            .allMatches(source)
            .length,
        2,
        reason: 'both queueing paths have to arm it');

    // Only the trampoline writes 20-dbc.sh. The handover arms the coordinator
    // a second time, and a run whose trampoline never started has nobody left
    // to write it: declaring it there ends the run on "install phases never
    // ran: 20-dbc.sh" while everything that did run went fine.
    expect(
        source,
        contains('expectDbcPhase: (_plan?.needsHandoff ?? false) && '
            '_deviceFinishArmed'),
        reason: 'the handover expects the dashboard phase only from a run '
            'that reached the trampoline');
  });
}
