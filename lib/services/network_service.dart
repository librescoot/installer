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

/// Thrown when configureInterface needs privileges we don't have.
/// The message is shown verbatim to the user, so it must be actionable.
class NetworkPrivilegeException implements Exception {
  final String message;
  const NetworkPrivilegeException(this.message);
  @override
  String toString() => message;
}

/// Service for configuring network interfaces to communicate with MDB
class NetworkService {
  static const String targetIp = '192.168.7.50';
  static const String subnetMask = '255.255.255.0';
  static const String mdbIp = '192.168.7.1';

  /// Find the network interface for the Librescoot USB ethernet device
  Future<NetworkInterface?> findLibrescootInterface() async {
    NetworkInterface? iface;
    if (Platform.isWindows) {
      iface = await _findWindowsInterface();
    } else if (Platform.isMacOS) {
      iface = await _findMacOSInterface();
    } else if (Platform.isLinux) {
      iface = await _findLinuxInterface();
    }
    debugPrint('Network: findLibrescootInterface => $iface');
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

  /// Linux-only diagnostic dump for the "ping never goes stable" path.
  /// Returns ip-addr/route info as a single string suitable for debugPrint.
  Future<String> gatherLinuxDiagnostics(String iface) async {
    if (!Platform.isLinux) return '';
    final buf = StringBuffer();
    try {
      final addr = await Process.run('ip', ['-4', 'addr', 'show', iface]);
      buf.writeln('--- ip -4 addr show $iface ---');
      buf.writeln(addr.stdout.toString().trim());
      final stderr = addr.stderr.toString().trim();
      if (stderr.isNotEmpty) buf.writeln('stderr: $stderr');
    } catch (e) {
      buf.writeln('ip addr failed: $e');
    }
    try {
      final route = await Process.run('ip', ['route', 'get', mdbIp]);
      buf.writeln('--- ip route get $mdbIp ---');
      buf.writeln(route.stdout.toString().trim());
      final stderr = route.stderr.toString().trim();
      if (stderr.isNotEmpty) buf.writeln('stderr: $stderr');
    } catch (e) {
      buf.writeln('ip route failed: $e');
    }
    return buf.toString();
  }

  Future<NetworkInterface?> _findWindowsInterface() async {
    try {
      // Use PowerShell to find RNDIS network adapter: avoids cmd.exe '&'
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

  Future<NetworkInterface?> _findLinuxInterface({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    // The cdc_ether driver binds asynchronously after USB enumeration —
    // the interface can take up to ~1s to appear on slow hubs. Poll until
    // it's there or we hit the timeout.
    final deadline = DateTime.now().add(timeout);
    NetworkInterface? iface;
    while (true) {
      iface = await _findLinuxInterfaceOnce();
      if (iface != null) return iface;
      if (!DateTime.now().isBefore(deadline)) return null;
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  Future<NetworkInterface?> _findLinuxInterfaceOnce() async {
    try {
      final dir = Directory('/sys/class/net');
      if (!await dir.exists()) return null;
      // Walk every interface; don't rely on name patterns. systemd predictable
      // naming gives us enx<MAC>, but legacy/biosdevname/init=no setups use
      // usb0, eth1, etc. Match on USB VID:PID via uevent first, fall back to
      // driver name.
      final entries = await dir.list(followLinks: false).toList();
      for (final entry in entries) {
        final name = entry.path.split('/').last;
        if (name == 'lo') continue;
        if (await _isLibrescootInterface(name)) {
          return NetworkInterface(
            name: name,
            displayName: 'USB Ethernet ($name)',
          );
        }
      }
    } catch (e) {
      debugPrint('Network: _findLinuxInterfaceOnce error: $e');
    }
    return null;
  }

  /// Decide whether the given iface is the Librescoot USB gadget.
  /// Primary check: USB MODALIAS in uevent contains v0525pA4A2.
  /// Fallback: driver symlink basename is cdc_ether or rndis_host.
  Future<bool> _isLibrescootInterface(String name) async {
    try {
      final uevent = File('/sys/class/net/$name/device/uevent');
      if (await uevent.exists()) {
        final content = await uevent.readAsString();
        // MODALIAS line for our gadget: usb:v0525pA4A2d... (case-insensitive hex)
        if (RegExp(r'MODALIAS=usb:v0525p[Aa]4[Aa]2', caseSensitive: false)
            .hasMatch(content)) {
          return true;
        }
      }
    } catch (_) {}

    // Fallback: read the driver symlink target. /sys/class/net/<iface>/device/driver
    // is a symlink to /sys/bus/usb/drivers/<driver>; the previous code used
    // `ls` here, which lists the *contents* of the driver dir, not its name —
    // so the cdc_ether check always failed.
    try {
      final result = await Process.run(
        'readlink',
        ['/sys/class/net/$name/device/driver'],
      );
      if (result.exitCode == 0) {
        final driver = result.stdout.toString().trim().split('/').last;
        if (driver == 'cdc_ether' ||
            driver == 'rndis_host' ||
            driver == 'cdc_ncm' ||
            driver == 'cdc_subset') {
          return true;
        }
      }
    } catch (_) {}

    return false;
  }

  Future<bool> _configureLinux(NetworkInterface iface) async {
    if (!await _isLinuxRoot()) {
      throw const NetworkPrivilegeException(
        'Network configuration on Linux requires root. '
        'Quit and relaunch the installer with: sudo <path-to-installer>',
      );
    }

    try {
      // NetworkManager will clobber a static IP on its next dhcp-fails-fall-back
      // cycle (you'd see APIPA 169.254.x.x reappear). Tell it to leave the iface
      // alone before we touch it. No-op if NM isn't running.
      if (await _isNetworkManagerActive()) {
        await _setNetworkManagerUnmanaged(iface.name);
        await Future.delayed(const Duration(milliseconds: 500));
      }

      var result = await Process.run('ip', ['link', 'set', iface.name, 'up']);
      if (result.exitCode != 0) {
        debugPrint('Network: ip link set up failed: ${result.stderr}');
        return false;
      }

      result = await Process.run(
        'ip',
        ['addr', 'add', '$targetIp/24', 'dev', iface.name],
      );
      if (result.exitCode != 0 &&
          !result.stderr.toString().contains('File exists')) {
        debugPrint('Network: ip addr add failed: ${result.stderr}');
        return false;
      }

      await Future.delayed(const Duration(seconds: 2));
      return await isMdbReachable();
    } on NetworkPrivilegeException {
      rethrow;
    } catch (e) {
      debugPrint('Network: failed to configure Linux interface: $e');
      return false;
    }
  }

  Future<bool> _isLinuxRoot() async {
    try {
      final result = await Process.run('id', ['-u']);
      return result.stdout.toString().trim() == '0';
    } catch (_) {
      return false;
    }
  }

  Future<bool> _isNetworkManagerActive() async {
    try {
      final hasNmcli = await Process.run('which', ['nmcli']);
      if (hasNmcli.exitCode != 0) return false;
      final active = await Process.run(
        'systemctl',
        ['is-active', 'NetworkManager'],
      );
      return active.stdout.toString().trim() == 'active';
    } catch (_) {
      return false;
    }
  }

  Future<void> _setNetworkManagerUnmanaged(String iface) async {
    try {
      final result = await Process.run(
        'nmcli',
        ['device', 'set', iface, 'managed', 'no'],
      );
      if (result.exitCode == 0) {
        debugPrint('Network: nmcli set $iface managed=no');
      } else {
        debugPrint(
          'Network: nmcli managed=no exit=${result.exitCode} '
          'stderr=${result.stderr}',
        );
      }
    } catch (e) {
      debugPrint('Network: nmcli call failed: $e');
    }
  }

  String _sanitizeOutput(String output) {
    return output
        .replaceAll('\u0000', '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
  }
}
