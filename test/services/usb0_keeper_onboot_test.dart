import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/ssh_service.dart';

/// The reboot into the newly installed image is the one the installer cannot
/// watch: the image that comes up has vehicle-service, its default usb0 policy
/// follows dashboard_power, and the dashboard is off. This script is the only
/// thing on the far side of that reboot, so what it says is the whole
/// difference between a board that answers afterwards and one that does not.
void main() {
  const script = SshService.usb0KeeperOnboot;

  test('it is valid shell', () async {
    final dir = await Directory.systemTemp.createTemp('usb0-keeper-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/onboot.sh');
    await file.writeAsString(script);

    final syntax = await Process.run('sh', ['-n', file.path]);
    expect(syntax.exitCode, 0, reason: syntax.stderr.toString());
  });

  test('the shebang is the first thing in the file', () {
    // librescoot-onboot.service runs this as ExecStart, so a blank first line
    // costs the interpreter.
    expect(script, startsWith('#!/bin/sh\n'));
  });

  test('it raises the link before it waits for anything', () {
    // The policy call has to wait for settings-service, which is tens of
    // seconds into a boot. Raising the link first means the installer can
    // already reach the board while the rest of this is still waiting.
    final raise = script.indexOf('ip link set usb0 up');
    final wait = script.indexOf('systemctl is-active librescoot-settings');
    expect(raise, isNot(-1));
    expect(wait, greaterThan(raise));
  });

  test('it sets the policy that stops vehicle-service taking usb0 away', () {
    expect(script, contains('lsc set scooter.usb0-policy always-on'));
  });

  test('a board without lsc still gets its link raised', () {
    // A rolled-back board is back on stage 0: no lsc, no redis, and equally no
    // vehicle-service to lower usb0. Guarding the policy call keeps the script
    // from dying before the part that board does need.
    expect(script, contains('command -v lsc'));
    expect(
      script.indexOf('ip link set usb0 up'),
      lessThan(script.indexOf('command -v lsc')),
    );
  });

  test('it removes itself before anything that can block', () {
    // The trampoline backs up an onboot.sh it finds and puts it back when it
    // retires, so a keeper still sitting there at that point would return as a
    // permanent one and pin usb0-policy on every future boot.
    //
    // First, not last. Everything after it can block: the redis wait runs to a
    // minute, and systemd kills a oneshot that outruns its start timeout.
    // Removed last, a keeper killed there is still on disk and runs again on
    // the next boot, and the one after, on a scooter nobody is installing.
    final rm = script.indexOf('rm -f /data/onboot.sh');
    expect(rm, isNot(-1));
    expect(rm, lessThan(script.indexOf('systemctl is-active librescoot-settings')),
        reason: 'a blocking wait before the removal can strand the keeper');
    expect(rm, lessThan(script.indexOf('lsc set')));
  });

  test('nothing in it needs a heredoc to expand', () {
    // It is written through a quoted heredoc, so the board sees these
    // characters and not what the installer's shell would have made of them.
    // $i and $((i+1)) are read on the scooter, by this script, on purpose.
    expect(script, contains(r'$i'));
    expect(script, isNot(contains('{{')));
  });

  test('it waits for settings-service, not merely for redis', () {
    // redis answers early. settings-service starts later and stamps the whole
    // settings hash from its schema, erasing anything written before it. A
    // keeper that waited on redis set the policy one second too early, exited
    // 0, and changed nothing; vehicle-service read the default and took usb0
    // down four seconds later.
    expect(script, contains('systemctl is-active librescoot-settings'));
    expect(
      script.indexOf('systemctl is-active librescoot-settings'),
      lessThan(script.indexOf('lsc set scooter.usb0-policy')),
      reason: 'the policy is written before the thing that would erase it',
    );
  });

  test('it confirms the policy survived rather than assuming it', () {
    // The failure this fixes is a write that succeeded and did not last, so
    // the only honest check is reading it back.
    expect(script, contains('hget settings scooter.usb0-policy'));
    expect(
      script.indexOf('lsc set scooter.usb0-policy'),
      lessThan(script.indexOf('hget settings scooter.usb0-policy')),
    );
  });
}
