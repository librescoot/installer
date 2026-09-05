import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:librescoot_installer/services/usb_detector.dart';
import 'elevation_service.dart';

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
  String toString() =>
      'NetworkInterface($displayName, ip=$ipAddress, up=$isUp)';
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
  static const Duration _privilegedCommandTimeout = Duration(minutes: 2);

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
    debugPrint(
      'Network: configureInterface(${iface.name}, ${iface.displayName})',
    );
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

  /// Whether [error] is the host stack refusing to route to the board, as
  /// opposed to a timeout or a refused connection.
  static bool isNoRouteToHost(Object error) =>
      error is SocketException &&
      isNoRouteToHostCode(
        error.osError?.errorCode,
        platform: Platform.operatingSystem,
      );

  /// Whether [error] is the initial connect finding nothing at the other end:
  /// no route, or no answer. Both mean the link was not ready, and both are
  /// worth one more pass at interface discovery before bothering the user.
  static bool isLinkNotReady(Object error) =>
      isNoRouteToHost(error) ||
      error is TimeoutException ||
      (error is SocketException &&
          error.message.toLowerCase().contains('timed out'));

  /// EHOSTUNREACH is per-platform: 65 Darwin, 113 Linux, 10065 Windows.
  ///
  /// The platform is a parameter rather than a lookup so the connect-failure
  /// classifier can be exercised for every host from any host.
  static bool isNoRouteToHostCode(int? code, {required String platform}) {
    if (code == null) return false;
    return switch (platform) {
      'macos' => code == 65,
      'linux' => code == 113,
      'windows' => code == 10065,
      _ => false,
    };
  }

  /// ECONNREFUSED is per-platform: 61 Darwin, 111 Linux, 10061 Windows.
  ///
  /// Refused is not the same answer as unreachable or silent: something at
  /// the other end sent a rejection back, so the link works and only the
  /// service is missing.
  static bool isConnectionRefusedCode(int? code, {required String platform}) {
    if (code == null) return false;
    return switch (platform) {
      'macos' => code == 61,
      'linux' => code == 111,
      'windows' => code == 10061,
      _ => false,
    };
  }

  /// A connect that ran out of time.
  ///
  /// Two errnos mean this. Dart reports its own connect timeout as 110 on
  /// every platform, and the OS reports ETIMEDOUT as 60 Darwin, 110 Linux,
  /// 10060 Windows. Reading only the platform one misses the commoner half.
  static bool isTimedOutCode(int? code, {required String platform}) {
    if (code == null) return false;
    if (code == 110) return true;
    return switch (platform) {
      'macos' => code == 60,
      'windows' => code == 10060,
      _ => false,
    };
  }

  static List<String> pingArgs(String host) {
    if (Platform.isWindows) return ['-n', '1', '-w', '1000', host];
    if (Platform.isMacOS) return ['-c', '1', '-W', '1000', host];
    return ['-c', '1', '-W', '1', host];
  }

  /// Check if MDB is reachable
  Future<bool> isMdbReachable() async {
    try {
      final result = await Process.run('ping', pingArgs(mdbIp));
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

  /// macOS twin of [gatherLinuxDiagnostics].
  Future<String> gatherMacOSDiagnostics(String? iface) async {
    if (!Platform.isMacOS) return '';
    final buf = StringBuffer();

    Future<void> run(String label, String exe, List<String> args) async {
      buf.writeln('--- $label ---');
      try {
        final r = await Process.run(exe, args);
        buf.writeln(r.stdout.toString().trim());
        final err = r.stderr.toString().trim();
        if (err.isNotEmpty) buf.writeln('stderr: $err');
      } catch (e) {
        buf.writeln('failed: $e');
      }
    }

    await run('ifconfig ${iface ?? '-a'}', 'ifconfig', [iface ?? '-a']);
    await run('netstat -rn -f inet', 'netstat', ['-rn', '-f', 'inet']);
    if (iface != null) {
      await run('networksetup service for $iface', 'networksetup', [
        '-listnetworkserviceorder',
      ]);
    }
    buf.writeln('--- gadget interface lookup ---');
    buf.writeln(await findMacOSGadgetInterface() ?? '(none)');
    return buf.toString();
  }

  Future<NetworkInterface?> _findWindowsInterface() async {
    try {
      // Use PowerShell to find RNDIS network adapter: avoids cmd.exe '&'
      // escaping issues with wmic.
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        r'''
$dev = Get-CimInstance Win32_NetworkAdapter | Where-Object { $_.PNPDeviceID -like "*VID_0525&PID_A4A2*" } | Select-Object -First 1 Name,NetConnectionID,NetEnabled
if ($dev) { "$($dev.Name)`t$($dev.NetConnectionID)`t$($dev.NetEnabled)" }
''',
      ]);

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
      debugPrint(
        'Network: netsh set address name="${iface.name}" static $targetIp $subnetMask',
      );
      final result = await Process.run('netsh', [
        'interface',
        'ip',
        'set',
        'address',
        'name=${iface.name}',
        'static',
        targetIp,
        subnetMask,
      ]);

      debugPrint(
        'Network: netsh exit=${result.exitCode} stdout=${result.stdout} stderr=${result.stderr}',
      );

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
    Duration timeout = const Duration(seconds: 25),
  }) async {
    // The network stack attaches a moment after enumeration here as it does on
    // Linux, so a board that is present but has not published an interface yet
    // is worth waiting for rather than refusing outright. Giving up early is
    // worse: the caller reads "no interface" as "nothing to configure" and
    // connects with no address on the link.
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
    debugPrint(
      'Network: no interface published under USB '
      '${_hex(UsbDetector.targetVendorId)}:${_hex(UsbDetector.ethernetPid)}',
    );
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
        final result = await Process.run(command, const [
          '-r',
          '-c',
          'IOUSBHostDevice',
          '-l',
          '-w',
          '0',
        ]);
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
      if (await _isMacOSInterfaceConfigured(iface.name) &&
          await isMdbReachable()) {
        return true;
      }

      final serviceName = await macOSServiceNameFor(iface.name);

      if (serviceName != null) {
        // Use networksetup for named services
        debugPrint('Network: networksetup -setmanual "$serviceName" $targetIp');
        final result = await Process.run('networksetup', [
          '-setmanual',
          serviceName,
          targetIp,
          subnetMask,
        ]);
        final out = result.stdout.toString().trim();
        final err = result.stderr.toString().trim();
        // Logged either way. This step deciding not to work is what sends the
        // run into the ifconfig fallback, and a run that ends there with no
        // record of why cannot be diagnosed from the log the user hands over.
        debugPrint(
          'Network: networksetup exit=${result.exitCode}'
          '${out.isEmpty ? '' : ' stdout=$out'}'
          '${err.isEmpty ? '' : ' stderr=$err'}',
        );

        if (result.exitCode == 0) {
          await Future.delayed(const Duration(seconds: 2));
          return await isMdbReachable();
        }
      } else {
        debugPrint('Network: no macOS network service owns ${iface.name}');
      }

      if (await _isMacOSInterfaceConfigured(iface.name)) {
        return await isMdbReachable();
      }

      if (_elevationDeclined) {
        throw const NetworkPrivilegeException(_declinedMessage);
      }

      final root = await ElevationService.macOSRootPrefix(
        'to set up the USB network',
      );
      const ran = elevationSentinel;
      final script =
          'echo $ran; '
          'ifconfig ${_shellQuote(iface.name)} inet '
          '${_shellQuote(targetIp)} netmask ${_shellQuote(subnetMask)}';
      if (root == null) {
        _elevationDeclined = true;
        throw const NetworkPrivilegeException(
          'Setting up the USB network connection needs administrator access, '
          'but this Mac has no way to request it. Enable administrator access '
          'for the installer and retry.',
        );
      }
      final argv = [...root.argv, 'sh', '-c', script];
      final result = await runBounded(
        argv.first,
        argv.sublist(1),
        timeout: _privilegedCommandTimeout,
        environment: {...Platform.environment, ...root.environment},
      );
      final ranAtAll = result.stdout.toString().contains(ran);

      if (result.exitCode != 0) {
        final denied = !ranAtAll;
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
          _elevationDeclined = true;
          throw const NetworkPrivilegeException(_declinedMessage);
        }
        debugPrint('Network: ifconfig failed: ${result.stderr}');
        return false;
      }

      await Future.delayed(const Duration(seconds: 2));
      return await isMdbReachable();
    } on NetworkPrivilegeException {
      // The generic catch below would turn this into a plain false, and the
      // caller reads false as "not reachable yet" and keeps pinging. The
      // whole point of the exception is that no amount of waiting fixes it,
      // so it has to leave this function intact. _configureLinux does the
      // same thing for the same reason.
      rethrow;
    } catch (e) {
      debugPrint('Failed to configure macOS interface: $e');
      return false;
    }
  }

  /// The macOS *network service* that owns [device], or null if none does.
  ///
  /// `networksetup -setmanual` addresses a service, and the hardware port is a
  /// different name that only usually matches it: rename a service in System
  /// Settings, or plug in a second adapter of the same model, and the port name
  /// stops resolving. The service order listing prints both together, so read
  /// the pairing there and keep the port name as the fallback.
  @visibleForTesting
  Future<String?> macOSServiceNameFor(String device) async {
    try {
      final order = await Process.run('networksetup', [
        '-listnetworkserviceorder',
      ]);
      if (order.exitCode == 0) {
        final name = parseServiceOrder(order.stdout.toString(), device);
        if (name != null) return name;
      }

      final ports = await Process.run('networksetup', [
        '-listallhardwareports',
      ]);
      if (ports.exitCode == 0) {
        final lines = ports.stdout.toString().split('\n');
        for (var i = 1; i < lines.length; i++) {
          if (lines[i].trim() != 'Device: $device') continue;
          final portLine = lines[i - 1];
          if (portLine.startsWith('Hardware Port:')) {
            return portLine.substring('Hardware Port:'.length).trim();
          }
        }
      }
    } catch (e) {
      debugPrint('Network: service lookup failed for $device: $e');
    }
    return null;
  }

  /// The service named above the `(Hardware Port: ..., Device: en5)` line in
  /// `networksetup -listnetworkserviceorder` output.
  ///
  /// Enabled services are numbered "(1)", disabled ones are marked "(*)", and
  /// both name a service that -setmanual accepts.
  @visibleForTesting
  static String? parseServiceOrder(String output, String device) {
    final lines = output.split('\n');
    for (var i = 0; i < lines.length; i++) {
      if (!lines[i].contains('Device: $device)')) continue;
      for (var j = i - 1; j >= 0; j--) {
        final match = RegExp(
          r'^\((?:\*|\d+)\)\s+(.+)$',
        ).firstMatch(lines[j].trim());
        if (match != null) return match.group(1)!.trim();
      }
    }
    return null;
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

  @visibleForTesting
  static const String elevationSentinel = '__librescoot_elevated__';

  static bool _elevationDeclined = false;

  static void allowElevationPromptAgain() => _elevationDeclined = false;

  @visibleForTesting
  static bool get elevationDeclined => _elevationDeclined;

  static const String _declinedMessage =
      'Setting up the USB network connection needs an administrator, and the '
      'request was not authorised. Use the retry button and confirm the '
      'prompt when it appears.';

  static String _shellQuote(String s) => "'${s.replaceAll("'", "'\\''")}'";

  @visibleForTesting
  static bool isSafeInterfaceName(String name) =>
      RegExp(r'^[A-Za-z0-9][A-Za-z0-9._@-]{0,14}$').hasMatch(name);

  static const int _linkStepFailed = 11;
  static const int _addressStepFailed = 12;

  @visibleForTesting
  static bool interfaceCarriesAddress(String ipOutput, String address) =>
      ipOutput.contains('inet $address/24') &&
      RegExp(r'[<,]UP[,>]').hasMatch(ipOutput);

  Future<bool> _isLinuxInterfaceConfigured(String iface) async {
    try {
      final r = await Process.run('ip', ['-4', 'addr', 'show', 'dev', iface]);
      if (r.exitCode != 0) return false;
      return interfaceCarriesAddress(r.stdout.toString(), targetIp);
    } catch (_) {
      return false;
    }
  }

  Future<bool> _configureLinux(NetworkInterface iface) async {
    if (!isSafeInterfaceName(iface.name)) {
      debugPrint('Network: refusing to configure "${iface.name}"');
      return false;
    }

    if (await _isLinuxInterfaceConfigured(iface.name)) {
      return await isMdbReachable();
    }

    if (_elevationDeclined) {
      throw const NetworkPrivilegeException(_declinedMessage);
    }

    final root = await ElevationService.linuxRootPrefix();
    if (root == null) {
      throw const NetworkPrivilegeException(
        'Configuring the USB network connection needs root, and this system '
        'has neither pkexec nor an askpass helper for sudo. Quit and '
        'relaunch the installer with: sudo <path-to-installer>',
      );
    }

    try {
      const ran = elevationSentinel;
      final steps = <String>['echo $ran'];
      if (await _isNetworkManagerActive()) {
        steps.add('nmcli device set ${iface.name} managed no || true');
        steps.add('sleep 0.5');
      }
      steps.add('ip link set ${iface.name} up || exit $_linkStepFailed');
      steps.add(
        'ip addr add $targetIp/24 dev ${iface.name} || exit $_addressStepFailed',
      );

      final argv = [...root.argv, 'sh', '-c', steps.join('\n')];
      if (!root.isDirect) {
        debugPrint('Network: elevating via ${root.argv.join(' ')}');
      }
      final result = await runBounded(
        argv.first,
        argv.sublist(1),
        timeout: _privilegedCommandTimeout,
        environment: {...Platform.environment, ...root.environment},
      );
      final stderr = result.stderr.toString();

      if (!result.stdout.toString().contains(ran)) {
        debugPrint(
          'Network: elevation did not run (exit ${result.exitCode}): $stderr',
        );
        _elevationDeclined = true;
        throw const NetworkPrivilegeException(
          'Configuring the USB network connection needs root, and the '
          'request was not authorised. Confirm the password dialog if one '
          'appeared. If none did, this desktop session cannot ask for it: '
          'quit and relaunch the installer with: sudo <path-to-installer>',
        );
      }

      switch (result.exitCode) {
        case 0:
          break;
        case _linkStepFailed:
          debugPrint('Network: ip link set up failed: $stderr');
          return false;
        case _addressStepFailed:
          if (!addressAlreadyAssigned(stderr)) {
            debugPrint('Network: ip addr add failed: $stderr');
            return false;
          }
        default:
          debugPrint(
            'Network: configuring ${iface.name} exited '
            '${result.exitCode}: $stderr',
          );
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

  Future<bool> _isNetworkManagerActive() async {
    try {
      if (!await ElevationService.hasCommand('nmcli')) return false;
      final active = await Process.run('systemctl', [
        'is-active',
        'NetworkManager',
      ]);
      return active.stdout.toString().trim() == 'active';
    } catch (_) {
      return false;
    }
  }
}
