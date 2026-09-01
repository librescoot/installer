import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/network_service.dart';

void main() {
  group('isLinkNotReady', () {
    test('no route counts', () {
      expect(
        NetworkService.isLinkNotReady(
          const SocketException(
            'Connection failed',
            osError: OSError('No route to host', 65),
          ),
        ),
        // Only true on a Darwin host; elsewhere 65 is some other errno.
        Platform.isMacOS,
      );
    });

    // The interface can be published after the configure pass ran, leaving a
    // stale route that swallows the packets instead of refusing them.
    test('a connect timeout counts', () {
      expect(
        NetworkService.isLinkNotReady(
          const SocketException('Connection timed out'),
        ),
        isTrue,
      );
      expect(
        NetworkService.isLinkNotReady(TimeoutException('nope')),
        isTrue,
      );
    });

    test('a refused connection does not', () {
      expect(
        NetworkService.isLinkNotReady(
          const SocketException(
            'Connection refused',
            osError: OSError('Connection refused', 61),
          ),
        ),
        isFalse,
      );
    });
  });

  group('EHOSTUNREACH is per-platform', () {
    test('Darwin uses 65', () {
      expect(
        NetworkService.isNoRouteToHostCode(65, platform: 'macos'),
        isTrue,
      );
      expect(
        NetworkService.isNoRouteToHostCode(113, platform: 'macos'),
        isFalse,
      );
    });

    test('Linux uses 113', () {
      expect(
        NetworkService.isNoRouteToHostCode(113, platform: 'linux'),
        isTrue,
      );
      // 65 is ENOPKG on Linux, nothing to do with routing.
      expect(
        NetworkService.isNoRouteToHostCode(65, platform: 'linux'),
        isFalse,
      );
    });

    test('Windows uses WSAEHOSTUNREACH', () {
      expect(
        NetworkService.isNoRouteToHostCode(10065, platform: 'windows'),
        isTrue,
      );
      expect(
        NetworkService.isNoRouteToHostCode(65, platform: 'windows'),
        isFalse,
      );
    });

    test('a missing OS error is not a routing failure', () {
      expect(
        NetworkService.isNoRouteToHostCode(null, platform: 'macos'),
        isFalse,
      );
    });

    // Dart reports its own connect timeout as errno 110 on every platform,
    // including macOS where ETIMEDOUT is 60. Reading that as a routing
    // failure would send every slow board down the Local Network path.
    test('Dart\'s synthetic connect timeout is not a routing failure', () {
      expect(
        NetworkService.isNoRouteToHostCode(110, platform: 'macos'),
        isFalse,
      );
    });

    test('other errnos are left alone', () {
      // ECONNREFUSED: sshd is not up yet, which a retry does fix.
      expect(
        NetworkService.isNoRouteToHostCode(61, platform: 'macos'),
        isFalse,
      );
      // ETIMEDOUT.
      expect(
        NetworkService.isNoRouteToHostCode(60, platform: 'macos'),
        isFalse,
      );
    });
  });
}
