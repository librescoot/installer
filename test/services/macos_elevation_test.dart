import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/elevation_service.dart';
import 'package:librescoot_installer/services/flash_service.dart';

void main() {
  final network = File('lib/services/network_service.dart').readAsStringSync();
  final macos = network.substring(
    network.indexOf(
      'Future<bool> _configureMacOS(NetworkInterface iface) async {',
    ),
    network.indexOf('Future<bool> _isMacOSInterfaceConfigured('),
  );

  group('macOS network config asks for the password it needs', () {
    test('it elevates rather than telling the user to relaunch', () {
      expect(macos, contains('ElevationService.macOSRootPrefix('));
      expect(macos, isNot(contains('relaunch the installer with: sudo')));
    });

    test('the surviving relaunch advice is Linux only', () {
      final source = File(
        'lib/services/network_service.dart',
      ).readAsStringSync();
      String body(String signature, String until) {
        final start = source.indexOf(signature);
        expect(start, greaterThan(-1), reason: signature);
        final end = source.indexOf(until, start + signature.length);
        expect(end, greaterThan(-1), reason: until);
        return source.substring(start, end);
      }

      const advice = 'relaunch the installer with: sudo';
      final linux = body(
        'Future<bool> _configureLinux(',
        'Future<bool> _isNetworkManagerActive(',
      );
      final mac = body(
        'Future<bool> _configureMacOS(',
        'Future<bool> _isMacOSInterfaceConfigured(',
      );

      expect(linux, contains(advice));
      expect(mac, isNot(contains(advice)));
      expect(advice.allMatches(source).length, advice.allMatches(linux).length);
    });

    test('it does not ask to be told the address is already set', () {
      final probe = macos.indexOf('_isMacOSInterfaceConfigured(iface.name)) {');
      final elevate = macos.indexOf('macOSRootPrefix(');
      expect(probe, greaterThan(-1));
      expect(probe, lessThan(elevate));
    });

    test('missing elevation fails before running the sentinel shell', () {
      final missing = macos.indexOf('if (root == null) {');
      final process = macos.indexOf(
        'final result = await runBounded(',
        missing,
      );
      expect(missing, greaterThan(-1));
      expect(process, greaterThan(missing));
      expect(
        macos.substring(missing, process),
        contains('throw const NetworkPrivilegeException'),
      );
      expect(macos.substring(missing, process), isNot(contains('argv.first')));
    });
  });

  group('one askpass helper, used by both callers', () {
    test('the flash and the network share the script', () {
      final flash = File('lib/services/flash_service.dart').readAsStringSync();
      expect(flash, contains('ElevationService.macOsAskpassScript('));
      expect(
        FlashService.macOsAskpassScript,
        ElevationService.macOsAskpassScript('to write to the card'),
      );
    });

    test('the reason is what changes, not the mechanism', () {
      final flash = ElevationService.macOsAskpassScript('to write to the card');
      final net = ElevationService.macOsAskpassScript(
        'to set up the USB network',
      );
      expect(flash, contains('to write to the card'));
      expect(net, contains('to set up the USB network'));
      for (final script in [flash, net]) {
        expect(script, startsWith('#!/bin/sh\n'));
        expect(script, contains('with hidden answer'));
        expect(script, contains('text returned of result'));
      }
    });

    test('sudo receives the helper environment', () {
      final elevation = File(
        'lib/services/elevation_service.dart',
      ).readAsStringSync();
      expect(elevation, contains("'SUDO_ASKPASS': askpass"));
    });

    test('the helper is written somewhere another user cannot pre-create', () {
      final elevation = File(
        'lib/services/elevation_service.dart',
      ).readAsStringSync();
      expect(elevation, contains("createTemp('librescoot_askpass_')"));
      expect(elevation, contains("chmod', ['0700'"));
    });
  });

  group('a refusal is heard once, not asked again every poll', () {
    final network = File(
      'lib/services/network_service.dart',
    ).readAsStringSync();

    test('both platforms decide on the sentinel, not on stderr wording', () {
      expect(network, isNot(contains("contains('permission denied')")));
      expect(
        RegExp('const ran = elevationSentinel').allMatches(network).length,
        2,
        reason: 'the macOS and Linux paths both use it',
      );
    });

    test('a declined prompt is remembered', () {
      expect(network, contains('static bool _elevationDeclined = false;'));
      expect(
        RegExp(r'_elevationDeclined = true').allMatches(network).length,
        greaterThanOrEqualTo(2),
        reason: 'both platforms record the refusal',
      );
      expect(
        RegExp(r'if \(_elevationDeclined\)').allMatches(network).length,
        greaterThanOrEqualTo(2),
        reason: 'and both check it before prompting',
      );
    });

    test('only an explicit retry may ask again', () {
      final screen = File(
        'lib/screens/installer_screen.dart',
      ).readAsStringSync();
      expect(network, contains('static void allowElevationPromptAgain()'));
      final calls = RegExp(r'allowElevationPromptAgain\(\)').allMatches(screen);
      expect(calls.length, greaterThanOrEqualTo(4));
      final retry = screen.substring(
        screen.indexOf('void _retryMdbConnect() {'),
        screen.indexOf('ConnectFailure _describeConnectFailure('),
      );
      expect(retry, contains('allowElevationPromptAgain()'));
    });

    test('the blocked panel offers a way back once nothing is watching', () {
      final screen = File(
        'lib/screens/installer_screen.dart',
      ).readAsStringSync();
      expect(screen, contains('bool get _noRouteWatchSpent'));
      expect(screen, contains('if (_noRouteWatchSpent)'));
    });
  });
}
