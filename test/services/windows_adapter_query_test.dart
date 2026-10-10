import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/network_service.dart';
import 'package:librescoot_installer/services/usb_detector.dart';
import 'package:librescoot_installer/services/windows_adapter_probe.dart';

String? _powerShell() {
  if (Platform.isWindows) return 'powershell';
  final path = '/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe';
  if (File(path).existsSync()) return path;
  return null;
}

void main() {
  final executable = _powerShell();
  final fixtures = <String, (String, int?)>{
    'single current adapter': (
      "@( [pscustomobject]@{ Name='Ethernet 12'; InterfaceDescription='USB gadget'; Status='Up'; ifIndex=42; PnPDeviceID='USB\\VID_0525&PID_A4A2\\SYNTHETIC' })",
      42,
    ),
    'historical adapter ignored': (
      "@( [pscustomobject]@{ Name='Ethernet'; InterfaceDescription='ghost'; Status='Not Present'; ifIndex=17; PnPDeviceID='USB\\VID_0525&PID_A4A2\\OLD' }, [pscustomobject]@{ Name='Ethernet 12'; InterfaceDescription='USB gadget'; Status='Up'; ifIndex=42; PnPDeviceID='USB\\VID_0525&PID_A4A2\\CURRENT' })",
      42,
    ),
    'multiple connected scooters refused': (
      "@( [pscustomobject]@{ Name='Ethernet 12'; Status='Up'; ifIndex=42; PnPDeviceID='USB\\VID_0525&PID_A4A2\\FIRST' }, [pscustomobject]@{ Name='Ethernet 13'; Status='Up'; ifIndex=43; PnPDeviceID='USB\\VID_0525&PID_A4A2\\SECOND' })",
      null,
    ),
    'unrelated adapter refused': (
      "@( [pscustomobject]@{ Name='LAN'; Status='Up'; ifIndex=42; PnPDeviceID='PCI\\SYNTHETIC' })",
      null,
    ),
  };
  for (final fixture in fixtures.entries) {
    test(fixture.key, () async {
      final script =
          'function Get-NetAdapter { ${fixture.value.$1} }\n$windowsGadgetAdapterQuery';
      final bytes = <int>[];
      for (final unit in script.codeUnits) {
        bytes.addAll([unit & 255, unit >> 8]);
      }
      final result = await runBounded(executable!, [
        '-NoProfile',
        '-NonInteractive',
        '-EncodedCommand',
        base64Encode(bytes),
      ], timeout: const Duration(seconds: 20));
      expect(result.exitCode, 0, reason: result.stderr.toString());
      final adapter = NetworkService.parseWindowsAdapter(
        result.stdout.toString(),
      );
      expect(adapter?.index, fixture.value.$2);
    }, skip: executable == null);
  }
}
