import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:librescoot_installer/services/usb_detector.dart';

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

  /// Whether `ip addr add` refused because the address is already on the
  /// interface, which means the interface is configured and the call has
  /// nothing left to do.
  ///
  /// iproute2 words this two ways: the kernel's EEXIST surfaces as
  /// "RTNETLINK answers: File exists", and its own validation reports
  /// "Error: ipv4: Address already assigned." A reconnect after the board
  /// reboots hits the second one, and reading it as a failure makes a
  /// correctly configured link look unconfigured.
  @visibleForTesting
  static bool addressAlreadyAssigned(String stderr) {
    final s = stderr.toLowerCase();
    return s.contains('file exists') || s.contains('already assigned');
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

      return parseWindowsAdapter(result.stdout.toString());
    } catch (_) {}
    return null;
  }

  /// One tab-separated adapter row: Name, NetConnectionID, NetEnabled.
  ///
  /// Null where there is no usable interface yet. netsh addresses an interface
  /// by its connection name, so an adapter without one cannot be configured,
  /// and Windows creates the adapter before the connection object: an empty
  /// NetConnectionID is the ordinary state for the first seconds after the
  /// board re-enumerates. The callers poll, so not-found is the answer that
  /// gets retried; a name of '' is one netsh cannot match.
  @visibleForTesting
  static NetworkInterface? parseWindowsAdapter(String stdout) {
    final line = stdout.trim();
    if (line.isEmpty) return null;

    final parts = line.split('\t');
    final name = parts.isNotEmpty && parts[0].trim().isNotEmpty
        ? parts[0].trim()
        : 'USB Ethernet';
    final netConn = parts.length > 1 ? parts[1].trim() : '';
    final isUp = parts.length > 2 && parts[2].trim().toLowerCase() == 'true';

    if (netConn.isEmpty) {
      debugPrint(
        'Network: adapter "$name" has no connection name yet, not ready',
      );
      return null;
    }

    return NetworkInterface(name: netConn, displayName: name, isUp: isUp);
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

  /// Find the MDB's interface on macOS.
  ///
  /// Identity decides, the same way it does on Linux. The interface has to be
  /// the one macOS published beneath a USB device carrying our vendor and
  /// product id. A hardware-port name containing "usb", and "an en that is up
  /// with no IPv4 of its own", were the previous signals, and both describe a
  /// dock's gigabit port or a Thunderbolt bridge still waiting on DHCP just as
  /// well as they describe the MDB. Picking one of those sets it unmanaged and
  /// gives it our static address, which drops the host off its own network and
  /// still never reaches the scooter.
  Future<NetworkInterface?> _findMacOSInterface({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    // The network stack attaches a moment after enumeration here as it does on
    // Linux, so a board that is present but has not published an interface yet
    // is worth waiting for rather than refusing outright.
    final deadline = DateTime.now().add(timeout);
    while (true) {
      final name = await findMacOSGadgetInterface();
      if (name != null) {
        return NetworkInterface(
          name: name,
          displayName: 'USB Ethernet ($name)',
        );
      }
      if (!DateTime.now().isBefore(deadline)) break;
      await Future.delayed(const Duration(seconds: 1));
    }

    // Say what was refused and what the old rule would have taken. On a host
    // where this returns nothing the difference between "no board attached"
    // and "board attached, interface not published" is the whole diagnosis,
    // and the second line is what tells us whether dropping the heuristic
    // changed the answer on a real Mac.
    debugPrint('Network: no interface published under USB '
        '${_hex(UsbDetector.targetVendorId)}:${_hex(UsbDetector.ethernetPid)}');
    try {
      final ifconfig = await Process.run('ifconfig', ['-a']);
      if (ifconfig.exitCode == 0) {
        final output = ifconfig.stdout.toString();
        debugPrint(
          'Network: unconfigured candidates were '
          '${unconfiguredActiveInterfaces(output)}, the previous rule would '
          'have taken ${newestUnconfiguredEthernet(output) ?? '(none)'}',
        );
      }
    } catch (_) {}
    return null;
  }

  static String _hex(int id) =>
      id.toRadixString(16).toUpperCase().padLeft(4, '0');

  /// The BSD name macOS gave the interface published beneath our ethernet
  /// gadget, or null when no such interface exists.
  @visibleForTesting
  Future<String?> findMacOSGadgetInterface() async {
    try {
      final output = await _runIoreg();
      if (output == null) return null;
      return UsbDetector.parseIoregEthernetInterface(output);
    } catch (e) {
      debugPrint('Network: ioreg lookup failed: $e');
      return null;
    }
  }

  /// The same invocation the USB detector uses to find the gadget's disk. The
  /// default IOService plane is what matters: `-p IOUSB` shows the USB nubs
  /// alone, without the driver stack that publishes the interface.
  Future<String?> _runIoreg() async {
    for (final command in const ['/usr/sbin/ioreg', 'ioreg']) {
      try {
        final result = await Process.run(
          command,
          const ['-r', '-c', 'IOUSBHostDevice', '-l', '-w', '0'],
        );
        if (result.exitCode == 0) return result.stdout.toString();
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  /// Interfaces in `ifconfig -a` output that are up and carry no IPv4 address
  /// of their own, which is what a USB gadget looks like before it is given
  /// one.
  ///
  /// Each block is judged on its own lines. Testing the whole dump instead is
  /// what broke this: lo0 always carries 127.0.0.1, so a global "no inet"
  /// test is false on every machine and no candidate ever qualified.
  @visibleForTesting
  static List<String> unconfiguredActiveInterfaces(String ifconfigOutput) {
    final found = <String>[];
    String? name;
    var active = false;
    var hasIpv4 = false;

    void closeBlock() {
      final current = name;
      if (current != null && active && !hasIpv4) found.add(current);
    }

    for (final line in ifconfigOutput.split('\n')) {
      final isHeader =
          line.isNotEmpty && !line.startsWith('\t') && !line.startsWith(' ');
      if (isHeader) {
        closeBlock();
        name = RegExp(r'^([\w.]+):').firstMatch(line)?.group(1);
        active = false;
        hasIpv4 = false;
        continue;
      }
      if (name == null) continue;
      if (line.contains('status: active')) active = true;
      // The trailing space is load-bearing. An unconfigured interface still
      // gets an inet6 link-local address, and matching that would rule out
      // every candidate this is meant to find.
      if (line.trimLeft().startsWith('inet ')) hasIpv4 = true;
    }
    closeBlock();

    return found;
  }

  /// The highest-numbered unconfigured `en` interface, taken as the most
  /// recently attached one.
  ///
  /// Ordered by the number rather than the string: sorting text puts en10
  /// before en2, so a Mac that has reached double digits, which any dock or
  /// Thunderbolt chain does, would never have en10 chosen.
  @visibleForTesting
  static String? newestUnconfiguredEthernet(String ifconfigOutput) {
    final candidates = unconfiguredActiveInterfaces(
      ifconfigOutput,
    ).where((name) => name.startsWith('en')).toList();
    if (candidates.isEmpty) return null;

    int number(String name) => int.tryParse(name.substring(2)) ?? -1;
    candidates.sort((a, b) => number(a).compareTo(number(b)));
    return candidates.last;
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
        final denied = result.stderr
            .toString()
            .toLowerCase()
            .contains('permission denied');
        // A machine that has run a successful install before carries a saved
        // service configuration for this gadget, and macOS reapplies it when
        // the interface returns. So the board can already be reachable and
        // nothing here was needed. That is not a rescue and there is no DHCP
        // lease behind it: `ipconfig getpacket` returns nothing on this link.
        //
        // On a machine that has never installed, there is no saved
        // configuration to reapply and this is the only route, so a denial is
        // the whole failure and the user has to be told what to do about it.
        await Future.delayed(const Duration(seconds: 2));
        if (await isMdbReachable()) {
          debugPrint(
            'Network: ifconfig not permitted, but the board is already '
            'reachable on an existing address',
          );
          return true;
        }
        if (denied) {
          throw const NetworkPrivilegeException(
            'Configuring the USB network interface on macOS requires '
            'administrator rights. Quit and relaunch the installer with: '
            'sudo <path-to-installer>',
          );
        }
        debugPrint('Network: ifconfig failed: ${result.stderr}');
        return false;
      }

      await Future.delayed(const Duration(seconds: 2));
      return await isMdbReachable();
    } catch (e) {
      debugPrint('Failed to configure macOS interface: $e');
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
      iface = await findLinuxInterfaceOnce();
      if (iface != null) return iface;
      if (!DateTime.now().isBefore(deadline)) return null;
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  @visibleForTesting
  Future<NetworkInterface?> findLinuxInterfaceOnce({
    String sysRoot = '/sys',
  }) async {
    try {
      final dir = Directory('$sysRoot/class/net');
      if (!await dir.exists()) return null;
      // Walk every interface; don't rely on name patterns. systemd predictable
      // naming gives us enx<MAC>, but legacy/biosdevname/init=no setups use
      // usb0, eth1, etc. Sorted so that a host with several candidates always
      // gets the same answer instead of one that depends on readdir order.
      final entries = await dir.list(followLinks: false).toList();
      final names = entries.map((e) => e.path.split('/').last).toList()..sort();
      for (final name in names) {
        if (name == 'lo') continue;
        if (await isLibrescootInterface(name, sysRoot: sysRoot)) {
          return NetworkInterface(
            name: name,
            displayName: 'USB Ethernet ($name)',
          );
        }
      }
    } catch (e) {
      debugPrint('Network: findLinuxInterfaceOnce error: $e');
    }
    return null;
  }

  /// Decide whether the given iface is the Librescoot USB gadget.
  ///
  /// Only the device's own identity counts, read from either of the two places
  /// the kernel publishes it: the USB interface uevent
  /// (`MODALIAS=usb:v0525pA4A2...`, or `PRODUCT=525/a4a2/...`, which drops
  /// leading zeros), and idVendor/idProduct on the USB device one level up.
  ///
  /// The driver name is deliberately not evidence. cdc_ether, rndis_host,
  /// cdc_ncm and cdc_subset are the generic CDC drivers every USB dock, phone
  /// tether and no-name adapter binds to, so trusting them means an unrelated
  /// interface can be picked, set unmanaged and given our static address. That
  /// takes down the host's own network and still never reaches the MDB. When
  /// the identity cannot be read, the honest answer is no.
  @visibleForTesting
  Future<bool> isLibrescootInterface(
    String name, {
    String sysRoot = '/sys',
  }) async {
    final device = '$sysRoot/class/net/$name/device';

    try {
      final uevent = File('$device/uevent');
      if (await uevent.exists()) {
        if (ueventIdentifiesGadget(await uevent.readAsString())) return true;
      }
    } catch (_) {}

    try {
      final vendor = File('$device/../idVendor');
      final product = File('$device/../idProduct');
      if (await vendor.exists() && await product.exists()) {
        if (usbIdsIdentifyGadget(
          await vendor.readAsString(),
          await product.readAsString(),
        )) {
          return true;
        }
      }
    } catch (_) {}

    return false;
  }

  /// USB ids of the MDB's ethernet gadget, the same pair the USB detector and
  /// the Windows driver installer match on.
  static const int gadgetVendorId = 0x0525;
  static const int gadgetProductId = 0xA4A2;

  /// True when a USB interface uevent names our gadget. Both lines it can come
  /// from are checked: MODALIAS pads the ids to four hex digits, PRODUCT does
  /// not (`PRODUCT=525/a4a2/612` on a live gadget).
  @visibleForTesting
  static bool ueventIdentifiesGadget(String uevent) {
    if (RegExp(
      r'MODALIAS=usb:v0525p[Aa]4[Aa]2',
      caseSensitive: false,
    ).hasMatch(uevent)) {
      return true;
    }
    return RegExp(
      r'^PRODUCT=0*525/0*a4a2(/|$)',
      multiLine: true,
      caseSensitive: false,
    ).hasMatch(uevent);
  }

  /// True when sysfs idVendor/idProduct are our gadget's. Both are hex without
  /// a 0x prefix, so they are parsed as hex rather than compared as strings.
  @visibleForTesting
  static bool usbIdsIdentifyGadget(String idVendor, String idProduct) {
    final vendor = int.tryParse(idVendor.trim(), radix: 16);
    final product = int.tryParse(idProduct.trim(), radix: 16);
    return vendor == gadgetVendorId && product == gadgetProductId;
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
          !addressAlreadyAssigned(result.stderr.toString())) {
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
}
