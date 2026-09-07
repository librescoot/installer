import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/usb_detector.dart';

UsbDevice deviceWith(SystemDiskVerdict verdict) => UsbDevice(
  id: 'USBSTOR\\DISK&VEN_LINUX&PROD_UMS_DISK_0',
  name: 'Linux UMS Disk 0',
  path: r'\\.\PHYSICALDRIVE1',
  vendorId: 0x0525,
  productId: 0xA4A5,
  mode: DeviceMode.massStorage,
  sizeBytes: 4 * 1024 * 1024 * 1024,
  systemDiskVerdict: verdict,
);

void main() {
  group('Windows mass-storage identity', () {
    test('walks PnP parents instead of trusting generic Linux UMS names', () {
      final source = File('lib/services/usb_detector.dart').readAsStringSync();
      expect(source, contains('DEVPKEY_Device_Parent'));
      expect(source, contains("^USB\\\\VID_0525&PID_A4A5"));
      expect(source, isNot(contains('PNPDeviceID -like "*VID_0525*"')));
    });
  });

  group('UsbDevice.isSystemDisk', () {
    test('blocks only on a confirmed system disk', () {
      expect(deviceWith(SystemDiskVerdict.systemDisk).isSystemDisk, isTrue);
      expect(deviceWith(SystemDiskVerdict.notSystem).isSystemDisk, isFalse);
    });

    test('does not block when the probe could not answer', () {
      // An unknown verdict goes to the confirmation dialog. Treating it as a
      // system disk here is what blocked the installer outright on machines
      // where the probe cannot run.
      expect(deviceWith(SystemDiskVerdict.unknown).isSystemDisk, isFalse);
    });

    test('a device nobody probed carries no verdict', () {
      // Omitting the argument must not manufacture a positive safety answer.
      final device = UsbDevice(
        id: 'x',
        name: 'x',
        path: 'x',
        vendorId: 0x0525,
        productId: 0xA4A5,
        mode: DeviceMode.massStorage,
      );
      expect(device.systemDiskVerdict, SystemDiskVerdict.unknown);
      expect(device.isSystemDisk, isFalse);
    });
  });
}
