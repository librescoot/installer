import 'dart:async';
import 'dart:io';

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

  bool get isLibreScootDevice => vendorId == 0x0525;

  /// Safety check: Is this device safe to write to?
  bool get isSafeToFlash {
    // NEVER flash if it's a system disk
    if (isSystemDisk) return false;

    // Must be a LibreScoot device with correct VID
    if (!isLibreScootDevice) return false;

    // Must be in mass storage mode
    if (mode != DeviceMode.massStorage) return false;

    // Size sanity check: LibreScoot uses 4GB or 8GB eMMC
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
  ethernet,    // 0525:A4A2 - SSH access available
  massStorage, // 0525:A4A5 - Ready for firmware write
  recovery,    // 15A2:0061 - NXP bootloader (DBC only)
  unknown,
}

/// Service for detecting LibreScoot devices connected via USB
class UsbDetector {
  static const int targetVendorId = 0x0525;
  static const int ethernetPid = 0xA4A2;
  static const int massStoragePid = 0xA4A5;
  static const int nxpVendorId = 0x15A2;
  static const int recoveryPid = 0x0061;

  final _deviceController = StreamController<UsbDevice?>.broadcast();
  Timer? _pollingTimer;
  UsbDevice? _lastDevice;

  Stream<UsbDevice?> get deviceStream => _deviceController.stream;
  UsbDevice? get currentDevice => _lastDevice;

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
      if (device?.id != _lastDevice?.id || device?.mode != _lastDevice?.mode) {
        _lastDevice = device;
        _deviceController.add(device);
      }
    } catch (e) {
      // Ignore polling errors, will retry next interval
    }
  }

  /// Detect a LibreScoot device
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

    // Check for mass storage device
    final storageDevice = await _detectWindowsStorage();
    if (storageDevice != null) return storageDevice;

    return null;
  }

  Future<UsbDevice?> _detectWindowsEthernet() async {
    // Query WMI for network adapters with our VID:PID
    try {
      final result = await Process.run(
        'wmic',
        [
          'path',
          'Win32_NetworkAdapter',
          'where',
          'PNPDeviceID like "%VID_0525&PID_A4A2%"',
          'get',
          'Name,PNPDeviceID,NetConnectionID',
          '/format:csv',
        ],
        runInShell: true,
      );

      if (result.exitCode != 0) return null;

      final output = _sanitizeWmicOutput(result.stdout.toString());
      final lines = output.split('\n').where((l) => l.trim().isNotEmpty).toList();

      if (lines.length < 2) return null; // No data rows

      // Parse CSV (skip header)
      for (var i = 1; i < lines.length; i++) {
        final parts = lines[i].split(',');
        if (parts.length >= 3) {
          final pnpId = parts.length > 2 ? parts[2] : '';
          if (pnpId.toUpperCase().contains('VID_0525')) {
            return UsbDevice(
              id: pnpId,
              name: parts.length > 1 ? parts[1] : 'Unknown',
              path: parts.length > 3 ? parts[3] : '',
              vendorId: targetVendorId,
              productId: ethernetPid,
              mode: DeviceMode.ethernet,
            );
          }
        }
      }
    } catch (_) {}
    return null;
  }

  Future<UsbDevice?> _detectWindowsStorage() async {
    // Query WMI for disk drives with our VID:PID
    try {
      final result = await Process.run(
        'wmic',
        [
          'path',
          'Win32_DiskDrive',
          'where',
          'PNPDeviceID like "%VID_0525%"',
          'get',
          'Model,PNPDeviceID,DeviceID,Size,MediaType',
          '/format:csv',
        ],
        runInShell: true,
      );

      if (result.exitCode != 0) return null;

      final output = _sanitizeWmicOutput(result.stdout.toString());
      final lines = output.split('\n').where((l) => l.trim().isNotEmpty).toList();

      if (lines.length < 2) return null;

      // Parse header to find column indices
      final header = lines[0].split(',');
      final deviceIdIdx = header.indexOf('DeviceID');
      final modelIdx = header.indexOf('Model');
      final pnpIdIdx = header.indexOf('PNPDeviceID');
      final sizeIdx = header.indexOf('Size');
      final mediaTypeIdx = header.indexOf('MediaType');

      for (var i = 1; i < lines.length; i++) {
        final parts = lines[i].split(',');
        final pnpId = pnpIdIdx >= 0 && pnpIdIdx < parts.length ? parts[pnpIdIdx] : '';

        if (pnpId.toUpperCase().contains('VID_0525')) {
          final deviceId = deviceIdIdx >= 0 && deviceIdIdx < parts.length ? parts[deviceIdIdx] : '';
          final model = modelIdx >= 0 && modelIdx < parts.length ? parts[modelIdx] : 'LibreScoot Device';
          final sizeStr = sizeIdx >= 0 && sizeIdx < parts.length ? parts[sizeIdx] : '';
          final mediaType = mediaTypeIdx >= 0 && mediaTypeIdx < parts.length ? parts[mediaTypeIdx] : '';

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
      }
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
        runInShell: true,
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
      final result = await Process.run(
        'system_profiler',
        ['SPUSBDataType', '-json'],
      );

      if (result.exitCode != 0) return null;

      // Parse JSON and look for our VID:PID
      // For now, use simpler ioreg approach
      return _detectMacOSIoreg();
    } catch (_) {}
    return null;
  }

  Future<UsbDevice?> _detectMacOSIoreg() async {
    try {
      // Look for USB devices with our vendor ID
      final result = await Process.run(
        'ioreg',
        ['-p', 'IOUSB', '-l', '-w', '0'],
      );

      if (result.exitCode != 0) return null;

      final output = result.stdout.toString();

      // Check for ethernet mode (0525:A4A2)
      if (output.contains('idVendor') && output.contains('0x525')) {
        if (output.contains('0xa4a2') || output.contains('0xA4A2')) {
          return UsbDevice(
            id: 'usb-0525-a4a2',
            name: 'LibreScoot MDB (Ethernet)',
            path: '', // Will be determined by network interface
            vendorId: targetVendorId,
            productId: ethernetPid,
            mode: DeviceMode.ethernet,
          );
        }

        if (output.contains('0xa4a5') || output.contains('0xA4A5')) {
          // Find the BSD name for the disk
          final diskInfo = await _findMacOSDiskInfo();
          if (diskInfo != null) {
            return UsbDevice(
              id: 'usb-0525-a4a5',
              name: 'LibreScoot MDB (Mass Storage)',
              path: diskInfo['path'] ?? '',
              vendorId: targetVendorId,
              productId: massStoragePid,
              mode: DeviceMode.massStorage,
              sizeBytes: diskInfo['size'],
              isRemovable: diskInfo['removable'] ?? false,
              isSystemDisk: diskInfo['systemDisk'] ?? true,
            );
          }
        }
      }

      // Check for recovery mode (15A2:0061)
      if (output.contains('0x15a2') || output.contains('0x15A2')) {
        if (output.contains('0x61') || output.contains('0x0061')) {
          return UsbDevice(
            id: 'usb-15a2-0061',
            name: 'LibreScoot DBC (Recovery)',
            path: '',
            vendorId: nxpVendorId,
            productId: recoveryPid,
            mode: DeviceMode.recovery,
          );
        }
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> _findMacOSDiskInfo() async {
    try {
      // Find external disks
      final listResult = await Process.run('diskutil', ['list', 'external']);
      if (listResult.exitCode != 0) return null;

      final output = listResult.stdout.toString();
      final match = RegExp(r'/dev/disk(\d+)').firstMatch(output);
      if (match == null) return null;

      final diskNum = match.group(1);
      final diskPath = '/dev/disk$diskNum';
      final rawPath = '/dev/rdisk$diskNum';

      // Get disk info
      final infoResult = await Process.run('diskutil', ['info', diskPath]);
      if (infoResult.exitCode != 0) return null;

      final info = infoResult.stdout.toString();

      // Parse size
      int? sizeBytes;
      final sizeMatch = RegExp(r'Disk Size:\s+[\d.]+ \w+ \((\d+) Bytes\)').firstMatch(info);
      if (sizeMatch != null) {
        sizeBytes = int.tryParse(sizeMatch.group(1)!);
      }

      // Check if removable
      final isRemovable = info.contains('Removable Media:') &&
          info.contains('Removable Media:              Removable');

      // Check if it's the system disk (CRITICAL)
      final isSystemDisk = _isMacOSSystemDisk(info, diskPath);

      return {
        'path': rawPath,
        'size': sizeBytes,
        'removable': isRemovable,
        'systemDisk': isSystemDisk,
      };
    } catch (_) {}
    return null;
  }

  bool _isMacOSSystemDisk(String diskInfo, String diskPath) {
    // Never flash disk0 - that's always the system disk
    if (diskPath == '/dev/disk0') return true;

    // Check for APFS or system volume indicators
    if (diskInfo.contains('APFS Container')) return true;
    if (diskInfo.contains('Macintosh HD')) return true;
    if (diskInfo.contains('System')) return true;

    // Check if internal
    if (diskInfo.contains('Internal:') && diskInfo.contains('Internal:                      Yes')) {
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
          name: 'LibreScoot MDB (Ethernet)',
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
          name: 'LibreScoot MDB (Mass Storage)',
          path: diskPath ?? '',
          vendorId: targetVendorId,
          productId: massStoragePid,
          mode: DeviceMode.massStorage,
        );
      }
    } catch (_) {}

    // Check for recovery mode
    try {
      final result = await Process.run('lsusb', ['-d', '15a2:0061']);
      if (result.exitCode == 0 && result.stdout.toString().isNotEmpty) {
        return UsbDevice(
          id: 'usb-15a2-0061',
          name: 'LibreScoot DBC (Recovery)',
          path: '',
          vendorId: nxpVendorId,
          productId: recoveryPid,
          mode: DeviceMode.recovery,
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
