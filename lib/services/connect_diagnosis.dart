import 'dart:async';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';

import '../models/connect_failure.dart';
import 'network_service.dart';
import 'usb_detector.dart';

/// Work out which of [ConnectFailureKind] the connect phase ran into.
///
/// [error] is null for the one failure that never throws: the wait for a USB
/// device that nothing ever answers.
///
/// [usbDevicePresent] is whether a device is on the bus right now, and
/// [usbDeviceSeen] whether one was there earlier in this attempt. Together
/// they separate a cable nobody plugged in from a board that walked away.
ConnectFailureKind classifyConnectFailure({
  required Object? error,
  required String platform,
  required bool usbDevicePresent,
  required bool usbDeviceSeen,
}) {
  // The USB device is the premise for everything below it. A socket error
  // reported against a board that is no longer on the bus sends the user to
  // look at the network for what is a cable problem.
  if (!usbDevicePresent) {
    return usbDeviceSeen
        ? ConnectFailureKind.deviceVanished
        : ConnectFailureKind.noUsbDevice;
  }
  if (error == null) return ConnectFailureKind.unknown;

  // The SSH-typed errors first: dartssh2 wraps the socket, so a drop during
  // the handshake arrives as one of these rather than as a SocketException.
  if (error is SSHAuthFailError) return ConnectFailureKind.authRejected;
  if (error is SSHAuthAbortError) return ConnectFailureKind.linkDropped;

  final code = error is SocketException ? error.osError?.errorCode : null;
  if (NetworkService.isNoRouteToHostCode(code, platform: platform)) {
    // Only macOS has a permission that produces this while ping still works,
    // and it has its own screen. Elsewhere the same errno is a plain routing
    // failure, and sending a Linux user to a macOS setting is nonsense.
    return platform == 'macos'
        ? ConnectFailureKind.localNetworkBlocked
        : ConnectFailureKind.noRoute;
  }
  if (NetworkService.isConnectionRefusedCode(code, platform: platform)) {
    return ConnectFailureKind.sshRefused;
  }
  if (error is TimeoutException ||
      NetworkService.isTimedOutCode(code, platform: platform) ||
      _says(error, 'timed out')) {
    return ConnectFailureKind.sshTimeout;
  }
  // The wording sshd and the socket layer use when the far end goes away
  // mid-connect, plus the one this app raises for a session that died under
  // a command it had already started.
  if (_says(error, 'connection closed before authentication') ||
      _says(error, 'connection reset') ||
      _says(error, 'software caused connection abort') ||
      _says(error, 'ssh session lost')) {
    return ConnectFailureKind.linkDropped;
  }
  return ConnectFailureKind.unknown;
}

bool _says(Object error, String needle) =>
    error.toString().toLowerCase().contains(needle);

/// The block the user copies into a bug report.
///
/// Deliberately not translated and deliberately more than the exception: the
/// same message means different things depending on which platform raised it
/// and whether the board was on the bus at the time.
String describeConnectFailureForSupport({
  required ConnectFailureKind kind,
  required Object? error,
  required String platform,
  required String platformVersion,
  UsbDevice? device,
}) {
  final b = StringBuffer();
  b.writeln('Phase:    MDB connect');
  b.writeln('Verdict:  ${kind.name}');
  b.writeln('Platform: $platform $platformVersion');
  b.writeln(
    'USB:      ${device == null ? 'no device on the bus' : _describeDevice(device)}',
  );
  if (error == null) {
    b.write('Error:    none, the wait for a USB device ran out');
  } else {
    b.write('Error:    ${error.runtimeType}: $error');
  }
  return b.toString();
}

String _describeDevice(UsbDevice device) {
  final vid = device.vendorId.toRadixString(16).padLeft(4, '0');
  final pid = device.productId.toRadixString(16).padLeft(4, '0');
  return '${device.name} ($vid:$pid, ${device.mode.name})';
}
