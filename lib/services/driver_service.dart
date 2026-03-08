import 'dart:io';
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
  static const String _driverInfAsset = 'assets/drivers/librescoot_rndis.inf';
  static const String _driverInfName = 'librescoot_rndis.inf';

  /// Check if the LibreScoot RNDIS driver is already installed.
  ///
  /// Uses `pnputil /enum-drivers` and searches for "librescoot" in the output.
  static Future<bool> isDriverInstalled() async {
    if (!Platform.isWindows) return true;

    try {
      final result = await Process.run(
        'pnputil',
        ['/enum-drivers'],
        runInShell: true,
      );

      if (result.exitCode != 0) {
        // pnputil failed, assume driver not installed
        return false;
      }

      final output = result.stdout.toString().toLowerCase();
      // Check for our driver by looking for "librescoot" in the output
      return output.contains('librescoot');
    } catch (e) {
      // If we can't check, assume not installed
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
      // Extract INF to temp directory
      final infPath = await _extractDriverInf();

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

  /// Extract the driver INF from assets to a temp directory.
  static Future<String> _extractDriverInf() async {
    // Load INF from assets
    final infContent = await rootBundle.loadString(_driverInfAsset);

    // Create temp directory
    final tempDir = await Directory.systemTemp.createTemp('librescoot_driver_');
    final infPath = path.join(tempDir.path, _driverInfName);

    // Write INF to temp file
    await File(infPath).writeAsString(infContent);

    return infPath;
  }
}
