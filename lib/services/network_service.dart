import 'dart:io';
import 'package:flutter/foundation.dart';

/// Network interface information
class NetworkInterface {
  final String name;
  final String displayName;
  final String? ipAddress;
  final bool isUp;

  NetworkInterface({
    required this.name,
    required this.displayName,
    this.ipAddress,
    this.isUp = false,
  });

  @override
  String toString() => 'NetworkInterface($displayName, ip=$ipAddress, up=$isUp)';
}

/// Service for configuring network interfaces to communicate with MDB
class NetworkService {
  static const String targetIp = '192.168.7.50';
  static const String subnetMask = '255.255.255.0';
  static const String mdbIp = '192.168.7.1';

  /// Find the network interface for the LibreScoot USB ethernet device
  Future<NetworkInterface?> findLibreScootInterface() async {
    NetworkInterface? iface;
    if (Platform.isWindows) {
      iface = await _findWindowsInterface();
    } else if (Platform.isMacOS) {
      iface = await _findMacOSInterface();
    } else if (Platform.isLinux) {
      iface = await _findLinuxInterface();
    }
    debugPrint('Network: findLibreScootInterface => $iface');
    return iface;
  }

  /// Configure the interface with a static IP for MDB communication
  Future<bool> configureInterface(NetworkInterface iface) async {
    debugPrint('Network: configureInterface(${iface.name}, ${iface.displayName})');
    // If MDB is already reachable, network is effectively configured.
    // Avoid reconfiguring and requiring admin privileges unnecessarily.
    if (await isMdbReachable()) {
      debugPrint('Network: MDB already reachable, skipping config');
      return true;
    }

    bool result = false;
    if (Platform.isWindows) {
      result = await _configureWindows(iface);
    } else if (Platform.isMacOS) {
      result = await _configureMacOS(iface);
    } else if (Platform.isLinux) {
      result = await _configureLinux(iface);
    }
    debugPrint('Network: configureInterface result=$result');
    return result;
  }

  /// Check if MDB is reachable
  Future<bool> isMdbReachable() async {
    try {
      final result = await Process.run(
        'ping',
        Platform.isWindows ? ['-n', '1', '-w', '1000', mdbIp] : ['-c', '1', '-W', '1', mdbIp],
      );
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<NetworkInterface?> _findWindowsInterface() async {
    try {
      // Use PowerShell to find RNDIS network adapter — avoids cmd.exe '&'
      // escaping issues with wmic.
      final result = await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-Command',
          r'''
$dev = Get-CimInstance Win32_NetworkAdapter | Where-Object { $_.PNPDeviceID -like "*VID_0525&PID_A4A2*" } | Select-Object -First 1 Name,NetConnectionID,NetEnabled
if ($dev) { "$($dev.Name)`t$($dev.NetConnectionID)`t$($dev.NetEnabled)" }
''',
        ],
      );

      if (result.exitCode != 0) return null;

      final line = result.stdout.toString().trim();
      if (line.isEmpty) return null;

      final parts = line.split('\t');
      final name = parts.isNotEmpty ? parts[0].trim() : 'USB Ethernet';
      final netConn = parts.length > 1 ? parts[1].trim() : '';
      final isUp = parts.length > 2 && parts[2].trim().toLowerCase() == 'true';

      return NetworkInterface(
        name: netConn,
        displayName: name,
        isUp: isUp,
      );
    } catch (_) {}
    return null;
  }

  Future<bool> _configureWindows(NetworkInterface iface) async {
    try {
      debugPrint('Network: netsh set address name="${iface.name}" static $targetIp $subnetMask');
      // Use netsh to set static IP
      final result = await Process.run(
        'netsh',
        [
          'interface',
          'ip',
          'set',
          'address',
          'name=${iface.name}',
          'static',
          targetIp,
          subnetMask,
        ],
      );

      debugPrint('Network: netsh exit=${result.exitCode} stdout=${result.stdout} stderr=${result.stderr}');

      if (result.exitCode != 0) {
        debugPrint('Network: netsh failed: ${result.stderr}');
        return false;
      }

      // Wait for interface to come up
      await Future.delayed(const Duration(seconds: 5));

      final reachable = await isMdbReachable();
      debugPrint('Network: MDB reachable after config: $reachable');
      return reachable;
    } catch (e) {
      debugPrint('Network: Failed to configure Windows interface: $e');
      return false;
    }
  }

  Future<NetworkInterface?> _findMacOSInterface() async {
    try {
      // List network services
      final result = await Process.run('networksetup', ['-listallhardwareports']);

      if (result.exitCode != 0) return null;

      final output = result.stdout.toString();
      final lines = output.split('\n');

      // Look for USB or RNDIS interface
      String? currentPort;
      String? currentDevice;

      for (final line in lines) {
        if (line.startsWith('Hardware Port:')) {
          currentPort = line.substring('Hardware Port:'.length).trim();
        } else if (line.startsWith('Device:')) {
          currentDevice = line.substring('Device:'.length).trim();

          // Check if this looks like the USB ethernet
          if (currentPort != null &&
              (currentPort.toLowerCase().contains('usb') ||
                  currentPort.toLowerCase().contains('rndis') ||
                  currentDevice.startsWith('en') && await _isUsbInterface(currentDevice))) {
            return NetworkInterface(
              name: currentDevice,
              displayName: currentPort,
            );
          }
        }
      }

      // Fallback: look for any new interface
      return _findMacOSNewInterface();
    } catch (_) {}
    return null;
  }

  Future<bool> _isUsbInterface(String device) async {
    try {
      final result = await Process.run('ifconfig', [device]);
      if (result.exitCode != 0) return false;

      // Check if it's up but has no IP (likely our device)
      final output = result.stdout.toString();
      return output.contains('status: active') && !output.contains('inet ');
    } catch (_) {
      return false;
    }
  }

  Future<NetworkInterface?> _findMacOSNewInterface() async {
    try {
      // Get list of interfaces without IPs
      final result = await Process.run('ifconfig', ['-a']);
      if (result.exitCode != 0) return null;

      final output = result.stdout.toString();
      final interfaces = <String>[];

      // Parse ifconfig output
      String? currentInterface;
      for (final line in output.split('\n')) {
        if (line.isNotEmpty && !line.startsWith('\t') && !line.startsWith(' ')) {
          final match = RegExp(r'^(\w+):').firstMatch(line);
          if (match != null) {
            currentInterface = match.group(1);
          }
        } else if (currentInterface != null &&
            line.contains('status: active') &&
            !output.contains('inet ') &&
            currentInterface.startsWith('en')) {
          interfaces.add(currentInterface);
        }
      }

      if (interfaces.isNotEmpty) {
        // Pick the highest numbered en interface (likely the newest)
        interfaces.sort();
        final iface = interfaces.last;
        return NetworkInterface(
          name: iface,
          displayName: 'USB Ethernet ($iface)',
        );
      }
    } catch (_) {}
    return null;
  }

  Future<bool> _configureMacOS(NetworkInterface iface) async {
    try {
      // If already configured correctly and reachable, don't reconfigure.
      if (await _isMacOSInterfaceConfigured(iface.name) && await isMdbReachable()) {
        return true;
      }

      // First, try to find the network service name
      final serviceResult = await Process.run('networksetup', ['-listallhardwareports']);
      String? serviceName;

      if (serviceResult.exitCode == 0) {
        final lines = serviceResult.stdout.toString().split('\n');
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].contains('Device: ${iface.name}') && i > 0) {
            final portLine = lines[i - 1];
            if (portLine.startsWith('Hardware Port:')) {
              serviceName = portLine.substring('Hardware Port:'.length).trim();
              break;
            }
          }
        }
      }

      if (serviceName != null) {
        // Use networksetup for named services
        final result = await Process.run(
          'networksetup',
          ['-setmanual', serviceName, targetIp, subnetMask],
        );

        if (result.exitCode == 0) {
          await Future.delayed(const Duration(seconds: 2));
          return await isMdbReachable();
        }
      }

      // Fallback: use ifconfig directly
      final result = await Process.run(
        'ifconfig',
        [iface.name, 'inet', targetIp, 'netmask', subnetMask],
      );

      if (result.exitCode != 0) {
        print('ifconfig failed: ${result.stderr}');
        return false;
      }

      await Future.delayed(const Duration(seconds: 2));
      return await isMdbReachable();
    } catch (e) {
      print('Failed to configure macOS interface: $e');
      return false;
    }
  }

  Future<bool> _isMacOSInterfaceConfigured(String interfaceName) async {
    try {
      final result = await Process.run('ifconfig', [interfaceName]);
      if (result.exitCode != 0) return false;

      final output = result.stdout.toString();
      return output.contains('inet $targetIp');
    } catch (_) {
      return false;
    }
  }

  Future<NetworkInterface?> _findLinuxInterface() async {
    try {
      // Look for USB ethernet interface
      final result = await Process.run('ip', ['link', 'show']);
      if (result.exitCode != 0) return null;

      final output = result.stdout.toString();

      // Find interfaces that might be USB ethernet (typically usb0 or enp0s*)
      for (final pattern in ['usb0', 'enp', 'enx']) {
        final match = RegExp('\\d+: ($pattern\\w+):').firstMatch(output);
        if (match != null) {
          final name = match.group(1)!;
          // Verify it's a USB device
          final check = await Process.run('ls', ['/sys/class/net/$name/device/driver']);
          if (check.exitCode == 0 && check.stdout.toString().contains('cdc_ether')) {
            return NetworkInterface(
              name: name,
              displayName: 'USB Ethernet ($name)',
            );
          }
        }
      }
    } catch (_) {}
    return null;
  }

  Future<bool> _configureLinux(NetworkInterface iface) async {
    try {
      // Bring interface up
      var result = await Process.run('ip', ['link', 'set', iface.name, 'up']);
      if (result.exitCode != 0) {
        print('ip link set up failed: ${result.stderr}');
        return false;
      }

      // Set IP address
      result = await Process.run(
        'ip',
        ['addr', 'add', '$targetIp/24', 'dev', iface.name],
      );

      // Ignore error if address already exists
      if (result.exitCode != 0 && !result.stderr.toString().contains('RTNETLINK answers: File exists')) {
        print('ip addr add failed: ${result.stderr}');
        return false;
      }

      await Future.delayed(const Duration(seconds: 2));
      return await isMdbReachable();
    } catch (e) {
      print('Failed to configure Linux interface: $e');
      return false;
    }
  }

  String _sanitizeOutput(String output) {
    return output
        .replaceAll('\u0000', '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
  }
}
