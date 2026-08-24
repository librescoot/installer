import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/flash_service.dart';

/// Regression tests for the pre-write device guard.
///
/// This guard existed for months without a single call site, so a wrong
/// device path would have gone straight to the flasher. It is now called from
/// _flashMdb immediately before writeTwoPhase. These tests pin the cases that
/// must never pass, so a future refactor can't quietly weaken them again.
void main() {
  final flash = FlashService();

  // A device that should pass everywhere: correct gadget VID/PID, removable,
  // not a system disk, 8 GB, platform-appropriate path.
  SafetyCheck checkGood() => flash.validateDevice(
        devicePath: _goodPath,
        sizeBytes: 8 * 1024 * 1024 * 1024,
        isRemovable: true,
        isSystemDisk: false,
        vendorId: 0x0525,
        productId: 0xA4A5,
      );

  test('a genuine mass-storage gadget passes', () {
    final result = checkGood();
    expect(result.passed, isTrue, reason: result.errors.join('; '));
    expect(result.errors, isEmpty);
  });

  test('a system disk is refused', () {
    final result = flash.validateDevice(
      devicePath: _goodPath,
      sizeBytes: 8 * 1024 * 1024 * 1024,
      isRemovable: true,
      isSystemDisk: true,
      vendorId: 0x0525,
      productId: 0xA4A5,
    );
    expect(result.passed, isFalse);
    expect(result.errors.join(' '), contains('system disk'));
  });

  test('a foreign vendor id is refused', () {
    final result = flash.validateDevice(
      devicePath: _goodPath,
      sizeBytes: 8 * 1024 * 1024 * 1024,
      isRemovable: true,
      isSystemDisk: false,
      vendorId: 0x1234,
      productId: 0xA4A5,
    );
    expect(result.passed, isFalse);
    expect(result.errors.join(' '), contains('vendor ID'));
  });

  test('RNDIS mode (PID A4A2) is refused, only mass storage may be written', () {
    final result = flash.validateDevice(
      devicePath: _goodPath,
      sizeBytes: 8 * 1024 * 1024 * 1024,
      isRemovable: true,
      isSystemDisk: false,
      vendorId: 0x0525,
      productId: 0xA4A2,
    );
    expect(result.passed, isFalse);
    expect(result.errors.join(' '), contains('product ID'));
  });

  test('an implausibly large disk is refused', () {
    final result = flash.validateDevice(
      devicePath: _goodPath,
      sizeBytes: 2000 * 1024 * 1024 * 1024, // 2 TB, i.e. someone's laptop disk
      isRemovable: true,
      isSystemDisk: false,
      vendorId: 0x0525,
      productId: 0xA4A5,
    );
    expect(result.passed, isFalse);
    expect(result.errors.join(' '), contains('too large'));
  });

  test('an implausibly small disk is refused', () {
    final result = flash.validateDevice(
      devicePath: _goodPath,
      sizeBytes: 512 * 1024 * 1024,
      isRemovable: true,
      isSystemDisk: false,
      vendorId: 0x0525,
      productId: 0xA4A5,
    );
    expect(result.passed, isFalse);
    expect(result.errors.join(' '), contains('too small'));
  });

  test('an unknown size warns but does not block', () {
    final result = flash.validateDevice(
      devicePath: _goodPath,
      sizeBytes: null,
      isRemovable: true,
      isSystemDisk: false,
      vendorId: 0x0525,
      productId: 0xA4A5,
    );
    expect(result.passed, isTrue, reason: result.errors.join('; '));
    expect(result.warnings.join(' '), contains('size'));
  });

  test('the platform system-disk path is refused even with a valid identity', () {
    final result = flash.validateDevice(
      devicePath: _systemPath,
      sizeBytes: 8 * 1024 * 1024 * 1024,
      isRemovable: true,
      isSystemDisk: false, // deliberately lying; the path check must still bite
      vendorId: 0x0525,
      productId: 0xA4A5,
    );
    expect(result.passed, isFalse);
    expect(result.errors.join(' '), contains('DANGER'));
  });

  test('an empty device path is refused', () {
    final result = flash.validateDevice(
      devicePath: '',
      sizeBytes: 8 * 1024 * 1024 * 1024,
      isRemovable: true,
      isSystemDisk: false,
      vendorId: 0x0525,
      productId: 0xA4A5,
    );
    expect(result.passed, isFalse);
    expect(result.errors, isNotEmpty);
  });

  group('the detected path and the target path must agree', () {
    // The scooter's own identity is what makes a stale pair dangerous: VID,
    // PID, size and removability all come from the arrived device and pass on
    // their own merits, while the path still names the one that left.
    SafetyCheck checkPair({required String detected, required String target}) =>
        flash.validateDevice(
          devicePath: target,
          sizeBytes: 8 * 1024 * 1024 * 1024,
          isRemovable: true,
          isSystemDisk: false,
          vendorId: 0x0525,
          productId: 0xA4A5,
          detectedPath: detected,
        );

    test('a mismatched pair is refused', () {
      final result = checkPair(detected: _goodPath, target: _otherPath);
      expect(result.passed, isFalse);
      expect(result.errors.join('; '), contains('does not match'));
    });

    test('a matching pair passes', () {
      final result = checkPair(detected: _goodPath, target: _goodPath);
      expect(result.passed, isTrue, reason: result.errors.join('; '));
    });

    test('no detected path means no claim, and no refusal', () {
      // macOS resolves the path separately and can legitimately have nothing
      // to compare. Refusing there would block a good flash on missing data.
      expect(checkPair(detected: '', target: _goodPath).passed, isTrue);
      final result = flash.validateDevice(
        devicePath: _goodPath,
        sizeBytes: 8 * 1024 * 1024 * 1024,
        isRemovable: true,
        isSystemDisk: false,
        vendorId: 0x0525,
        productId: 0xA4A5,
      );
      expect(result.passed, isTrue, reason: result.errors.join('; '));
    });

    test('a mismatch inside the size window is still refused', () {
      // The dangerous shape: an SD card or an old stick, 1-16 GB, so the size
      // window never fires and the identity is the scooter's by construction.
      final result = checkPair(detected: _goodPath, target: _otherPath);
      expect(result.passed, isFalse);
    });
  });
}

/// A plausible target path for the host we happen to be running the suite on.
String get _goodPath {
  if (Platform.isWindows) return r'\\.\PHYSICALDRIVE3';
  if (Platform.isMacOS) return '/dev/rdisk4';
  return '/dev/sdb';
}

/// The path the guard must always refuse on this host.
String get _systemPath {
  if (Platform.isWindows) return r'\\.\PHYSICALDRIVE0';
  if (Platform.isMacOS) return '/dev/rdisk0';
  return '/dev/sda';
}

/// A second valid-looking target on this host, for the stale-path case.
String get _otherPath {
  if (Platform.isWindows) return r'\\.\PHYSICALDRIVE7';
  if (Platform.isMacOS) return '/dev/rdisk7';
  return '/dev/sdc';
}
