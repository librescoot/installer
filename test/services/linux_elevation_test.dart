import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/elevation_service.dart';
import 'package:librescoot_installer/services/network_service.dart';

void main() {
  group('an interface name that reaches a shell', () {
    test('accepts what the kernel actually names interfaces', () {
      for (final name in [
        'usb0',
        'eth1',
        'enp0s20f0u1',
        'enx00e04c360033',
        'wlp3s0',
        'br-0',
      ]) {
        expect(NetworkService.isSafeInterfaceName(name), isTrue, reason: name);
      }
    });

    test('refuses anything that could carry a command with it', () {
      for (final name in [
        'usb0; rm -rf /',
        r'usb0$(id)',
        'usb0 && reboot',
        'usb0`id`',
        'usb0|sh',
        "usb0'",
        'usb0\nreboot',
        '',
        '-usb0',
        'usb0/../../etc',
      ]) {
        expect(NetworkService.isSafeInterfaceName(name), isFalse,
            reason: name);
      }
    });
  });

  group('the Linux root prefix', () {
    Future<bool> has(Set<String> present) async => false;

    test('already root needs no prefix at all', () async {
      final root = await ElevationService.linuxRootPrefix(
        isRoot: () async => true,
        hasCommandOverride: (_) async => true,
      );
      expect(root, isNotNull);
      expect(root!.isDirect, isTrue);
      expect(root.argv, isEmpty);
      expect(root.environment, isEmpty);
    });

    test('pkexec is preferred, because it raises the desktop own dialog',
        () async {
      final root = await ElevationService.linuxRootPrefix(
        isRoot: () async => false,
        hasCommandOverride: (name) async => name == 'pkexec' || name == 'sudo',
        findAskpass: () async => '/usr/bin/ssh-askpass',
      );
      expect(root!.argv, ['pkexec']);
      expect(root.environment, isEmpty,
          reason: 'pkexec needs no askpass of its own');
    });

    test('sudo is only offered with the askpass it needs', () async {
      final withAskpass = await ElevationService.linuxRootPrefix(
        isRoot: () async => false,
        hasCommandOverride: (name) async => name == 'sudo',
        findAskpass: () async => '/usr/bin/ssh-askpass',
      );
      expect(withAskpass!.argv, ['sudo', '-A']);
      expect(withAskpass.environment['SUDO_ASKPASS'], '/usr/bin/ssh-askpass');

      final without = await ElevationService.linuxRootPrefix(
        isRoot: () async => false,
        hasCommandOverride: (name) async => name == 'sudo',
        findAskpass: () async => null,
      );
      expect(without, isNull,
          reason: 'better to say we cannot ask than to hang asking');
    });

    test('a host with neither says so', () async {
      final root = await ElevationService.linuxRootPrefix(
        isRoot: () async => false,
        hasCommandOverride: (_) async => false,
        findAskpass: () async => null,
      );
      expect(root, isNull);
      expect(await has(const {}), isFalse);
    });

    test('hasCommand does not itself depend on which', () async {
      expect(await ElevationService.hasCommand('sh'), isTrue);
      expect(
        await ElevationService.hasCommand('definitely-not-a-real-binary-xyz'),
        isFalse,
      );
    });
  });

  group('configuring the interface asks for root instead of giving up', () {
    final source = File('lib/services/network_service.dart').readAsStringSync();
    final start = source.indexOf('Future<bool> _configureLinux(');
    final block = source.substring(start, source.indexOf('\n  Future<bool> _isNetworkManagerActive', start));

    test('it elevates rather than requiring an already-root process', () {
      expect(block, contains('ElevationService.linuxRootPrefix()'));
      expect(block, isNot(contains('_isLinuxRoot')));
    });

    test('the whole sequence runs under one elevation', () {
      expect('runBounded('.allMatches(block).length, 1);
      expect(block, contains('timeout: _privilegedCommandTimeout'));
    });

    test('a declined prompt is reported as such, not as a broken network', () {
      expect(block, contains('const ran = elevationSentinel'));
      expect(NetworkService.elevationSentinel, isNotEmpty);
      expect(block, contains(r"<String>['echo $ran']"));
      expect(block, contains('!result.stdout.toString().contains(ran)'));
      expect(block, contains('was not authorised'));
    });

    test('it does not ask for a password to learn what a read already says',
        () {
      final probe = source.indexOf('_isLinuxInterfaceConfigured(iface.name)');
      final elevate = source.indexOf('ElevationService.linuxRootPrefix()');
      expect(probe, greaterThan(-1));
      expect(probe, lessThan(elevate));
    });

    test('the unprivileged probe does not mistake LOWER_UP for UP', () {
      const addr = '192.168.7.50';
      const flags = '2: usb0: <BROADCAST,MULTICAST,%s> mtu 1500\n'
          '    inet 192.168.7.50/24 scope global usb0';
      expect(
        NetworkService.interfaceCarriesAddress(
            flags.replaceFirst('%s', 'UP,LOWER_UP'), addr),
        isTrue,
      );
      expect(
        NetworkService.interfaceCarriesAddress(
            flags.replaceFirst('%s', 'LOWER_UP'), addr),
        isFalse,
        reason: 'LOWER_UP contains UP but the link is down',
      );
      expect(
        NetworkService.interfaceCarriesAddress(
            '2: usb0: <BROADCAST,UP,LOWER_UP> mtu 1500', addr),
        isFalse,
        reason: 'up, but not carrying our address',
      );
      expect(
        NetworkService.interfaceCarriesAddress(
            flags.replaceFirst('%s', 'UP').replaceFirst('/24', '/16'), addr),
        isFalse,
        reason: 'a different prefix is a different configuration',
      );
    });
  });
}
