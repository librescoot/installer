import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

/// Result of a driver installation attempt.
class DriverInstallResult {
  final bool success;
  final String? error;
  final bool alreadyInstalled;

  const DriverInstallResult({
    required this.success,
    this.error,
    this.alreadyInstalled = false,
  });

  factory DriverInstallResult.alreadyInstalled() => const DriverInstallResult(
        success: true,
        alreadyInstalled: true,
      );

  factory DriverInstallResult.installed() => const DriverInstallResult(
        success: true,
      );

  factory DriverInstallResult.failed(String error) => DriverInstallResult(
        success: false,
        error: error,
      );
}

/// Current binding state for the Librescoot ethernet device.
enum DriverBinding {
  /// Device is bound to our RNDIS driver (or another Net-class RNDIS driver).
  correct,

  /// Device is bound to a non-Net driver (usbser/Ports, modem, …) that
  /// hijacked it before our INF could take effect.
  wrongDriver,

  /// Device is enumerated but has no functional driver yet.
  noDriver,

  /// Device is not currently present.
  notPresent,
}

/// Snapshot of the device's driver binding, used to decide whether a forced
/// rebind is needed during install.
class DriverDiagnosis {
  final DriverBinding state;
  final String? instanceId;
  final String? currentClass;
  final String? currentService;

  const DriverDiagnosis(
    this.state, {
    this.instanceId,
    this.currentClass,
    this.currentService,
  });

  @override
  String toString() => 'DriverDiagnosis(${state.name}, '
      'class=$currentClass, service=$currentService, id=$instanceId)';
}

/// Service for managing Windows RNDIS driver installation.
///
/// On Windows, the Librescoot MDB uses USB RNDIS (Ethernet over USB).
/// This service checks if the driver is installed and installs it if needed.
class DriverService {
  static const String _driverInfAsset = 'assets/drivers/RNDIS.inf';
  static const String _driverCatAsset = 'assets/drivers/rndis.cat';
  static const String _driverInfName = 'RNDIS.inf';
  static const String _driverCatName = 'rndis.cat';

  /// Check if an RNDIS driver is already installed.
  ///
  /// Uses `pnputil /enum-drivers` and searches for the Acer RNDIS driver
  /// Uses `pnputil /enum-drivers` and checks for the RNDIS INF or provider.
  static Future<bool> isDriverInstalled() async {
    if (!Platform.isWindows) return true;

    try {
      final result = await Process.run(
        'pnputil',
        ['/enum-drivers'],
        runInShell: true,
      );

      if (result.exitCode != 0) {
        return false;
      }

      final output = result.stdout.toString().toLowerCase();
      // Check for our RNDIS driver (RNDIS.inf / g_rndis.inf) or Acer RNDIS
      return output.contains('rndis.inf') ||
          output.contains('g_rndis.inf');
    } catch (e) {
      return false;
    }
  }

  /// Diagnose the current driver binding for the Librescoot ethernet device.
  ///
  /// Inspects PnP class and service via PowerShell so we can tell apart:
  ///   * correct binding (Net + RNDIS service),
  ///   * a hijacking driver (usbser claiming it as a Ports/COM device, modem
  ///     class, etc.) that needs a forced rebind, and
  ///   * a brand-new device with no driver yet (the easy case).
  static Future<DriverDiagnosis> diagnoseBinding() async {
    if (!Platform.isWindows) {
      return const DriverDiagnosis(DriverBinding.correct);
    }

    try {
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        r'''
$d = Get-PnpDevice -PresentOnly | Where-Object { $_.InstanceId -like "*VID_0525&PID_A4A2*" } | Select-Object -First 1
if ($d) {
  $svc = (Get-PnpDeviceProperty -InstanceId $d.InstanceId -KeyName 'DEVPKEY_Device_Service' -ErrorAction SilentlyContinue).Data
  "$($d.InstanceId)`t$($d.Class)`t$svc"
}
''',
      ]);

      if (result.exitCode != 0) {
        return const DriverDiagnosis(DriverBinding.notPresent);
      }

      final line = result.stdout.toString().trim();
      if (line.isEmpty) {
        return const DriverDiagnosis(DriverBinding.notPresent);
      }

      final parts = line.split('\t');
      final instanceId = parts.isNotEmpty ? parts[0].trim() : '';
      final cls = parts.length > 1 ? parts[1].trim().toLowerCase() : '';
      final svc = parts.length > 2 ? parts[2].trim().toLowerCase() : '';

      if (cls == 'net' && svc.contains('rndis')) {
        return DriverDiagnosis(
          DriverBinding.correct,
          instanceId: instanceId,
          currentClass: cls,
          currentService: svc,
        );
      }

      // No driver bound yet — Windows reports class as USBDevice or leaves the
      // service blank.
      if (cls == 'usbdevice' || cls.isEmpty || svc.isEmpty) {
        return DriverDiagnosis(
          DriverBinding.noDriver,
          instanceId: instanceId,
          currentClass: cls,
          currentService: svc,
        );
      }

      // Anything else (Ports/usbser, Modem, …) is something we need to evict.
      return DriverDiagnosis(
        DriverBinding.wrongDriver,
        instanceId: instanceId,
        currentClass: cls,
        currentService: svc,
      );
    } catch (e) {
      debugPrint('Driver: diagnoseBinding failed: $e');
      return const DriverDiagnosis(DriverBinding.notPresent);
    }
  }

  /// Install the Librescoot RNDIS driver from bundled assets.
  ///
  /// Stages `RNDIS.inf` via `pnputil /add-driver /install` and, if another
  /// driver (usbser, modem, …) had already claimed the device, forces a
  /// rebind so the more-specific hardware-ID match in our INF wins.
  static Future<DriverInstallResult> installDriver() async {
    if (!Platform.isWindows) {
      return DriverInstallResult.alreadyInstalled();
    }

    final pre = await diagnoseBinding();
    debugPrint('Driver: pre-install diagnosis: $pre');

    // Already correctly bound — nothing to do, regardless of what's in the
    // driver store. (Covers users who already had the driver from a previous
    // install or from a similar device.)
    if (pre.state == DriverBinding.correct) {
      return DriverInstallResult.alreadyInstalled();
    }

    // If the device isn't present and we already have the driver staged,
    // there's nothing more to do until the user plugs in.
    if (pre.state == DriverBinding.notPresent && await isDriverInstalled()) {
      return DriverInstallResult.alreadyInstalled();
    }

    String? infPath;
    try {
      infPath = await _extractDriverFiles();

      // Stage + install. Idempotent; safe to run even if the INF is already
      // in the driver store.
      final add = await Process.run(
        'pnputil',
        ['/add-driver', infPath, '/install'],
        runInShell: true,
      );

      if (add.exitCode != 0) {
        final stderr = add.stderr.toString().trim();
        final stdout = add.stdout.toString().trim();
        final errorMsg = stderr.isNotEmpty ? stderr : stdout;
        return DriverInstallResult.failed(
          'pnputil failed (exit ${add.exitCode}): $errorMsg',
        );
      }

      // If something else had already claimed the device, /add-driver /install
      // alone won't displace it — Windows only auto-binds to devices that have
      // no driver yet. Force a rebind by removing the device node and
      // re-enumerating.
      if (pre.state == DriverBinding.wrongDriver && pre.instanceId != null) {
        debugPrint('Driver: evicting ${pre.currentClass}/${pre.currentService} '
            'on ${pre.instanceId}');
        await _forceRebind(pre.instanceId!);
      }

      // Poll for up to ~10s to let Windows finish re-enumeration / driver
      // ranking before we declare success or failure.
      final post = await _waitForCorrectBinding(
        const Duration(seconds: 10),
      );
      debugPrint('Driver: post-install diagnosis: $post');

      if (post.state == DriverBinding.correct) {
        return DriverInstallResult.installed();
      }

      // notPresent after a successful /add-driver is fine — the user just
      // hasn't plugged in (or unplugged during install). Treat as installed
      // so the UI can move on.
      if (post.state == DriverBinding.notPresent) {
        return DriverInstallResult.installed();
      }

      return DriverInstallResult.failed(
        'Driver staged but binding is still ${post.state.name} '
        '(class=${post.currentClass}, service=${post.currentService})',
      );
    } catch (e) {
      return DriverInstallResult.failed('Failed to install driver: $e');
    } finally {
      if (infPath != null) {
        try {
          await File(infPath).delete();
          await Directory(path.dirname(infPath)).delete();
        } catch (_) {
          // Ignore cleanup errors
        }
      }
    }
  }

  /// Remove the device node and trigger re-enumeration so the most-specific
  /// staged INF (ours) wins driver ranking. Falls back to a disable/enable
  /// cycle on Windows builds where `/remove-device` isn't available.
  ///
  /// Caller must have already staged the INF via `pnputil /add-driver
  /// /install`. Requires admin (which the caller already has — `/add-driver`
  /// needs it too).
  static Future<bool> _forceRebind(String instanceId) async {
    // /remove-device exists on Win10 2004+. Pass the InstanceId as a single
    // argv element with runInShell: false so cmd.exe never sees the embedded
    // '&' characters.
    final remove = await Process.run(
      'pnputil',
      ['/remove-device', instanceId],
      runInShell: false,
    );

    if (remove.exitCode != 0) {
      debugPrint(
        'Driver: pnputil /remove-device failed (${remove.exitCode}): '
        '${remove.stderr.toString().trim()} — falling back to disable/enable',
      );
      // Fallback for older builds: bounce the device.
      await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        'Disable-PnpDevice -InstanceId "$instanceId" -Confirm:\$false; '
            'Start-Sleep -Milliseconds 500; '
            'Enable-PnpDevice  -InstanceId "$instanceId" -Confirm:\$false',
      ]);
    }

    final scan = await Process.run('pnputil', ['/scan-devices']);
    return scan.exitCode == 0;
  }

  /// Poll [diagnoseBinding] until it returns a non-transient state
  /// (`correct`, `wrongDriver`, or `notPresent`) or [timeout] elapses.
  /// Returns the most recent diagnosis.
  static Future<DriverDiagnosis> _waitForCorrectBinding(
    Duration timeout, {
    Duration interval = const Duration(milliseconds: 500),
  }) async {
    final deadline = DateTime.now().add(timeout);
    DriverDiagnosis last = await diagnoseBinding();
    while (DateTime.now().isBefore(deadline)) {
      if (last.state == DriverBinding.correct) return last;
      await Future.delayed(interval);
      last = await diagnoseBinding();
    }
    return last;
  }

  /// Stop the ShellHWDetection service to prevent "format this disk" popups
  /// when the device enters USB Mass Storage mode.
  static Future<void> suppressAutoPlay() async {
    if (!Platform.isWindows) return;
    try {
      debugPrint('Driver: stopping ShellHWDetection service');
      await Process.run('net', ['stop', 'ShellHWDetection']);
    } catch (e) {
      debugPrint('Driver: failed to stop ShellHWDetection: $e');
    }
  }

  /// Restart the ShellHWDetection service after flashing is complete.
  static Future<void> restoreAutoPlay() async {
    if (!Platform.isWindows) return;
    try {
      debugPrint('Driver: starting ShellHWDetection service');
      await Process.run('net', ['start', 'ShellHWDetection']);
    } catch (e) {
      debugPrint('Driver: failed to start ShellHWDetection: $e');
    }
  }

  /// Extract the driver INF and CAT from assets to a temp directory.
  static Future<String> _extractDriverFiles() async {
    // Create temp directory
    final tempDir = await Directory.systemTemp.createTemp('librescoot_driver_');

    // Extract INF
    final infContent = await rootBundle.loadString(_driverInfAsset);
    final infPath = path.join(tempDir.path, _driverInfName);
    await File(infPath).writeAsString(infContent);

    // Extract CAT (binary file)
    final catData = await rootBundle.load(_driverCatAsset);
    final catPath = path.join(tempDir.path, _driverCatName);
    await File(catPath).writeAsBytes(catData.buffer.asUint8List());

    return infPath;
  }
}
