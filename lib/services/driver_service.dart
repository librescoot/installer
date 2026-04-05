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

/// Service for managing Windows RNDIS driver installation.
///
/// On Windows, the LibreScoot MDB uses USB RNDIS (Ethernet over USB).
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

  /// Install the LibreScoot RNDIS driver from bundled assets.
  ///
  /// Extracts the INF file to a temp directory and runs:
  /// `pnputil /add-driver <path> /install`
  static Future<DriverInstallResult> installDriver() async {
    if (!Platform.isWindows) {
      return DriverInstallResult.alreadyInstalled();
    }

    // Check if already installed
    if (await isDriverInstalled()) {
      return DriverInstallResult.alreadyInstalled();
    }

    try {
      // Extract INF and CAT to temp directory
      final infPath = await _extractDriverFiles();

      // Install driver using pnputil
      final result = await Process.run(
        'pnputil',
        ['/add-driver', infPath, '/install'],
        runInShell: true,
      );

      // Clean up temp file
      try {
        await File(infPath).delete();
        await Directory(path.dirname(infPath)).delete();
      } catch (_) {
        // Ignore cleanup errors
      }

      if (result.exitCode == 0) {
        return DriverInstallResult.installed();
      } else {
        final stderr = result.stderr.toString().trim();
        final stdout = result.stdout.toString().trim();
        final errorMsg = stderr.isNotEmpty ? stderr : stdout;
        return DriverInstallResult.failed(
          'pnputil failed (exit ${result.exitCode}): $errorMsg',
        );
      }
    } catch (e) {
      return DriverInstallResult.failed('Failed to install driver: $e');
    }
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
