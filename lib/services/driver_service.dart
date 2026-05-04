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

/// Captured output of a logged subprocess invocation.
class _RunResult {
  final int exitCode;
  final String stdout;
  final String stderr;

  _RunResult(this.exitCode, this.stdout, this.stderr);

  bool get ok => exitCode == 0;

  String get combined {
    final s = stderr.trim();
    final o = stdout.trim();
    if (s.isNotEmpty && o.isNotEmpty) return '$o\n$s';
    return s.isNotEmpty ? s : o;
  }
}

/// Outcome of a forced INF -> hardware-ID install via newdev.dll.
class _ForceInstallOutcome {
  final bool ok;
  final bool rebootRequired;
  final String detail;

  _ForceInstallOutcome(this.ok, this.rebootRequired, this.detail);
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

  /// Hardware ID of the Librescoot ethernet device. Used for both PnP
  /// enumeration matching and as the target of forced INF installs.
  static const String _hardwareId = r'USB\VID_0525&PID_A4A2';

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

      // No driver bound yet: Windows reports class as USBDevice or leaves the
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
  /// Stages `RNDIS.inf` via `pnputil /add-driver /install` and, if a wrong
  /// driver (usbser, modem, …) had already claimed the device, forces a
  /// rebind by calling `newdev.dll!UpdateDriverForPlugAndPlayDevicesW` with
  /// `INSTALLFLAG_FORCE` against the hardware ID. Falls back to the legacy
  /// remove+scan rebind if the force install does not converge.
  static Future<DriverInstallResult> installDriver() async {
    if (!Platform.isWindows) {
      return DriverInstallResult.alreadyInstalled();
    }

    final pre = await diagnoseBinding();
    debugPrint('Driver: pre-install diagnosis: $pre');

    // Already correctly bound: nothing to do, regardless of what's in the
    // driver store. (Covers users who already had the driver from a previous
    // install or from a similar device.)
    if (pre.state == DriverBinding.correct) {
      return DriverInstallResult.alreadyInstalled();
    }

    String? infPath;
    try {
      infPath = await _extractDriverFiles();
      debugPrint('Driver: extracted INF to $infPath');

      // Stage + install. Idempotent; safe to run even if the INF is already
      // in the driver store. /install auto-binds to any matching device that
      // has no driver yet but cannot displace an existing binding.
      final add = await _runLogged(
        'pnputil-add',
        'pnputil',
        ['/add-driver', infPath, '/install'],
        runInShell: true,
      );
      if (!add.ok) {
        return DriverInstallResult.failed(
          'pnputil /add-driver failed (exit ${add.exitCode}): ${add.combined}',
        );
      }

      // No device to rebind right now: INF is staged, Windows will pick it
      // up when the user plugs in.
      if (pre.state == DriverBinding.notPresent) {
        debugPrint('Driver: device not present: INF staged for plug-in');
        return DriverInstallResult.installed();
      }

      // Force-install our INF onto the matching hardware ID. This bypasses
      // driver ranking entirely and rebinds even when usbser (or a modem
      // class) is currently claiming the device.
      final forced = await _forceInstallByHardwareId(infPath);
      debugPrint('Driver: force-install ok=${forced.ok} '
          'reboot=${forced.rebootRequired} detail=${forced.detail}');

      var post = await _waitForCorrectBinding(const Duration(seconds: 10));
      debugPrint('Driver: post-force-install diagnosis: $post');

      if (post.state == DriverBinding.correct) {
        return DriverInstallResult.installed();
      }

      // Force-install didn't take. Last-ditch fallback: remove the device
      // node and re-scan so Windows re-runs ranking. Useful when newdev.dll
      // returned an unexpected error (e.g. on Windows builds with unusual
      // policy).
      if (pre.instanceId != null) {
        debugPrint('Driver: force-install did not converge: '
            'falling back to remove+scan rebind on ${pre.instanceId}');
        await _forceRebind(pre.instanceId!);
        post = await _waitForCorrectBinding(const Duration(seconds: 10));
        debugPrint('Driver: post-fallback diagnosis: $post');
      }

      if (post.state == DriverBinding.correct) {
        return DriverInstallResult.installed();
      }

      // notPresent after a successful staging is fine: the user just
      // unplugged during install. Treat as installed so the UI can move on.
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

  /// Force the staged INF onto the Librescoot hardware ID via
  /// `newdev.dll!UpdateDriverForPlugAndPlayDevicesW` with `INSTALLFLAG_FORCE`
  /// (= 0x1). This is the documented "rebind regardless of current driver"
  /// API: equivalent to `devcon update`: and bypasses driver ranking.
  ///
  /// Caller must have already staged the INF via `pnputil /add-driver
  /// /install`. Requires admin (which the caller already has).
  static Future<_ForceInstallOutcome> _forceInstallByHardwareId(
    String infPath,
  ) async {
    // Pass paths/IDs through the environment so PowerShell never sees
    // backslashes or ampersands as syntax. The script reads them via
    // `$env:LIBRESCOOT_INF` / `$env:LIBRESCOOT_HWID`.
    const script = r'''
$ErrorActionPreference = 'Continue'
$inf  = $env:LIBRESCOOT_INF
$hwid = $env:LIBRESCOOT_HWID
if (-not $inf -or -not $hwid) {
    Write-Output "FAILED missing-env inf=$inf hwid=$hwid"
    exit 2
}
$src = @"
using System;
using System.Runtime.InteropServices;
public class NewDev {
    [DllImport("newdev.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    public static extern bool UpdateDriverForPlugAndPlayDevices(
        IntPtr hwndParent, string HardwareId, string FullInfPath,
        uint InstallFlags, out bool bRebootRequired);
}
"@
try {
    Add-Type -TypeDefinition $src -ErrorAction Stop
} catch {
    Write-Output "FAILED add-type $($_.Exception.Message)"
    exit 2
}
$reboot = $false
$ok = [NewDev]::UpdateDriverForPlugAndPlayDevices(
    [IntPtr]::Zero, $hwid, $inf, 1, [ref]$reboot
)
if ($ok) {
    Write-Output "OK reboot=$reboot"
    exit 0
} else {
    $gle = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
    $msg = (New-Object System.ComponentModel.Win32Exception $gle).Message
    Write-Output "FAILED gle=$gle msg=$msg"
    exit 1
}
''';

    final r = await _runLogged(
      'force-install',
      'powershell',
      ['-NoProfile', '-NonInteractive', '-Command', script],
      runInShell: false,
      environment: {
        'LIBRESCOOT_INF': infPath,
        'LIBRESCOOT_HWID': _hardwareId,
      },
    );
    final detail = r.combined.trim();
    final reboot = detail.contains('reboot=True');
    return _ForceInstallOutcome(
      r.ok,
      reboot,
      detail.isEmpty ? '(no output)' : detail,
    );
  }

  /// Remove the device node and trigger re-enumeration so the most-specific
  /// staged INF (ours) wins driver ranking. Falls back to a disable/enable
  /// cycle on Windows builds where `/remove-device` isn't available. Used as
  /// a last-ditch fallback when [_forceInstallByHardwareId] fails to converge.
  static Future<bool> _forceRebind(String instanceId) async {
    // /remove-device exists on Win10 2004+. Pass the InstanceId as a single
    // argv element with runInShell: false so cmd.exe never sees the embedded
    // '&' characters.
    final remove = await _runLogged(
      'pnputil-remove',
      'pnputil',
      ['/remove-device', instanceId],
      runInShell: false,
    );

    if (!remove.ok) {
      debugPrint(
        'Driver: pnputil /remove-device failed: '
        'falling back to disable/enable cycle',
      );
      // Fallback for older builds: bounce the device.
      await _runLogged(
        'disable-enable',
        'powershell',
        [
          '-NoProfile',
          '-Command',
          'Disable-PnpDevice -InstanceId "$instanceId" -Confirm:\$false; '
              'Start-Sleep -Milliseconds 500; '
              'Enable-PnpDevice  -InstanceId "$instanceId" -Confirm:\$false',
        ],
        runInShell: false,
      );
    }

    final scan = await _runLogged(
      'pnputil-scan',
      'pnputil',
      ['/scan-devices'],
      runInShell: true,
    );
    return scan.ok;
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

  /// Run a subprocess and pipe its stdout/stderr line-by-line into
  /// `debugPrint` under a labelled prefix so field logs make it obvious
  /// what each command did. Returns a [_RunResult] for callers that need to
  /// branch on the outcome.
  static Future<_RunResult> _runLogged(
    String label,
    String executable,
    List<String> args, {
    bool runInShell = false,
    Map<String, String>? environment,
  }) async {
    debugPrint('Driver[$label]: $executable ${args.join(' ')}');
    try {
      final r = await Process.run(
        executable,
        args,
        runInShell: runInShell,
        environment: environment,
      );
      final out = r.stdout.toString();
      final err = r.stderr.toString();
      debugPrint('Driver[$label]: exit=${r.exitCode}');
      _logLines('Driver[$label]: stdout', out);
      _logLines('Driver[$label]: stderr', err);
      return _RunResult(r.exitCode, out, err);
    } catch (e) {
      debugPrint('Driver[$label]: exception: $e');
      return _RunResult(-1, '', e.toString());
    }
  }

  static void _logLines(String prefix, String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return;
    for (final line in trimmed.split(RegExp(r'\r?\n'))) {
      final l = line.trimRight();
      if (l.isNotEmpty) debugPrint('$prefix: $l');
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
