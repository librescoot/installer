import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Outcome of asking the OS whether a disk carries boot or system.
enum SystemDiskVerdict {
  /// The storage stack confirmed it carries neither.
  notSystem,

  /// It carries boot or system, or we refuse to probe it at all. Never flash.
  systemDisk,

  /// The probe could not answer. The user confirms the target instead.
  unknown,
}

/// What asking Windows about one disk number came back with.
class WindowsDiskProbe {
  /// False only when the probe established the disk is gone.
  final bool present;

  /// Whether the disk carries boot or system, as far as the probe could tell.
  final SystemDiskVerdict verdict;

  const WindowsDiskProbe({required this.verdict, this.present = true});
}

/// One disk as the OS enumerates it, for the dialog that asks the user to
/// confirm the flash target when the system-disk probe came back unknown.
class UsbDiskInfo {
  final int index;
  final String model;
  final int? sizeBytes;
  final String bus;
  final String path;

  /// True for the disk the detector matched by its USB vendor and product,
  /// which is the only one the installer offers to write to.
  final bool isDetectedTarget;

  UsbDiskInfo({
    required this.index,
    required this.model,
    required this.sizeBytes,
    required this.bus,
    required this.path,
    this.isDetectedTarget = false,
  });

  String get sizeFormatted {
    final bytes = sizeBytes;
    if (bytes == null) return 'Unknown';
    final gb = bytes / (1024 * 1024 * 1024);
    return '${gb.toStringAsFixed(1)} GB';
  }
}

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

  /// What the OS said about this device being the system/boot disk (DANGER!)
  final SystemDiskVerdict systemDiskVerdict;

  UsbDevice({
    required this.id,
    required this.name,
    required this.path,
    required this.vendorId,
    required this.productId,
    required this.mode,
    this.sizeBytes,
    this.isRemovable = false,
    // No verdict without a probe. notSystem would assert one that never ran
    // and skip the confirmation dialog.
    this.systemDiskVerdict = SystemDiskVerdict.unknown,
  });

  /// Only a confirmed system disk blocks the flash outright. An unknown
  /// verdict is put to the user instead of guessing either way.
  bool get isSystemDisk => systemDiskVerdict == SystemDiskVerdict.systemDisk;

  bool get isLibrescootDevice => vendorId == 0x0525;

  /// Human-readable size
  String get sizeFormatted {
    if (sizeBytes == null) return 'Unknown';
    final gb = sizeBytes! / (1024 * 1024 * 1024);
    return '${gb.toStringAsFixed(1)} GB';
  }

  @override
  String toString() => 'UsbDevice($name, VID=${vendorId.toRadixString(16)}, '
      'PID=${productId.toRadixString(16)}, mode=$mode, size=$sizeFormatted, '
      'removable=$isRemovable, systemDisk=${systemDiskVerdict.name})';
}

/// Device operating modes
enum DeviceMode {
  ethernet,     // 0525:A4A2 - SSH access available
  hijacked,     // 0525:A4A2 present, but another driver holds it (no SSH)
  massStorage,  // 0525:A4A5 - Ready for firmware write
  recoveryDbc,  // 15A2:0061 - DBC i.MX6SL ROM in serial-download mode
  recoveryMdb,  // 15A2:007D - MDB i.MX6UL ROM in serial-download mode
  unknown,
}

/// Service for detecting Librescoot devices connected via USB
class UsbDetector {
  static const int targetVendorId = 0x0525;
  static const int ethernetPid = 0xA4A2;

  /// Map a Windows PnP setup class onto a device mode.
  ///
  /// A device answering on 0525:A4A2 is only reachable over SSH if Windows
  /// put it in the Net class. When another driver has claimed it the same PnP
  /// entity is still enumerated, in class Ports and named something like
  /// "USB Serial Device (COM5)", and reporting that as ethernet sent the
  /// installer on to an SSH attempt that could never succeed.
  ///
  /// An unknown class stays ethernet: the query failing to return a class is
  /// not evidence that something took the device.
  @visibleForTesting
  static DeviceMode modeForPnpClass(String? pnpClass) {
    final cls = pnpClass?.trim().toLowerCase() ?? '';
    if (cls.isEmpty) return DeviceMode.ethernet;
    return cls == 'net' ? DeviceMode.ethernet : DeviceMode.hijacked;
  }
  static const int massStoragePid = 0xA4A5;
  static const int nxpVendorId = 0x15A2;
  static const int recoveryPidDbc = 0x0061;
  static const int recoveryPidMdb = 0x007D;

  final _deviceController = StreamController<UsbDevice?>.broadcast();
  Timer? _pollingTimer;
  UsbDevice? _lastDevice;
  bool _pollInFlight = false;
  int _pollGeneration = 0;
  Map<String, dynamic>? _macDiskInfoCache;
  bool _macDiskProbeInFlight = false;
  int _macDiskProbeAttempts = 0;
  static const int _maxMacDiskProbeAttempts = 12;

  /// Whether the macOS disk probe result is currently cached.
  ///
  /// The cache outliving the device it describes is what hands the flasher a
  /// path that no longer exists, so the conditions that clear it are worth
  /// pinning in a test rather than trusting by inspection.
  @visibleForTesting
  bool get hasMacDiskInfoCache => _macDiskInfoCache != null;

  /// Seed the macOS disk probe cache, standing in for a probe that has landed.
  @visibleForTesting
  void seedMacDiskInfoForTest(Map<String, dynamic>? info) =>
      _macDiskInfoCache = info;

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

  /// How long a single poll may take before its result is abandoned.
  ///
  /// Nothing under detectDevice() bounds its own subprocesses, and a wedged
  /// diskutil or PowerShell would otherwise hold the in-flight guard forever
  /// and stop detection for good. Generous on purpose: a cold Windows host
  /// legitimately spends several seconds in its PnP queries, and cutting a
  /// working probe short is worse than waiting for it.
  static const Duration pollTimeout = Duration(seconds: 30);

  /// Start monitoring for USB devices
  void startMonitoring({Duration interval = const Duration(seconds: 1)}) {
    stopMonitoring();
    _pollingTimer = Timer.periodic(interval, (_) => _poll());
    _poll(); // Initial poll
  }

  /// Stop monitoring
  ///
  /// Bumps the generation so that a poll already in flight can no longer
  /// write state or emit when it lands. Callers stop monitoring precisely
  /// when they need USB left alone, and a late result arriving in the middle
  /// of a flash carries a pre-flash view of a device that is re-enumerating.
  void stopMonitoring() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _pollGeneration++;
    // Release the guard as well. Whatever is still running out there is now
    // orphaned by the generation bump and can no longer touch anything, so
    // holding the guard for it would only delay the first poll after a
    // restart by however long the orphan takes to finish.
    _pollInFlight = false;
  }

  Future<void> _poll() async {
    // A tick that arrives while a poll is still running is dropped rather
    // than stacking another set of subprocesses on top of it.
    if (_pollInFlight) return;
    _pollInFlight = true;
    final generation = _pollGeneration;
    try {
      final device = await detectDevice().timeout(pollTimeout);
      // Superseded while we were away by a stop, or by the stop inside a
      // restart. This answer describes a device state nobody is waiting for
      // any more, and applying it would undo whatever replaced it. A poll
      // that runs past pollTimeout never reaches here at all: the await
      // throws and its late result is simply dropped.
      if (generation != _pollGeneration) return;
      final changed = device?.id != _lastDevice?.id ||
          device?.mode != _lastDevice?.mode ||
          device?.path != _lastDevice?.path ||
          device?.sizeBytes != _lastDevice?.sizeBytes ||
          device?.isRemovable != _lastDevice?.isRemovable ||
          device?.systemDiskVerdict != _lastDevice?.systemDiskVerdict;
      if (changed) {
        // Computed before _lastDevice is replaced, or the comparison is
        // against the value we are about to overwrite and never fires.
        final modeChanged = device?.mode != _lastDevice?.mode;
        _lastDevice = device;
        if (device == null || modeChanged) {
          // The cached path can outlive the device (USB drop, power-cycle),
          // and it also outlives a mode change: mass storage to ethernet
          // leaves a disk node cached for a board that no longer presents
          // one, because the device is not null so the drop below is skipped.
          // Clearing on the mode change catches the case a null poll misses
          // when the board switches gadget without a gap the poll can see.
          //
          // Resetting the attempt counter matters for the same transition:
          // it is capped, and a device that is present but not yet
          // enumerated exhausts the cap and then never probes again, which
          // is the state that most needs another look.
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
    } finally {
      _pollInFlight = false;
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
} | Select-Object -First 1 Model,PNPDeviceID,DeviceID,MediaType,Index
if ($dev) {
  "$($dev.Model)`t$($dev.PNPDeviceID)`t$($dev.DeviceID)`t$($dev.Index)`t$($dev.MediaType)"
}
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
      final indexStr = parts.length > 3 ? parts[3].trim() : '';
      final mediaType = parts.length > 4 ? parts[4].trim() : '';

      if (pnpId.isNotEmpty) {
          final sizeBytes = await _windowsDiskSize(int.tryParse(indexStr));

          // Check if this is removable media
          final isRemovable = mediaType.toLowerCase().contains('removable');

          // CRITICAL: Check if this might be a system disk
          final probe = await _windowsSystemDiskVerdict(deviceId);

          // The enumeration can return a disk the storage stack has released.
          // Downstream that reads as a board in mass storage, the state that
          // means a flash has not taken, and triggers another write against a
          // path that no longer opens.
          if (!probe.present) return null;

          return UsbDevice(
            id: pnpId,
            name: model,
            path: deviceId,
            vendorId: targetVendorId,
            productId: massStoragePid,
            mode: DeviceMode.massStorage,
            sizeBytes: sizeBytes,
            isRemovable: isRemovable,
            systemDiskVerdict: probe.verdict,
          );
      }
    } catch (_) {}
    return null;
  }

  /// The disk's real length, from Get-Disk, in its own process.
  ///
  /// Win32_DiskDrive.Size is a geometry product rounded down to whole
  /// cylinders and under-reports the device. Get-Disk reports the true
  /// length, but powershell.exe has been seen dying with an access violation
  /// inside this query on some machines, and a process that dies takes its
  /// whole script with it regardless of try/catch. Kept separate from the
  /// enumeration so that a crash here costs the size rather than the device.
  ///
  /// Null when the size could not be established. [FlashService.validateDevice]
  /// refuses a flash on a null size, which is the safe reading: a size that is
  /// missing is not a size that matches.
  Future<int?> _windowsDiskSize(int? diskNumber) async {
    if (diskNumber == null) return null;
    try {
      final result = await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-Command',
          '(Get-Disk -Number $diskNumber -ErrorAction Stop).Size',
        ],
      );
      if (result.exitCode != 0) {
        debugPrint(
          'USB detector: disk size query failed for disk $diskNumber '
          '(exit ${result.exitCode})',
        );
        return null;
      }
      return int.tryParse(result.stdout.toString().trim());
    } catch (e) {
      debugPrint('USB detector: disk size query threw for disk $diskNumber: $e');
      return null;
    }
  }

  /// Find the MDB's PnP entity on Windows and work out what mode it is in.
  ///
  /// The device is enumerated whether or not a usable driver holds it, so the
  /// setup class is what separates "reachable over SSH" from "some other
  /// driver has it". See [modeForPnpClass].
  Future<UsbDevice?> _detectWindowsPnpEthernet() async {
    try {
      final result = await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-Command',
          r"""
$dev = Get-CimInstance Win32_PnPEntity | Where-Object { $_.PNPDeviceID -like "*VID_0525&PID_A4A2*" } | Select-Object -First 1 Name,PNPDeviceID,PNPClass
if ($dev) { "$($dev.Name)`t$($dev.PNPDeviceID)`t$($dev.PNPClass)" }
""",
        ],
        // runInShell omitted: avoid cmd.exe mangling '&' in VID/PID strings
      );

      if (result.exitCode != 0) return null;
      final line = result.stdout.toString().trim();
      if (line.isEmpty) return null;

      final parts = line.split('\t');
      final name = parts.isNotEmpty ? parts[0].trim() : 'Librescoot MDB (USB)';
      final pnpId = parts.length > 1 ? parts[1].trim() : '';
      final pnpClass = parts.length > 2 ? parts[2].trim() : '';
      if (!pnpId.toUpperCase().contains('VID_0525&PID_A4A2')) return null;

      return UsbDevice(
        id: pnpId,
        name: name.isNotEmpty ? name : 'Librescoot MDB (USB)',
        path: pnpId,
        vendorId: targetVendorId,
        productId: ethernetPid,
        mode: modeForPnpClass(pnpClass),
      );
    } catch (_) {}

    return null;
  }

  /// Check if a Windows disk is the system disk.
  ///
  /// Asks the storage stack which disk carries boot and system, rather than
  /// pattern-matching drive letters out of a text dump. Get-Disk answers it
  /// directly; the CIM associator walk is there for the rare machine whose
  /// Storage module is missing, and compares against the actual system drive
  /// instead of assuming it is C:.
  /// Whether a Linux block device carries a mounted filesystem.
  ///
  /// Linux had no verdict at all, so the only guard was refusing /dev/sda
  /// outright. On a laptop that boots from NVMe, sda is simply the first USB
  /// disk attached, which is exactly what the scooter enumerates as, and the
  /// refusal blocked the one device the user is trying to flash.
  ///
  /// The test is where a partition is mounted, not whether it is mounted at
  /// all. A desktop auto-mounts whatever appears, and the scooter's own boot
  /// partition shows up under the removable-media roots seconds after it
  /// enters mass storage, so "has a mount" would refuse the exact device the
  /// user is trying to flash. A mount anywhere else is a disk the machine is
  /// living on.
  Future<SystemDiskVerdict> linuxSystemDiskVerdict(String diskPath,
      {String mountsPath = '/proc/mounts'}) async {
    final base = diskPath.startsWith('/dev/') ? diskPath.substring(5) : diskPath;
    if (base.isEmpty) return SystemDiskVerdict.systemDisk;
    try {
      final mounts = await File(mountsPath).readAsString();
      // sda matches sda and sda1..sdaN, and must not match sdaa or sdb.
      final owned = RegExp('^${RegExp.escape(base)}' r'(p?\d+)?$');
      for (final line in mounts.split('\n')) {
        final fields = line.split(' ');
        if (fields.length < 2) continue;
        final source = fields[0];
        if (!source.startsWith('/dev/')) continue;
        if (!owned.hasMatch(source.substring(5))) continue;
        if (_isRemovableMountPoint(fields[1])) continue;
        return SystemDiskVerdict.systemDisk;
      }
      return SystemDiskVerdict.notSystem;
    } catch (e) {
      // Unable to tell is not permission to write: the caller keeps its
      // conservative path rules when the answer is unknown.
      debugPrint('USB detector: could not read $mountsPath ($e)');
      return SystemDiskVerdict.unknown;
    }
  }

  /// Where a desktop parks media it auto-mounted, as opposed to the paths a
  /// running system is built out of. Mount points arrive octal-escaped, so a
  /// space in a volume label shows up as \\040.
  static bool _isRemovableMountPoint(String mountPoint) {
    final p = mountPoint.replaceAll(r'\040', ' ');
    return p.startsWith('/media/') ||
        p.startsWith('/run/media/') ||
        p.startsWith('/mnt/') ||
        p == '/media' ||
        p == '/mnt';
  }

  /// Maps the probe script's answer. Only 'absent' clears [present], so a
  /// probe that could not answer never removes a device.
  static WindowsDiskProbe _parseWindowsDiskProbe(int exitCode, String stdout) {
    final answer = stdout.trim().toLowerCase();
    if (exitCode != 0) {
      return const WindowsDiskProbe(verdict: SystemDiskVerdict.unknown);
    }
    return switch (answer) {
      'system' =>
        const WindowsDiskProbe(verdict: SystemDiskVerdict.systemDisk),
      'ok' => const WindowsDiskProbe(verdict: SystemDiskVerdict.notSystem),
      'absent' => const WindowsDiskProbe(
          verdict: SystemDiskVerdict.unknown,
          present: false,
        ),
      _ => const WindowsDiskProbe(verdict: SystemDiskVerdict.unknown),
    };
  }

  @visibleForTesting
  /// `Removable Media` from `diskutil info`. Null when the field is absent.
  ///
  /// diskutil pads its value column to the width of the longest label in the
  /// block, so the column position moves between disks and between OS
  /// versions. Match the field, not the layout.
  @visibleForTesting
  static bool? parseMacRemovable(String info) {
    final match =
        RegExp(r'Removable Media:\s*(\S+)', multiLine: true).firstMatch(info);
    if (match == null) return null;
    final value = match.group(1)!.toLowerCase();
    if (value == 'removable') return true;
    if (value == 'fixed') return false;
    return null;
  }

  static WindowsDiskProbe parseWindowsDiskProbe(int exitCode, String stdout) =>
      _parseWindowsDiskProbe(exitCode, stdout);

  Future<WindowsDiskProbe> _windowsSystemDiskVerdict(String deviceId) async {
    // Anything we cannot name a disk number for is not something we are
    // willing to write to.
    final diskMatch = RegExp(r'PHYSICALDRIVE(\d+)').firstMatch(deviceId);
    if (diskMatch == null) {
      return const WindowsDiskProbe(verdict: SystemDiskVerdict.systemDisk);
    }

    final diskNumber = int.parse(diskMatch.group(1)!);

    // Index 0 does not identify the system disk; that can be any number and
    // IsBoot/IsSystem below is what finds it. Refused because the scooter is
    // never index 0.
    if (diskNumber == 0) {
      return const WindowsDiskProbe(verdict: SystemDiskVerdict.systemDisk);
    }

    try {
      final result = await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          '''
\$ErrorActionPreference = 'Stop'
\$n = $diskNumber
try {
  \$disk = Get-Disk -Number \$n
  if (\$disk.IsBoot -or \$disk.IsSystem) { 'system' } else { 'ok' }
  exit
} catch {}
try {
  \$drive = Get-CimInstance Win32_DiskDrive -Filter "Index=\$n"
  if (-not \$drive) { 'absent'; exit }
  \$letters = \$drive |
    Get-CimAssociatedInstance -ResultClassName Win32_DiskPartition |
    Get-CimAssociatedInstance -ResultClassName Win32_LogicalDisk |
    Select-Object -ExpandProperty DeviceID
  # An empty letter set means the volumes could not be read, not that none
  # is the system volume: ESP-only, BitLocker-locked and Storage Spaces disks
  # all answer this way without throwing.
  if (-not \$letters) { 'unknown'; exit }
  if (\$letters -contains \$env:SystemDrive) { 'system' } else { 'ok' }
} catch { 'unknown' }
''',
        ],
      );

      final answer = result.stdout.toString().trim().toLowerCase();
      final probe = _parseWindowsDiskProbe(result.exitCode, answer);

      if (!probe.present) {
        debugPrint(
          'USB detector: disk $deviceId no longer enumerates, '
          'dropping the stale mass-storage entry',
        );
      } else if (probe.verdict == SystemDiskVerdict.unknown) {
        debugPrint(
          'USB detector: system-disk check inconclusive for $deviceId '
          '(exit ${result.exitCode}, output "$answer"), '
          'asking the user to confirm the target',
        );
      }
      return probe;
    } catch (e) {
      debugPrint('USB detector: system-disk check failed for $deviceId: $e');
      return const WindowsDiskProbe(verdict: SystemDiskVerdict.unknown);
    }
  }

  /// USB-attached disks the OS can see, for the confirmation dialog.
  ///
  /// Deliberately narrow: disk 0 and everything on an internal bus is left
  /// out, so nothing the user could mistake for their own drive is offered.
  /// [detectedPath] marks the disk the detector matched by vendor and
  /// product, which is the only one the installer will write to.
  Future<List<UsbDiskInfo>> listUsbDisks({String? detectedPath}) async {
    if (!Platform.isWindows) return const [];
    try {
      final result = await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          r'''
Get-CimInstance Win32_DiskDrive | ForEach-Object {
  "$($_.Index)`t$($_.Model)`t$($_.Size)`t$($_.InterfaceType)`t$($_.DeviceID)`t$($_.PNPDeviceID)"
}
''',
        ],
      );
      if (result.exitCode != 0) return const [];

      final disks = <UsbDiskInfo>[];
      for (final line in result.stdout.toString().split('\n')) {
        final parts = line.trim().split('\t');
        if (parts.length < 6) continue;

        final index = int.tryParse(parts[0].trim());
        if (index == null || index == 0) continue;

        final bus = parts[3].trim();
        final pnpId = parts[5].trim().toUpperCase();
        final isUsb = bus.toUpperCase() == 'USB' || pnpId.startsWith('USBSTOR');
        if (!isUsb) continue;

        final devicePath = parts[4].trim();
        disks.add(UsbDiskInfo(
          index: index,
          model: parts[1].trim().isEmpty ? 'Disk $index' : parts[1].trim(),
          sizeBytes: int.tryParse(parts[2].trim()),
          bus: bus.isEmpty ? 'USB' : bus,
          path: devicePath,
          isDetectedTarget: detectedPath != null &&
              devicePath.toUpperCase() == detectedPath.toUpperCase(),
        ));
      }
      disks.sort((a, b) => a.index.compareTo(b.index));
      return disks;
    } catch (e) {
      debugPrint('USB detector: could not enumerate USB disks: $e');
      return const [];
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
            // The disk probe runs asynchronously, so diskInfo is null until
            // it lands. Null is the absence of an answer, not a negative one.
            systemDiskVerdict: switch (diskInfo?['systemDisk']) {
              true => SystemDiskVerdict.systemDisk,
              false => SystemDiskVerdict.notSystem,
              _ => SystemDiskVerdict.unknown,
            },
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

      // Check for serial-download (SDP) recovery mode: what the i.MX
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
      final result = await _runSystemProfilerUsb();
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

  /// Query system_profiler's USB report across macOS versions.
  ///
  /// macOS 26 renamed the datatype from `SPUSBDataType` to
  /// `SPUSBHostDataType`. The legacy name still exits 0 there but returns an
  /// empty report, which is indistinguishable from "no devices attached" —
  /// so an empty result falls through to the next candidate instead of being
  /// treated as an answer.
  Future<ProcessResult?> _runSystemProfilerUsb() async {
    for (final dataType in const ['SPUSBHostDataType', 'SPUSBDataType']) {
      final result = await _runWithFallback(
        ['/usr/sbin/system_profiler', 'system_profiler'],
        [dataType],
      );
      if (result == null || result.exitCode != 0) continue;
      if (result.stdout.toString().trim().isEmpty) continue;
      return result;
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

      // Cross-check the heuristic pick against the actual USB device
      // identity before trusting it. _selectBestExternalDisk only scores by
      // size/label; with a second unrelated external disk attached, it can
      // pick the wrong one. Resolve which BSD disk number system_profiler
      // ties to the Librescoot gadget (VID 0x0525 / PID 0xA4A5) and require
      // the heuristic pick to match it. No match (or identity unresolved)
      // means we refuse to guess rather than risk flashing the wrong disk.
      final usbDiskNum = await _findLibrescootUsbDiskNumber();
      if (usbDiskNum == null) {
        debugPrint('USB detector: could not resolve Librescoot USB disk identity, refusing to select a target');
        return null;
      }
      final pickedDiskNum = int.tryParse(RegExp(r'/dev/disk(\d+)').firstMatch(diskPath)?.group(1) ?? '');
      if (pickedDiskNum != usbDiskNum) {
        debugPrint('USB detector: heuristic pick $diskPath does not match USB-identified disk$usbDiskNum, refusing to select a target');
        return null;
      }
      final rawPath = diskPath.replaceFirst('/dev/disk', '/dev/rdisk');
      debugPrint('USB detector: diskutil selected $diskPath (confirmed via USB identity)');

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

      final isRemovable = parseMacRemovable(info) ?? false;
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

  /// Resolve the BSD disk number of the Librescoot USB mass-storage gadget
  /// (VID 0x0525 / PID 0xA4A5). Used to cross-check disk selection against
  /// actual USB device identity instead of trusting the size/label heuristic
  /// alone. Returns null if the device isn't present or its identity can't be
  /// tied to a disk (e.g. it's still in ethernet mode).
  ///
  /// Prefers the IORegistry, which nests the gadget's IOMedia node — and its
  /// "BSD Name" — directly beneath the USB device. The `system_profiler`
  /// scrape is a fallback for older releases only: macOS 26 both renamed the
  /// datatype and dropped "BSD Name" from the USB report entirely, so it
  /// cannot map USB identity to a disk there at all.
  Future<int?> _findLibrescootUsbDiskNumber() async {
    final viaIoreg = await _findUsbDiskNumberViaIoreg();
    if (viaIoreg != null) return viaIoreg;

    try {
      final result = await _runSystemProfilerUsb();
      if (result == null || result.exitCode != 0) return null;
      return _parseUsbDiskNumber(result.stdout.toString());
    } catch (_) {
      return null;
    }
  }

  /// Walk the IORegistry for the Librescoot gadget and return the BSD disk
  /// number of the IOMedia nested beneath it.
  Future<int?> _findUsbDiskNumberViaIoreg() async {
    try {
      final result = await _runWithFallback(
        ['/usr/sbin/ioreg', 'ioreg'],
        ['-r', '-c', 'IOUSBHostDevice', '-l', '-w', '0'],
      );
      if (result == null || result.exitCode != 0) return null;
      return parseIoregDiskNumber(result.stdout.toString());
    } catch (_) {
      return null;
    }
  }

  /// Parse `ioreg -r -c IOUSBHostDevice -l` for the BSD disk number belonging
  /// to VID 0x0525 / PID 0xA4A5.
  ///
  /// ioreg prints each node's properties followed, depth-first, by its
  /// children, and indents every node by its depth in the tree. A device's
  /// "BSD Name" therefore appears after that device's own idVendor/idProduct
  /// lines and at a deeper indent, so a disk can be attributed to the device
  /// that owns it even with other USB storage attached.
  ///
  /// The identity is dropped as soon as a node appears at or above the indent
  /// of the node that published it, which is where that device's subtree ends.
  /// Without that, a device publishing no descriptor properties of its own
  /// would inherit the gadget's identity and hand the flasher its disk. An
  /// identity that cannot be established stays unresolved, and the caller
  /// refuses to pick a target rather than guess.
  @visibleForTesting
  int? parseIoregDiskNumber(String output) {
    final disk = ioregBsdNameUnder(
      output,
      productId: massStoragePid,
      // Whole disks only: matches "disk8", never the "disk8s1" slice.
      bsdRe: RegExp(r'"BSD Name"\s*=\s*"disk(\d+)"', caseSensitive: false),
    );
    return disk == null ? null : int.tryParse(disk);
  }

  /// Parse the same `ioreg -r -c IOUSBHostDevice -l` output for the network
  /// interface macOS published beneath the ethernet gadget (PID 0xA4A2),
  /// e.g. `en12`.
  ///
  /// Same walk as the disk lookup because it is the same tree: a different
  /// driver stack hangs off the device, but the interface it publishes sits
  /// under that device's node exactly as an IOMedia does, and the indent
  /// tracking below is what attributes it to the right device.
  static String? parseIoregEthernetInterface(String output) => ioregBsdNameUnder(
        output,
        productId: ethernetPid,
        bsdRe: RegExp(r'"BSD Name"\s*=\s*"(en\d+)"', caseSensitive: false),
      );

  /// Find a "BSD Name" published somewhere beneath the USB device carrying our
  /// vendor id and [productId], and return the text [bsdRe] captures.
  ///
  /// ioreg prints each node's properties followed, depth-first, by its
  /// children, and indents every node by its depth in the tree. A device's
  /// "BSD Name" therefore appears after that device's own idVendor/idProduct
  /// lines and at a deeper indent, so a node can be attributed to the device
  /// that owns it even with other USB devices attached.
  ///
  /// The identity is dropped as soon as a node appears at or above the indent
  /// of the node that published it, which is where that device's subtree ends.
  /// Without that, a device publishing no descriptor properties of its own
  /// would inherit the gadget's identity and hand the caller something that
  /// belongs to someone else. An identity that cannot be established stays
  /// unresolved, and the caller refuses rather than guessing.
  ///
  /// Depth-agnostic on purpose: it takes the first match at any depth in the
  /// subtree rather than expecting a particular chain of intermediate driver
  /// nubs, which differ between the storage and network stacks and between
  /// macOS releases.
  @visibleForTesting
  static String? ioregBsdNameUnder(
    String output, {
    required int productId,
    required RegExp bsdRe,
  }) {
    // ioreg prints these in decimal, but accept the hex form too: the rest of
    // this file does, and misreading an id here costs a flash target.
    final vendorRe =
        RegExp(r'"idVendor"\s*=\s*(0x[0-9a-f]+|\d+)', caseSensitive: false);
    final productRe =
        RegExp(r'"idProduct"\s*=\s*(0x[0-9a-f]+|\d+)', caseSensitive: false);

    int? lastVendor;
    int? lastProduct;
    int? nodeIndent;
    int? identityIndent;

    for (final line in output.split('\n')) {
      final header = line.indexOf('+-o ');
      if (header >= 0) {
        if (identityIndent != null && header <= identityIndent) {
          lastVendor = null;
          lastProduct = null;
          identityIndent = null;
        }
        nodeIndent = header;
        continue;
      }

      final vendor = vendorRe.firstMatch(line);
      if (vendor != null) {
        lastVendor = int.tryParse(vendor.group(1)!);
        identityIndent = nodeIndent;
      }
      final product = productRe.firstMatch(line);
      if (product != null) {
        lastProduct = int.tryParse(product.group(1)!);
        identityIndent = nodeIndent;
      }

      final bsd = bsdRe.firstMatch(line);
      if (bsd != null &&
          lastVendor == targetVendorId &&
          lastProduct == productId) {
        return bsd.group(1);
      }
    }
    return null;
  }

  /// Parse `system_profiler SPUSBDataType` plain-text output for the BSD
  /// disk number of the device reporting Vendor ID 0x0525 and Product ID
  /// 0xa4a5. Vendor ID and Product ID are adjacent lines in the same device
  /// block (order varies by macOS version), and its BSD Name (if any) is a
  /// nested "Media" entry further down in that same block, before the next
  /// device's Product ID line.
  int? _parseUsbDiskNumber(String output) {
    final lines = output.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].toLowerCase();
      if (!line.contains('vendor id: 0x0525')) continue;

      final windowStart = (i - 5).clamp(0, lines.length);
      final windowEnd = (i + 5).clamp(0, lines.length);
      final window = lines.sublist(windowStart, windowEnd).join('\n').toLowerCase();
      if (!window.contains('product id: 0xa4a5')) continue;

      for (var j = i + 1; j < lines.length; j++) {
        if (RegExp(r'product id:', caseSensitive: false).hasMatch(lines[j])) break;
        final bsdMatch = RegExp(r'BSD Name:\s*disk(\d+)', caseSensitive: false).firstMatch(lines[j]);
        if (bsdMatch != null) {
          return int.tryParse(bsdMatch.group(1)!);
        }
      }
      return null;
    }
    return null;
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

      // Not `return null`: lsusb exits 1 when nothing matches, and a board in
      // serial-download mode is 15a2, never 0525. Returning here made the SDP
      // checks at the bottom of this method unreachable in exactly the case
      // they exist for, so a board sitting in its boot ROM read as no board
      // at all for as long as it sat there.
      if (result.exitCode != 0) return _detectLinuxRecovery();

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

    return _detectLinuxRecovery();
  }

  /// The i.MX Boot ROM's own USB identity, which is what is on the bus when
  /// the board found nothing bootable. See _detectMacOSIoreg for the protocol
  /// notes.
  Future<UsbDevice?> _detectLinuxRecovery() async {
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
    // Match the block device to the MDB's USB VID:PID (0525:A4A5). The old
    // "first block device with TRAN=usb" grabbed whatever else was plugged in
    // — an SD-card reader at /dev/sda, a USB stick — and we'd target the wrong
    // disk. Walk sysfs and accept only a device whose USB ancestor is the MDB
    // gadget. No match -> null; never fall back to guessing /dev/sda.
    try {
      final blockDir = Directory('/sys/block');
      if (!blockDir.existsSync()) return null;
      final names = blockDir
          .listSync()
          .map((e) => e.path.split('/').last)
          .where((n) => n.startsWith('sd'))
          .toList()
        ..sort();
      for (final name in names) {
        if (_linuxBlockIsMdb(name)) return '/dev/$name';
      }
    } catch (_) {}
    return null;
  }

  /// True if `/sys/block/<name>` sits under the MDB USB gadget (idVendor 0525,
  /// idProduct a4a5). Resolves the sysfs symlink and walks up to the first
  /// ancestor exposing idVendor/idProduct (the USB device node).
  bool _linuxBlockIsMdb(String name) {
    try {
      final real = Directory('/sys/block/$name').resolveSymbolicLinksSync();
      var dir = Directory(real);
      for (var i = 0; i < 12 && dir.path.length > 1; i++) {
        final vid = File('${dir.path}/idVendor');
        final pid = File('${dir.path}/idProduct');
        if (vid.existsSync() && pid.existsSync()) {
          final v = vid.readAsStringSync().trim().toLowerCase();
          final p = pid.readAsStringSync().trim().toLowerCase();
          return v == '0525' && p == 'a4a5';
        }
        dir = dir.parent;
      }
    } catch (_) {}
    return false;
  }

  /// Sanitize WMIC output (remove null bytes and other artifacts)

  void dispose() {
    stopMonitoring();
    _deviceController.close();
  }
}
