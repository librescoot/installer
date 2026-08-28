import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/flash_service.dart';
import 'package:librescoot_installer/services/usb_detector.dart';

void main() {
  late Directory tmp;
  late UsbDetector detector;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('mounts');
    detector = UsbDetector();
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  String mounts(String body) {
    final f = File('${tmp.path}/mounts')..writeAsStringSync(body);
    return f.path;
  }

  group('linuxSystemDiskVerdict', () {
    test('a disk with the root filesystem on it is the system disk', () async {
      final m = mounts('/dev/sda2 / ext4 rw 0 0\n'
          '/dev/sda1 /boot vfat rw 0 0\n');
      expect(await detector.linuxSystemDiskVerdict('/dev/sda', mountsPath: m),
          SystemDiskVerdict.systemDisk);
    });

    test('an NVMe-booted laptop leaves sda free for the scooter', () async {
      // The case that used to be refused outright: root is on NVMe, so sda is
      // simply the first USB disk attached, which is what the scooter is.
      final m = mounts('/dev/nvme0n1p2 / ext4 rw 0 0\n'
          '/dev/nvme0n1p1 /boot/efi vfat rw 0 0\n');
      expect(await detector.linuxSystemDiskVerdict('/dev/sda', mountsPath: m),
          SystemDiskVerdict.notSystem);
    });

    test('the scooter auto-mounted by the desktop is still flashable', () async {
      // The whole point: udisks2 mounts the scooter's boot partition seconds
      // after it enters mass storage. Treating any mount as disqualifying
      // refuses the exact device the user is trying to flash.
      final m = mounts('/dev/nvme0n1p2 / ext4 rw 0 0\n'
          '/dev/sda1 /media/teal/BOOT vfat rw 0 0\n'
          '/dev/sda2 /run/media/teal/rootfs ext4 rw 0 0\n');
      expect(await detector.linuxSystemDiskVerdict('/dev/sda', mountsPath: m),
          SystemDiskVerdict.notSystem);
    });

    test('a mount point with a space in it is still read as removable',
        () async {
      // /proc/mounts octal-escapes them.
      final m = mounts('/dev/sda1 /media/teal/MY\\040DISK vfat rw 0 0\n');
      expect(await detector.linuxSystemDiskVerdict('/dev/sda', mountsPath: m),
          SystemDiskVerdict.notSystem);
    });

    test('a system path outside the media roots still disqualifies', () async {
      final m = mounts('/dev/nvme0n1p2 / ext4 rw 0 0\n'
          '/dev/sda1 /home ext4 rw 0 0\n');
      expect(await detector.linuxSystemDiskVerdict('/dev/sda', mountsPath: m),
          SystemDiskVerdict.systemDisk);
    });

    test('a neighbouring disk name is not confused for this one', () async {
      // sdb and sdaa must not match sda.
      final m = mounts('/dev/sdb1 / ext4 rw 0 0\n'
          '/dev/sdaa1 /data ext4 rw 0 0\n');
      expect(await detector.linuxSystemDiskVerdict('/dev/sda', mountsPath: m),
          SystemDiskVerdict.notSystem);
    });

    test('nvme partition suffixes are matched', () async {
      final m = mounts('/dev/nvme0n1p2 / ext4 rw 0 0\n');
      expect(
          await detector.linuxSystemDiskVerdict('/dev/nvme0n1', mountsPath: m),
          SystemDiskVerdict.systemDisk);
    });

    test('an unreadable mounts file answers unknown, never notSystem', () async {
      expect(
          await detector.linuxSystemDiskVerdict('/dev/sda',
              mountsPath: '${tmp.path}/does-not-exist'),
          SystemDiskVerdict.unknown);
    });
  });

  group('validateDevice and /dev/sda', () {
    // validateDevice branches on the host platform, and the /dev/sda rules sit
    // in the Linux arm. On another host that arm never runs, so the two tests
    // keyed to it assert on code that did not execute.
    final String? linuxOnly = Platform.isLinux
        ? null
        : 'validateDevice branches per platform, so the /dev/sda rules only '
            'run on Linux';

    SafetyCheck check(String path, SystemDiskVerdict verdict) =>
        FlashService().validateDevice(
          devicePath: path,
          sizeBytes: FlashService.mdbEmmcBytes,
          isRemovable: true,
          isSystemDisk: false,
          vendorId: 0x0525,
          productId: 0xA4A5,
          systemDiskVerdict: verdict,
        );

    test('sda passes once nothing is mounted on it', () {
      expect(check('/dev/sda', SystemDiskVerdict.notSystem).passed, isTrue);
    }, skip: linuxOnly);

    test('sda is refused when the answer is unknown', () {
      // Without evidence the name is all there is, and sda is commonly root.
      expect(check('/dev/sda', SystemDiskVerdict.unknown).passed, isFalse);
    }, skip: linuxOnly);

    test('a disk carrying a filesystem is refused whatever its name', () {
      final result = FlashService().validateDevice(
        devicePath: '/dev/sdc',
        sizeBytes: FlashService.mdbEmmcBytes,
        isRemovable: true,
        isSystemDisk: true,
        vendorId: 0x0525,
        productId: 0xA4A5,
        systemDiskVerdict: SystemDiskVerdict.systemDisk,
      );
      expect(result.passed, isFalse);
    });

    test('the identity check still stands on its own', () {
      final result = FlashService().validateDevice(
        devicePath: '/dev/sda',
        sizeBytes: FlashService.mdbEmmcBytes,
        isRemovable: true,
        isSystemDisk: false,
        vendorId: 0x1234,
        productId: 0xA4A5,
        systemDiskVerdict: SystemDiskVerdict.notSystem,
      );
      expect(result.passed, isFalse);
    });
  });
}
