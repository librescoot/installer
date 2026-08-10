import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/usb_detector.dart';

/// Regression tests for USB->disk identity resolution on macOS.
///
/// macOS 26 broke the previous approach in two independent ways: it renamed
/// system_profiler's datatype from SPUSBDataType to SPUSBHostDataType (the
/// legacy name still exits 0 but reports nothing), and the replacement
/// reporter no longer emits "BSD Name" entries at all. The detector therefore
/// resolves identity from ioreg instead. These tests pin that parser, since a
/// wrong answer here either stalls the installer forever or — worse — points
/// the flasher at somebody else's disk.
void main() {
  final detector = UsbDetector();

  test('resolves the gadget disk from real macOS 26 ioreg output', () {
    expect(detector.parseIoregDiskNumber(_macos26Sample), 8);
  });

  test('returns null in ethernet mode (no mass-storage PID, no disk)', () {
    expect(detector.parseIoregDiskNumber(_ethernetModeSample), isNull);
  });

  test('never matches a partition slice', () {
    expect(detector.parseIoregDiskNumber('''
    "idVendor" = 1317
    "idProduct" = 42149
        "BSD Name" = "disk8s1"
'''), isNull);
  });

  test('attributes the disk to the gadget, not a foreign USB drive', () {
    // The dangerous case: another USB disk enumerated first. Picking disk3
    // here would hand the flasher an unrelated drive.
    expect(detector.parseIoregDiskNumber('''
  +-o SomeOtherDrive
    "idVendor" = 1234
    "idProduct" = 5678
        "BSD Name" = "disk3"
  +-o USB download gadget
    "idVendor" = 1317
    "idProduct" = 42149
        "BSD Name" = "disk8"
'''), 8);
  });

  test('attributes correctly when the gadget enumerates first', () {
    expect(detector.parseIoregDiskNumber('''
  +-o USB download gadget
    "idVendor" = 1317
    "idProduct" = 42149
        "BSD Name" = "disk8"
  +-o SomeOtherDrive
    "idVendor" = 1234
    "idProduct" = 5678
        "BSD Name" = "disk3"
'''), 8);
  });

  test('returns null on empty or junk input', () {
    expect(detector.parseIoregDiskNumber(''), isNull);
    expect(detector.parseIoregDiskNumber('no usb devices here'), isNull);
  });
}

/// Trimmed from live `ioreg -r -c IOUSBHostDevice -l -w 0` on macOS 26.6
/// (build 25G72) with an unu MDB in U-Boot `ums 0 mmc 1` mode.
const _macos26Sample = '''
  +-o USB download gadget@01100000  <class IOUSBHostDevice, id 0x10002f8a1>
    |   "idProduct" = 42149
    |   "USB Product Name" = "USB download gadget"
    |   "idVendor" = 1317
    |   "USB Vendor Name" = "FSL"
    | +-o IOUSBHostInterface@0  <class IOUSBHostInterface, id 0x10002fb01>
    |   |   "idProduct" = 42149
    |   |   "USB Device Info" = {"bcdDevice"=545,"idProduct"=42149,"idVendor"=1317}
    |   |   "idVendor" = 1317
    |   | +-o IOUSBMassStorageDriverNub  <class IOUSBMassStorageDriverNub>
    |   |     +-o Linux UMS disk 0 Media  <class IOMedia, id 0x10002fbf0>
    |   |       |   "Content" = "FDisk_partition_scheme"
    |   |       |   "BSD Name" = "disk8"
    |   |       |   "Removable" = Yes
    |   |       +-o Linux UMS disk 0 Media 1  <class IOMedia, id 0x10002fbf5>
    |   |           |   "Content" = "Linux"
    |   |           |   "BSD Name" = "disk8s1"
''';

/// The MDB before it is switched into mass storage: RNDIS gadget (PID 0xA4A2),
/// no block device anywhere in its subtree.
const _ethernetModeSample = '''
  +-o RNDIS_Ethernet Gadget@01100000  <class IOUSBHostDevice, id 0x10002f111>
    |   "idProduct" = 42146
    |   "USB Product Name" = "RNDIS_Ethernet Gadget"
    |   "idVendor" = 1317
    | +-o IOUSBHostInterface@0  <class IOUSBHostInterface>
    |   |   "idProduct" = 42146
    |   |   "idVendor" = 1317
''';
