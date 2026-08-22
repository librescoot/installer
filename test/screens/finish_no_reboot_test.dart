import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The laptop-attended finish hands the vehicle back without rebooting it.
///
/// A reboot comes back locked and dark, which is the opposite of the signal
/// the end of an install should give. Everything the reboot used to restore is
/// done directly instead: librescoot-pm is started (every connect stops it and
/// nothing else starts it again), vehicle-service is restarted so it re-claims
/// the blinker PWM channels the progress bar borrowed, usb0-policy goes back to
/// auto, and the scooter unlocks.
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
    expect(finish, contains('systemctl start librescoot-pm'),
        reason: 'pm-service is stopped on every connect and started nowhere '
            'else, so without this the scooter never suspends again');
    expect(finish, contains('systemctl restart librescoot-vehicle'),
        reason: 'vehicle-service has to re-claim the blinker PWM channels, '
            'which are left deactivated by the progress bar');
    expect(finish, contains('lsc set scooter.usb0-policy auto'),
        reason: 'usb0-policy is forced to always-on at connect');
  });

  test('the attended finish unlocks the scooter as its success signal', () {
    expect(finish, contains('lpush scooter:state unlock'),
        reason: 'a scooter that unlocks itself is the signal the install '
            'worked; an LED the owner has to interpret is not');
  });

  test('the policy change and the unlock survive the gadget teardown', () {
    // Setting usb0-policy=auto makes vehicle-service tear down the USB gadget
    // synchronously, which is the SSH transport the command arrived on. A
    // command that is not detached dies there, taking the unlock with it.
    final policyLine = finish.indexOf('lsc set scooter.usb0-policy auto');
    final nohup = finish.lastIndexOf('nohup', policyLine);
    expect(nohup, isNot(-1),
        reason: 'the policy reset and unlock must run in a detached shell, '
            'or the gadget teardown kills them mid-flight');
  });
}
