import 'dart:async';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/models/connect_failure.dart';
import 'package:librescoot_installer/services/connect_diagnosis.dart';
import 'package:librescoot_installer/services/usb_detector.dart';

SocketException _socket(String message, [int? code]) => SocketException(
      message,
      osError: code == null ? null : OSError(message, code),
    );

ConnectFailureKind _kind(
  Object? error, {
  String platform = 'linux',
  bool present = true,
  bool seen = true,
}) =>
    classifyConnectFailure(
      error: error,
      platform: platform,
      usbDevicePresent: present,
      usbDeviceSeen: seen,
    );

void main() {
  group('the USB device outranks the exception', () {
    test('nothing ever on the bus is a cable, not a network failure', () {
      // This one never throws: the phase waits for a device that does not
      // arrive. Reported as anything else it sends someone whose cable is in
      // the wrong port off to look at their network settings.
      expect(
        _kind(null, present: false, seen: false),
        ConnectFailureKind.noUsbDevice,
      );
    });

    test('a board that walked away is not a routing problem', () {
      // The scooter suspends on its own with no main battery in the front
      // slot and takes the USB device with it. The socket error it leaves
      // behind describes the symptom, and the errno branches below would
      // read it as the host misconfiguring an interface that is gone.
      expect(
        _kind(_socket('No route to host', 113), present: false),
        ConnectFailureKind.deviceVanished,
      );
    });

    test('a device on the bus is judged by the exception', () {
      expect(
        _kind(_socket('Connection refused', 111)),
        ConnectFailureKind.sshRefused,
      );
    });
  });

  group('EHOSTUNREACH means two different things', () {
    test('on macOS it is the Local Network permission', () {
      // The board answers pings there while the app is refused, which is the
      // one failure with a setting behind it rather than a cable.
      expect(
        _kind(_socket('No route to host', 65), platform: 'macos'),
        ConnectFailureKind.localNetworkBlocked,
      );
    });

    test('anywhere else it is an interface without the address on it', () {
      // Sending a Linux user to a macOS privacy pane is nonsense, and the
      // answer that does help them is NetworkManager.
      expect(
        _kind(_socket('No route to host', 113)),
        ConnectFailureKind.noRoute,
      );
      expect(
        _kind(_socket('No route to host', 10065), platform: 'windows'),
        ConnectFailureKind.noRoute,
      );
    });

    test('the Linux errno on macOS is not a routing failure at all', () {
      // 113 is ENOPKG on Darwin. Matching it there would put the permission
      // screen in front of someone whose permission is fine.
      expect(
        _kind(_socket('something else', 113), platform: 'macos'),
        ConnectFailureKind.unknown,
      );
    });
  });

  group('refused, silent and dropped are three different answers', () {
    test('a rejection proves the link works', () {
      for (final (platform, code) in const [
        ('macos', 61),
        ('linux', 111),
        ('windows', 10061),
      ]) {
        expect(
          _kind(_socket('Connection refused', code), platform: platform),
          ConnectFailureKind.sshRefused,
          reason: 'ECONNREFUSED on $platform',
        );
      }
    });

    test('a connect that ran out of time says so', () {
      expect(_kind(TimeoutException('authenticated')),
          ConnectFailureKind.sshTimeout);
      expect(_kind(_socket('Connection timed out')),
          ConnectFailureKind.sshTimeout);
    });

    test('Dart\'s own connect timeout is a timeout on every host', () {
      // Dart reports it as errno 110 everywhere, including macOS where
      // ETIMEDOUT is 60. Reading only the platform errno leaves the commoner
      // half of these classed as unknown.
      for (final platform in const ['macos', 'linux', 'windows']) {
        expect(
          _kind(_socket('Connection timed out', 110), platform: platform),
          ConnectFailureKind.sshTimeout,
          reason: 'the synthetic timeout on $platform',
        );
      }
      expect(
        _kind(_socket('Operation timed out', 60), platform: 'macos'),
        ConnectFailureKind.sshTimeout,
      );
    });

    test('a handshake that died mid-way is the board restarting', () {
      // dartssh2 raises this when the far end closes before authentication
      // finishes, which is what a rebooting board looks like. It arrives on
      // the same path as a rejected credential, and telling the user their
      // password is wrong would be a lie with a dead end attached.
      expect(
        _kind(SSHAuthAbortError('connection closed')),
        ConnectFailureKind.linkDropped,
      );
      expect(
        _kind(Exception('Connection closed before authentication')),
        ConnectFailureKind.linkDropped,
      );
      expect(
        _kind(Exception('SSH session lost during resume check')),
        ConnectFailureKind.linkDropped,
      );
    });

    test('a rejected credential is a rejected credential', () {
      expect(
        _kind(SSHAuthFailError('permission denied')),
        ConnectFailureKind.authRejected,
      );
    });

    test('anything unrecognised keeps its own kind', () {
      // The screen for this one leads with the technical details, so folding
      // it into a neighbour would put confident wrong advice in front of a
      // failure nobody has diagnosed yet.
      expect(_kind(Exception('the sky fell in')), ConnectFailureKind.unknown);
    });
  });

  group('which failures the screen keeps watching', () {
    test('the two that fix themselves offer no retry', () {
      // Both keep an attempt running behind the screen: the bus poll for one,
      // the timer for the other. A Retry button there restarts something that
      // never stopped, and reads as if nothing were happening until it is
      // pressed.
      expect(
        const ConnectFailure(kind: ConnectFailureKind.noUsbDevice).selfHealing,
        isTrue,
      );
      expect(
        const ConnectFailure(kind: ConnectFailureKind.localNetworkBlocked)
            .selfHealing,
        isTrue,
      );
    });

    test('everything else needs the user to press something', () {
      for (final kind in ConnectFailureKind.values) {
        if (kind == ConnectFailureKind.noUsbDevice ||
            kind == ConnectFailureKind.localNetworkBlocked) {
          continue;
        }
        expect(
          ConnectFailure(kind: kind).selfHealing,
          isFalse,
          reason: '$kind has nothing running behind it',
        );
      }
    });
  });

  group('the block that gets pasted into a bug report', () {
    test('it carries the verdict, the host and the exception', () {
      final text = describeConnectFailureForSupport(
        kind: ConnectFailureKind.sshTimeout,
        error: TimeoutException('authenticated'),
        platform: 'macos',
        platformVersion: 'Version 15.3',
        device: UsbDevice(
          id: 'usb-1',
          name: 'RNDIS/Ethernet Gadget',
          path: '/dev/null',
          vendorId: 0x0525,
          productId: 0xa4a2,
          mode: DeviceMode.ethernet,
        ),
      );
      // Whoever reads this in Discord has neither the screen nor the log, so
      // the verdict the installer reached has to travel with the exception.
      expect(text, contains('sshTimeout'));
      expect(text, contains('macos Version 15.3'));
      expect(text, contains('0525:a4a2'));
      expect(text, contains('TimeoutException'));
    });

    test('a missing device is stated, not left blank', () {
      // An empty USB line reads as a field the installer failed to fill in.
      // "No device on the bus" is the finding.
      final text = describeConnectFailureForSupport(
        kind: ConnectFailureKind.noUsbDevice,
        error: null,
        platform: 'windows',
        platformVersion: '10.0',
      );
      expect(text, contains('no device on the bus'));
      expect(text.toLowerCase(), contains('ran out'));
    });
  });
}
