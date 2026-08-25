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
        sizeBytes: FlashService.mdbEmmcBytes,
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
      sizeBytes: FlashService.mdbEmmcBytes,
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
      sizeBytes: FlashService.mdbEmmcBytes,
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
      sizeBytes: FlashService.mdbEmmcBytes,
      isRemovable: true,
      isSystemDisk: false,
      vendorId: 0x0525,
      productId: 0xA4A2,
    );
    expect(result.passed, isFalse);
    expect(result.errors.join(' '), contains('product ID'));
  });

  test('a disk that is not the MDB eMMC is refused, however plausible', () {
    // 2 TB is someone's laptop disk; 8 GB is an ordinary USB stick. Neither
    // is the eMMC, and only the eMMC may be written.
    for (final size in [
      2000 * 1024 * 1024 * 1024,
      8 * 1024 * 1024 * 1024,
      512 * 1024 * 1024,
    ]) {
      final result = flash.validateDevice(
        devicePath: _goodPath,
        sizeBytes: size,
        isRemovable: true,
        isSystemDisk: false,
        vendorId: 0x0525,
        productId: 0xA4A5,
      );
      expect(result.passed, isFalse, reason: 'size $size was accepted');
      expect(result.errors.join('; '), contains('Unexpected device size'));
    }
  });

  test('a failed eMMC is named as such, not called a small disk', () {
    final result = flash.validateDevice(
      devicePath: _goodPath,
      sizeBytes: 32 * 1024 * 1024,
      isRemovable: true,
      isSystemDisk: false,
      vendorId: 0x0525,
      productId: 0xA4A5,
    );
    expect(result.passed, isFalse);
    expect(result.errors.join('; '), contains('has failed'));
  });

  test('the eMMC size must match exactly', () {
    // Win32_DiskDrive.Size reads up to one cylinder low (8225280 bytes at
    // 255x63x512), which is why the Windows detector sources the size from
    // Get-Disk instead. A truncated figure reaching here is a bug, not a
    // tolerance case.
    for (final size in [
      FlashService.mdbEmmcBytes - 8225280,
      FlashService.mdbEmmcBytes - 512,
      FlashService.mdbEmmcBytes + 512,
    ]) {
      final result = flash.validateDevice(
        devicePath: _goodPath,
        sizeBytes: size,
        isRemovable: true,
        isSystemDisk: false,
        vendorId: 0x0525,
        productId: 0xA4A5,
      );
      expect(result.passed, isFalse, reason: 'size \$size was accepted');
    }
  });

  test('an unknown size stops the flash on Windows', () {
    // Get-Disk answers for any disk the storage stack can see, so no size
    // there means the stack itself cannot answer. Elsewhere the size is
    // resolved separately and may legitimately not have landed yet.
    final result = flash.validateDevice(
      devicePath: _goodPath,
      sizeBytes: null,
      isRemovable: true,
      isSystemDisk: false,
      vendorId: 0x0525,
      productId: 0xA4A5,
    );
    if (Platform.isWindows) {
      expect(result.passed, isFalse);
      expect(result.errors.join(' '), contains('size'));
    } else {
      expect(result.passed, isTrue, reason: result.errors.join('; '));
    }
  });

  test('the platform system-disk path is refused even with a valid identity', () {
    final result = flash.validateDevice(
      devicePath: _systemPath,
      sizeBytes: FlashService.mdbEmmcBytes,
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
      sizeBytes: FlashService.mdbEmmcBytes,
      isRemovable: true,
      isSystemDisk: false,
      vendorId: 0x0525,
      productId: 0xA4A5,
    );
    expect(result.passed, isFalse);
    expect(result.errors, isNotEmpty);
  });

  group('the detected path and the target path must agree', () {
    // VID, PID, size and removability come from the detected object and pass
    // on their own merits while the path names a different disk.
    SafetyCheck checkPair({required String detected, required String target}) =>
        flash.validateDevice(
          devicePath: target,
          sizeBytes: FlashService.mdbEmmcBytes,
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
      // macOS resolves the path separately and may have nothing to compare.
      expect(checkPair(detected: '', target: _goodPath).passed, isTrue);
      final result = flash.validateDevice(
        devicePath: _goodPath,
        sizeBytes: FlashService.mdbEmmcBytes,
        isRemovable: true,
        isSystemDisk: false,
        vendorId: 0x0525,
        productId: 0xA4A5,
      );
      expect(result.passed, isTrue, reason: result.errors.join('; '));
    });

    test('the size window cannot catch this, whatever the real disk holds',
        () {
      // sizeBytes describes the detected object, not the disk at devicePath,
      // so it matches the eMMC exactly however large that disk is. The real
      // disk's size never reaches this function; only the path check refuses.
      final result = flash.validateDevice(
        devicePath: _otherPath,
        sizeBytes: FlashService.mdbEmmcBytes,
        isRemovable: true,
        isSystemDisk: false,
        vendorId: 0x0525,
        productId: 0xA4A5,
        detectedPath: _goodPath,
      );
      expect(result.passed, isFalse);
      expect(result.errors.join('; '), contains('does not match'));
      expect(result.errors.join('; '), isNot(contains('Unexpected device size')));
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
