import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// USB device information with safety metadata
class UsbDevice {
  final String id;
  final String name;
  final String path;
  final int vendorId;
  final int productId;
  final DeviceMode mode;

  /// Size in bytes - used for safety validation
  final int? sizeBytes;

  /// Whether this is definitely a removable device
  final bool isRemovable;

  /// Whether this device is the system/boot disk (DANGER!)
  final bool isSystemDisk;

  UsbDevice({
    required this.id,
    required this.name,
    required this.path,
    required this.vendorId,
    required this.productId,
    required this.mode,
    this.sizeBytes,
    this.isRemovable = false,
    this.isSystemDisk = false,
  });

  bool get isLibrescootDevice => vendorId == 0x0525;

  /// Safety check: Is this device safe to write to?
  bool get isSafeToFlash {
    // NEVER flash if it's a system disk
    if (isSystemDisk) return false;

    // Must be a Librescoot device with correct VID
    if (!isLibrescootDevice) return false;

    // Must be in mass storage mode
    if (mode != DeviceMode.massStorage) return false;

    // Size sanity check: Librescoot uses 4GB or 8GB eMMC
    // Reject anything larger than 16GB or smaller than 1GB
    if (sizeBytes != null) {
      const minSize = 1 * 1024 * 1024 * 1024; // 1 GB
      const maxSize = 16 * 1024 * 1024 * 1024; // 16 GB
      if (sizeBytes! < minSize || sizeBytes! > maxSize) return false;
    }

    return true;
  }

  /// Human-readable size
  String get sizeFormatted {
    if (sizeBytes == null) return 'Unknown';
    final gb = sizeBytes! / (1024 * 1024 * 1024);
    return '${gb.toStringAsFixed(1)} GB';
  }

  @override
  String toString() => 'UsbDevice($name, VID=${vendorId.toRadixString(16)}, '
      'PID=${productId.toRadixString(16)}, mode=$mode, size=$sizeFormatted, '
      'removable=$isRemovable, systemDisk=$isSystemDisk)';
}

/// Device operating modes
enum DeviceMode {
  ethernet,     // 0525:A4A2 - SSH access available
  massStorage,  // 0525:A4A5 - Ready for firmware write
  recoveryDbc,  // 15A2:0061 - DBC i.MX6SL ROM in serial-download mode
  recoveryMdb,  // 15A2:007D - MDB i.MX6UL ROM in serial-download mode
  unknown,
}

/// Service for detecting Librescoot devices connected via USB
class UsbDetector {
  static const int targetVendorId = 0x0525;
  static const int ethernetPid = 0xA4A2;
  static const int massStoragePid = 0xA4A5;
  static const int nxpVendorId = 0x15A2;
  static const int recoveryPidDbc = 0x0061;
  static const int recoveryPidMdb = 0x007D;

  final _deviceController = StreamController<UsbDevice?>.broadcast();
  Timer? _pollingTimer;
  UsbDevice? _lastDevice;
  Map<String, dynamic>? _macDiskInfoCache;
  bool _macDiskProbeInFlight = false;
  int _macDiskProbeAttempts = 0;
  static const int _maxMacDiskProbeAttempts = 12;

  Stream<UsbDevice?> get deviceStream => _deviceController.stream;
  UsbDevice? get currentDevice => _lastDevice;

  /// Resolve the block device path for a mass storage device.
  /// On macOS, runs diskutil to find the matching external disk.
  Future<String?> resolveDevicePath() async {
    if (!Platform.isMacOS) return _lastDevice?.path;
    if (_macDiskInfoCache != null) return _macDiskInfoCache!['path'] as String?;
    final info = await _findMacOSDiskInfo();
    if (info != null) {
      _macDiskInfoCache = info;
      return info['path'] as String?;
    }
    return null;
  }

  /// Start monitoring for USB devices
  void startMonitoring({Duration interval = const Duration(seconds: 1)}) {
    stopMonitoring();
    _pollingTimer = Timer.periodic(interval, (_) => _poll());
    _poll(); // Initial poll
  }

  /// Stop monitoring
  void stopMonitoring() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> _poll() async {
    try {
      final device = await detectDevice();
      final changed = device?.id != _lastDevice?.id ||
          device?.mode != _lastDevice?.mode ||
          device?.path != _lastDevice?.path ||
          device?.sizeBytes != _lastDevice?.sizeBytes ||
          device?.isRemovable != _lastDevice?.isRemovable ||
          device?.isSystemDisk != _lastDevice?.isSystemDisk;
      if (changed) {
        _lastDevice = device;
        if (device == null) {
          // The cached path can outlive the device (USB drop, power-cycle).
          // Drop it so resolveDevicePath() doesn't hand back a node that
          // no longer exists on the host.
          _macDiskInfoCache = null;
          _macDiskProbeAttempts = 0;
        }
        debugPrint(device == null
            ? 'USB detector: device disconnected'
            : 'USB detector: detected ${device.name} mode=${device.mode.name}');
        _deviceController.add(device);
      }
    } catch (e) {
      // Ignore polling errors, will retry next interval.
    }
  }

  /// Detect a Librescoot device
  Future<UsbDevice?> detectDevice() async {
    if (Platform.isWindows) {
      return _detectWindows();
    } else if (Platform.isMacOS) {
      return _detectMacOS();
    } else if (Platform.isLinux) {
      return _detectLinux();
    }
    return null;
  }

  Future<UsbDevice?> _detectWindows() async {
    // Check for ethernet mode device (network adapter)
    final ethernetDevice = await _detectWindowsEthernet();
    if (ethernetDevice != null) return ethernetDevice;

    // Fallback: detect generic PnP USB/COM device for A4A2 when the RNDIS
    // driver is missing or not bound yet.
    final pnpEthernetDevice = await _detectWindowsPnpEthernet();
    if (pnpEthernetDevice != null) return pnpEthernetDevice;

    // Check for mass storage device
    final storageDevice = await _detectWindowsStorage();
    if (storageDevice != null) return storageDevice;

    // Check for SDP / serial-download recovery (no driver available, but
    // we can still see the PnP enumeration).
    final recoveryDevice = await _detectWindowsRecovery();
    if (recoveryDevice != null) return recoveryDevice;

    return null;
  }

  /// Detect a Librescoot board in i.MX SDP / serial-download mode on
  /// Windows by querying PnP for VID_15A2 + the relevant PID.
  Future<UsbDevice?> _detectWindowsRecovery() async {
    try {
      final result = await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-Command',
          r'''
$dev = Get-PnpDevice -PresentOnly | Where-Object { $_.InstanceId -like "*VID_15A2*" } | Select-Object -First 1 InstanceId
if ($dev) { $dev.InstanceId }
''',
        ],
      );
      if (result.exitCode != 0) return null;
      final id = result.stdout.toString().trim().toUpperCase();
      if (id.isEmpty) return null;
      if (id.contains('PID_0061')) {
        return UsbDevice(
          id: 'usb-15a2-0061',
          name: 'Librescoot DBC (Recovery)',
          path: '',
          vendorId: nxpVendorId,
          productId: recoveryPidDbc,
          mode: DeviceMode.recoveryDbc,
        );
      }
      if (id.contains('PID_007D')) {
        return UsbDevice(
          id: 'usb-15a2-007d',
          name: 'Librescoot MDB (Recovery)',
          path: '',
          vendorId: nxpVendorId,
          productId: recoveryPidMdb,
          mode: DeviceMode.recoveryMdb,
        );
      }
    } catch (_) {}
    return null;
  }

  Future<UsbDevice?> _detectWindowsEthernet() async {
    // Query WMI for network adapters with our VID:PID.
    // Use PowerShell instead of wmic to avoid cmd.exe '&' escaping issues
    // and wmic's UTF-16/HTML-encoded CSV output.
    try {
      final result = await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-Command',
          r'''
$dev = Get-CimInstance Win32_NetworkAdapter | Where-Object { $_.PNPDeviceID -like "*VID_0525&PID_A4A2*" } | Select-Object -First 1 Name,NetConnectionID,PNPDeviceID
if ($dev) { "$($dev.Name)`t$($dev.NetConnectionID)`t$($dev.PNPDeviceID)" }
''',
        ],
      );

      if (result.exitCode != 0) return null;

      final line = result.stdout.toString().trim();
      if (line.isEmpty) return null;

      final parts = line.split('\t');
      final name = parts.isNotEmpty ? parts[0].trim() : 'Unknown';
      final netConn = parts.length > 1 ? parts[1].trim() : '';
      final pnpId = parts.length > 2 ? parts[2].trim() : '';

      if (pnpId.toUpperCase().contains('VID_0525')) {
        return UsbDevice(
          id: pnpId,
          name: name,
          path: netConn,
          vendorId: targetVendorId,
          productId: ethernetPid,
          mode: DeviceMode.ethernet,
        );
      }
    } catch (e) {
      debugPrint('USB detector: ethernet detection error: $e');
    }
    return null;
  }

  Future<UsbDevice?> _detectWindowsStorage() async {
    // Query WMI for disk drives matching the Librescoot UMS device.
    // In UMS mode the PNPDeviceID is USBSTOR\DISK&VEN_LINUX&PROD_UMS_DISK_0,
    // not USB\VID_0525, so we match on both patterns.
    try {
      final result = await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-Command',
          r'''
$dev = Get-CimInstance Win32_DiskDrive | Where-Object {
  $_.PNPDeviceID -like "*VID_0525*" -or
  $_.PNPDeviceID -like "*VEN_LINUX*PROD_UMS*"
} | Select-Object -First 1 Model,PNPDeviceID,DeviceID,Size,MediaType
if ($dev) { "$($dev.Model)`t$($dev.PNPDeviceID)`t$($dev.DeviceID)`t$($dev.Size)`t$($dev.MediaType)" }
''',
        ],
      );

      if (result.exitCode != 0) return null;

      final line = result.stdout.toString().trim();
      if (line.isEmpty) return null;

      final parts = line.split('\t');
      final model = parts.isNotEmpty ? parts[0].trim() : 'Librescoot Device';
      final pnpId = parts.length > 1 ? parts[1].trim() : '';
      final deviceId = parts.length > 2 ? parts[2].trim() : '';
      final sizeStr = parts.length > 3 ? parts[3].trim() : '';
      final mediaType = parts.length > 4 ? parts[4].trim() : '';

      if (pnpId.isNotEmpty) {
          final sizeBytes = int.tryParse(sizeStr);

          // Check if this is removable media
          final isRemovable = mediaType.toLowerCase().contains('removable');

          // CRITICAL: Check if this might be a system disk
          final isSystemDisk = await _isWindowsSystemDisk(deviceId);

          return UsbDevice(
            id: pnpId,
            name: model,
            path: deviceId,
            vendorId: targetVendorId,
            productId: massStoragePid,
            mode: DeviceMode.massStorage,
            sizeBytes: sizeBytes,
            isRemovable: isRemovable,
            isSystemDisk: isSystemDisk,
          );
      }
    } catch (_) {}
    return null;
  }

  Future<UsbDevice?> _detectWindowsPnpEthernet() async {
    try {
      final result = await Process.run(
        'wmic',
        [
          'path',
          'Win32_PnPEntity',
          'where',
          'PNPDeviceID like "%VID_0525&PID_A4A2%"',
          'get',
          'Name,PNPDeviceID',
          '/format:csv',
        ],
        // runInShell omitted: avoid cmd.exe mangling '&' in VID/PID strings
      );

      if (result.exitCode != 0) return null;

      final output = _sanitizeWmicOutput(result.stdout.toString());
      final lines = output.split('\n').where((l) => l.trim().isNotEmpty).toList();
      if (lines.length < 2) return null;

      // Header-aware parsing
      final header = lines[0].split(',');
      final nameIdx = header.indexOf('Name');
      final pnpIdIdx = header.indexOf('PNPDeviceID');

      for (var i = 1; i < lines.length; i++) {
        final parts = lines[i].split(',');
        final pnpId = pnpIdIdx >= 0 && pnpIdIdx < parts.length ? parts[pnpIdIdx] : '';
        if (!pnpId.toUpperCase().contains('VID_0525&PID_A4A2')) continue;

        final name = nameIdx >= 0 && nameIdx < parts.length
            ? parts[nameIdx]
            : 'Librescoot MDB (USB)';

        return UsbDevice(
          id: pnpId,
          name: name,
          path: pnpId,
          vendorId: targetVendorId,
          productId: ethernetPid,
          mode: DeviceMode.ethernet,
        );
      }
    } catch (_) {}

    return _detectWindowsPnpEthernetPowerShell();
  }

  Future<UsbDevice?> _detectWindowsPnpEthernetPowerShell() async {
    try {
      final result = await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-Command',
          r'''
$dev = Get-CimInstance Win32_PnPEntity | Where-Object { $_.PNPDeviceID -like "*VID_0525&PID_A4A2*" } | Select-Object -First 1 Name,PNPDeviceID
if ($dev) { "$($dev.Name)`t$($dev.PNPDeviceID)" }
''',
        ],
        // runInShell omitted: avoid cmd.exe mangling '&' in VID/PID strings
      );

      if (result.exitCode != 0) return null;
      final line = result.stdout.toString().trim();
      if (line.isEmpty) return null;

      final parts = line.split('\t');
      final name = parts.isNotEmpty ? parts[0].trim() : 'Librescoot MDB (USB)';
      final pnpId = parts.length > 1 ? parts[1].trim() : '';
      if (!pnpId.toUpperCase().contains('VID_0525&PID_A4A2')) return null;

      return UsbDevice(
        id: pnpId,
        name: name.isNotEmpty ? name : 'Librescoot MDB (USB)',
        path: pnpId,
        vendorId: targetVendorId,
        productId: ethernetPid,
        mode: DeviceMode.ethernet,
      );
    } catch (_) {}

    return null;
  }

  /// Check if a Windows disk is the system disk
  Future<bool> _isWindowsSystemDisk(String deviceId) async {
    try {
      // Get the disk number
      final diskMatch = RegExp(r'PHYSICALDRIVE(\d+)').firstMatch(deviceId);
      if (diskMatch == null) return true; // Err on the side of caution

      final diskNumber = diskMatch.group(1);

      // Check if this disk contains the Windows partition
      final result = await Process.run(
        'wmic',
        [
          'path',
          'Win32_LogicalDiskToPartition',
          'get',
          'Antecedent,Dependent',
          '/format:csv',
        ],
        // runInShell omitted: avoid cmd.exe mangling '&' in VID/PID strings
      );

      if (result.exitCode != 0) return true; // Err on the side of caution

      final output = _sanitizeWmicOutput(result.stdout.toString());

      // Check if disk 0 (typically system disk)
      if (diskNumber == '0') return true;

      // Check if this disk has the C: drive
      if (output.contains('Disk #$diskNumber') && output.contains('C:')) {
        return true;
      }

      return false;
    } catch (_) {
      return true; // Err on the side of caution
    }
  }

  Future<UsbDevice?> _detectMacOS() async {
    try {
      // Use ioreg directly; prefer absolute paths because app container PATH
      // may not include system binaries.
      final usb = await _detectMacOSIoreg();
      if (usb != null) return usb;
      final profilerUsb = await _detectMacOSSystemProfiler();
      if (profilerUsb != null) return profilerUsb;
    } catch (_) {}

    // Fallback: if MDB is reachable, treat as ethernet mode so installer can
    // proceed even when USB metadata probing is flaky.
    try {
      final ping = await Process.run('ping', ['-c', '1', '-W', '1', '192.168.7.1']);
      if (ping.exitCode == 0) {
        return UsbDevice(
          id: 'net-192.168.7.1',
          name: 'Librescoot MDB (Ethernet)',
          path: '',
          vendorId: targetVendorId,
          productId: ethernetPid,
          mode: DeviceMode.ethernet,
        );
      }
    } catch (_) {}

    return null;
  }

  Future<UsbDevice?> _detectMacOSIoreg() async {
    try {
      final result = await _runWithFallback(
        ['/usr/sbin/ioreg', 'ioreg'],
        ['-p', 'IOUSB', '-l', '-w', '0'],
      );
      if (result == null || result.exitCode != 0) return null;

      final output = result.stdout.toString();
      final lower = output.toLowerCase();
      final hasVendor0525 = RegExp(r'"idvendor"\s*=\s*(?:1317|0x0*525)\b').hasMatch(lower);
      final hasPidA4A2 = RegExp(r'"idproduct"\s*=\s*(?:42146|0x0*a4a2)\b').hasMatch(lower);
      final hasPidA4A5 = RegExp(r'"idproduct"\s*=\s*(?:42149|0x0*a4a5)\b').hasMatch(lower);
      final hasVendor15A2 = RegExp(r'"idvendor"\s*=\s*(?:5538|0x0*15a2)\b').hasMatch(lower);
      final hasPid0061 = RegExp(r'"idproduct"\s*=\s*(?:97|0x0*61)\b').hasMatch(lower);
      final hasPid007D = RegExp(r'"idproduct"\s*=\s*(?:125|0x0*7d)\b').hasMatch(lower);

      // Check Librescoot modes. Prioritize mass storage in case both PIDs
      // appear in a noisy aggregate IORegistry dump.
      if (hasVendor0525) {
        if (hasPidA4A5) {
          // Return immediately so step progression never blocks on disk tooling.
          _kickMacDiskInfoProbe();
          final diskInfo = _macDiskInfoCache;
          return UsbDevice(
            id: 'usb-0525-a4a5',
            name: 'Librescoot MDB (Mass Storage)',
            path: diskInfo?['path'] ?? '',
            vendorId: targetVendorId,
            productId: massStoragePid,
            mode: DeviceMode.massStorage,
            sizeBytes: diskInfo?['size'],
            isRemovable: diskInfo?['removable'] ?? false,
            isSystemDisk: diskInfo?['systemDisk'] ?? false,
          );
        }

        if (hasPidA4A2) {
          return UsbDevice(
            id: 'usb-0525-a4a2',
            name: 'Librescoot MDB (Ethernet)',
            path: '', // Will be determined by network interface
            vendorId: targetVendorId,
            productId: ethernetPid,
            mode: DeviceMode.ethernet,
          );
        }
      }

      // Check for serial-download (SDP) recovery mode — what the i.MX
      // Boot ROM exposes when no valid bootloader was found or BOOT_MODE
      // pins were set. DBC i.MX6SL => 15A2:0061, MDB i.MX6UL => 15A2:007D.
      // Both UUU and imx_usb_loader are host-side clients of SDP, so this
      // detection covers either tool.
      if (hasVendor15A2) {
        if (hasPid0061) {
          return UsbDevice(
            id: 'usb-15a2-0061',
            name: 'Librescoot DBC (Recovery)',
            path: '',
            vendorId: nxpVendorId,
            productId: recoveryPidDbc,
            mode: DeviceMode.recoveryDbc,
          );
        }
        if (hasPid007D) {
          return UsbDevice(
            id: 'usb-15a2-007d',
            name: 'Librescoot MDB (Recovery)',
            path: '',
            vendorId: nxpVendorId,
            productId: recoveryPidMdb,
            mode: DeviceMode.recoveryMdb,
          );
        }
      }
    } catch (_) {}
    return null;
  }

  Future<UsbDevice?> _detectMacOSSystemProfiler() async {
    try {
      final result = await _runWithFallback(
        ['/usr/sbin/system_profiler', 'system_profiler'],
        ['SPUSBDataType'],
      );
      if (result == null || result.exitCode != 0) return null;

      final output = result.stdout.toString().toLowerCase();
      final hasVendor0525 = output.contains('vendor id: 0x0525');
      final hasPidA4A5 = output.contains('product id: 0xa4a5');
      final hasPidA4A2 = output.contains('product id: 0xa4a2');

      if (hasVendor0525 && hasPidA4A5) {
        return UsbDevice(
          id: 'usb-0525-a4a5-profiler',
          name: 'Librescoot MDB (Mass Storage)',
          path: '',
          vendorId: targetVendorId,
          productId: massStoragePid,
          mode: DeviceMode.massStorage,
        );
      }
      if (hasVendor0525 && hasPidA4A2) {
        return UsbDevice(
          id: 'usb-0525-a4a2-profiler',
          name: 'Librescoot MDB (Ethernet)',
          path: '',
          vendorId: targetVendorId,
          productId: ethernetPid,
          mode: DeviceMode.ethernet,
        );
      }
    } catch (_) {}
    return null;
  }

  Future<ProcessResult?> _runWithFallback(List<String> commands, List<String> args) async {
    for (final command in commands) {
      try {
        return await Process.run(command, args);
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  void _kickMacDiskInfoProbe() {
    if (_macDiskProbeInFlight || _macDiskInfoCache != null) return;
    if (_macDiskProbeAttempts >= _maxMacDiskProbeAttempts) return;
    _macDiskProbeInFlight = true;
    _macDiskProbeAttempts++;
    debugPrint('USB detector: starting macOS disk metadata probe (#$_macDiskProbeAttempts)');
    () async {
      try {
        final info = await _findMacOSDiskInfo().timeout(
          const Duration(milliseconds: 800),
          onTimeout: () {
            debugPrint('USB detector: disk metadata probe timed out');
            return null;
          },
        );
        if (info != null) {
          _macDiskInfoCache = info;
          _macDiskProbeAttempts = 0;
          debugPrint(
            'USB detector: disk metadata updated '
            '(path=${info["path"]}, size=${info["size"]}, removable=${info["removable"]}, systemDisk=${info["systemDisk"]})',
          );
        } else {
          debugPrint('USB detector: disk metadata probe returned no data');
        }
      } catch (_) {
        debugPrint('USB detector: disk metadata probe failed');
      } finally {
        _macDiskProbeInFlight = false;
      }
    }();
  }

  Future<Map<String, dynamic>?> _findMacOSDiskInfo() async {
    try {
      debugPrint('USB detector: diskutil list external');
      final listResult = await _runWithFallback(
        ['/usr/sbin/diskutil', 'diskutil'],
        ['list', 'external', 'physical'],
      );
      if (listResult == null || listResult.exitCode != 0) return null;

      final output = listResult.stdout.toString();
      final diskPath = _selectBestExternalDisk(output);
      if (diskPath == null) return null;
      final rawPath = diskPath.replaceFirst('/dev/disk', '/dev/rdisk');
      debugPrint('USB detector: diskutil selected $diskPath');

      debugPrint('USB detector: diskutil info $diskPath');
      final infoResult = await _runWithFallback(
        ['/usr/sbin/diskutil', 'diskutil'],
        ['info', diskPath],
      );
      if (infoResult == null || infoResult.exitCode != 0) return null;

      final info = infoResult.stdout.toString();
      int? sizeBytes;
      final sizeMatch = RegExp(r'Disk Size:\s+[\d.]+ \w+ \((\d+) Bytes\)').firstMatch(info);
      if (sizeMatch != null) {
        sizeBytes = int.tryParse(sizeMatch.group(1)!);
      }

      final isRemovable = info.contains('Removable Media:') &&
          info.contains('Removable Media:              Removable');
      final isSystemDisk = _isMacOSSystemDisk(info, diskPath);

      return {
        'path': rawPath,
        'size': sizeBytes,
        'removable': isRemovable,
        'systemDisk': isSystemDisk,
      };
    } catch (_) {
      return null;
    }
  }

  String? _selectBestExternalDisk(String diskutilListOutput) {
    final lines = diskutilListOutput.split('\n');
    final candidates = <Map<String, dynamic>>[];

    String? currentDisk;
    final currentBlock = StringBuffer();

    void flushCurrent() {
      if (currentDisk == null) return;
      final block = currentBlock.toString().toLowerCase();
      final disk = currentDisk;
      final diskNumMatch = RegExp(r'/dev/disk(\d+)').firstMatch(disk);
      final diskNum = int.tryParse(diskNumMatch?.group(1) ?? '0') ?? 0;
      var score = 0;
      if (block.contains(' linux ')) score += 100;
      if (block.contains('fdisk_partition_scheme')) score += 20;
      score += diskNum;
      candidates.add({'disk': disk, 'score': score});
    }

    for (final rawLine in lines) {
      final line = rawLine.trimRight();
      final diskMatch = RegExp(r'^/dev/disk\d+ \(external, physical\):$').firstMatch(line);
      if (diskMatch != null) {
        flushCurrent();
        currentDisk = line.split(' ').first;
        currentBlock.clear();
        continue;
      }
      if (currentDisk != null) {
        currentBlock.writeln(line);
      }
    }
    flushCurrent();

    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
    return candidates.first['disk'] as String;
  }

  bool _isMacOSSystemDisk(String diskInfo, String diskPath) {
    if (diskPath == '/dev/disk0') return true;
    final info = diskInfo;

    // Internal physical media is likely a system disk.
    final internalMatch = RegExp(r'^\s*Internal:\s+Yes\s*$', multiLine: true).hasMatch(info);
    if (internalMatch) return true;

    // APFS/system-volume signals tied to internal disk are strong indicators.
    if (RegExp(r'^\s*APFS Physical Store Disk:\s+disk0s\d+\s*$', multiLine: true).hasMatch(info)) {
      return true;
    }
    if (RegExp(r'^\s*Part of Whole:\s+disk0\s*$', multiLine: true).hasMatch(info)) {
      return true;
    }

    return false;
  }

  Future<UsbDevice?> _detectLinux() async {
    try {
      // Use lsusb for device detection
      final result = await Process.run('lsusb', ['-d', '0525:']);

      if (result.exitCode != 0) return null;

      final output = result.stdout.toString();

      if (output.contains('a4a2') || output.contains('A4A2')) {
        return UsbDevice(
          id: 'usb-0525-a4a2',
          name: 'Librescoot MDB (Ethernet)',
          path: '',
          vendorId: targetVendorId,
          productId: ethernetPid,
          mode: DeviceMode.ethernet,
        );
      }

      if (output.contains('a4a5') || output.contains('A4A5')) {
        final diskPath = await _findLinuxDiskPath();
        return UsbDevice(
          id: 'usb-0525-a4a5',
          name: 'Librescoot MDB (Mass Storage)',
          path: diskPath ?? '',
          vendorId: targetVendorId,
          productId: massStoragePid,
          mode: DeviceMode.massStorage,
        );
      }
    } catch (_) {}

    // Check for SDP / serial-download recovery mode (DBC i.MX6SL or
    // MDB i.MX6UL). See _detectMacOSIoreg for the protocol notes.
    try {
      final dbc = await Process.run('lsusb', ['-d', '15a2:0061']);
      if (dbc.exitCode == 0 && dbc.stdout.toString().isNotEmpty) {
        return UsbDevice(
          id: 'usb-15a2-0061',
          name: 'Librescoot DBC (Recovery)',
          path: '',
          vendorId: nxpVendorId,
          productId: recoveryPidDbc,
          mode: DeviceMode.recoveryDbc,
        );
      }
    } catch (_) {}
    try {
      final mdb = await Process.run('lsusb', ['-d', '15a2:007d']);
      if (mdb.exitCode == 0 && mdb.stdout.toString().isNotEmpty) {
        return UsbDevice(
          id: 'usb-15a2-007d',
          name: 'Librescoot MDB (Recovery)',
          path: '',
          vendorId: nxpVendorId,
          productId: recoveryPidMdb,
          mode: DeviceMode.recoveryMdb,
        );
      }
    } catch (_) {}

    return null;
  }

  Future<String?> _findLinuxDiskPath() async {
    try {
      // Find block device for USB mass storage
      final result = await Process.run('lsblk', ['-o', 'NAME,TRAN', '-n']);
      if (result.exitCode != 0) return null;

      for (final line in result.stdout.toString().split('\n')) {
        if (line.contains('usb')) {
          final name = line.split(' ').first.trim();
          if (name.isNotEmpty) {
            return '/dev/$name';
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Sanitize WMIC output (remove null bytes and other artifacts)
  String _sanitizeWmicOutput(String output) {
    return output
        .replaceAll('\u0000', '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
  }

  void dispose() {
    stopMonitoring();
    _deviceController.close();
  }
}
