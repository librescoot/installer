import 'dart:async';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/ssh_service.dart';

void main() {
  group('SshService.isPreAuthDrop', () {
    test('a connection closed before authentication is a transport drop', () {
      expect(
          SshService.isPreAuthDrop(
              SSHAuthAbortError('Connection closed before authentication')),
          isTrue);
    });

    test('an unreachable or reset socket is a transport drop', () {
      expect(SshService.isPreAuthDrop(const SocketException('Connection reset')),
          isTrue);
    });

    test('a stalled handshake is a transport drop, not a bad password', () {
      // The far end accepts the socket and then says nothing. Without this the
      // timeout escalates the credential ladder and ends at a password prompt
      // for a device whose password was never in question.
      expect(SshService.isPreAuthDrop(TimeoutException('authenticated')),
          isTrue);
    });

    test('a rejected credential is not', () {
      // The credential ladder has to keep advancing for this one, all the way
      // to asking the user, or an unknown stock board can never be reached.
      expect(SshService.isPreAuthDrop(SSHAuthFailError('permission denied')),
          isFalse);
    });

    test('the retries outlast a reboot', () {
      final total = SshService.preAuthRetryDelay * SshService.maxPreAuthRetries;
      expect(total.inSeconds, greaterThanOrEqualTo(25));
    });

    test('a board that is ready is not left waiting', () {
      // The whole point of the constant interval: a pre-auth drop is a booting
      // board, so the gap between attempts is how long it can sit ready before
      // anyone asks. The old ladder ended on a 32-second step.
      expect(SshService.preAuthRetryDelay.inSeconds, lessThanOrEqualTo(5));
    });
  });
}
