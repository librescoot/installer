import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/network_service.dart';

/// A sysfs tree shaped like the real one: the netdev's `device` is a symlink
/// to the USB *interface*, and idVendor/idProduct live on the USB *device* one
/// level up, so reading them means traversing `..` through that symlink.
class FakeSys {
  FakeSys(this.root);
  final Directory root;
  var _bus = 0;

  void addInterface(
    String name, {
    String? uevent,
    String? idVendor,
    String? idProduct,
    String driver = 'cdc_ether',
  }) {
    final usbDevice = Directory('${root.path}/devices/usb1/1-1.${_bus++}')
      ..createSync(recursive: true);
    final usbInterface = Directory('${usbDevice.path}/1-1:1.0')
      ..createSync(recursive: true);
    if (uevent != null) {
      File('${usbInterface.path}/uevent').writeAsStringSync(uevent);
    }
    if (idVendor != null) {
      File('${usbDevice.path}/idVendor').writeAsStringSync('$idVendor\n');
    }
    if (idProduct != null) {
      File('${usbDevice.path}/idProduct').writeAsStringSync('$idProduct\n');
    }
    final driverDir = Directory('${root.path}/bus/usb/drivers/$driver')
      ..createSync(recursive: true);

    final netDir = Directory('${root.path}/class/net/$name')
      ..createSync(recursive: true);
    Link('${netDir.path}/device').createSync(usbInterface.path);
    Link('${netDir.path}/driver').createSync(driverDir.path);
  }
}

/// The gadget's own uevent, copied off a board that had the MDB enumerated.
const gadgetUevent = '''
DEVTYPE=usb_interface
DRIVER=cdc_ether
PRODUCT=525/a4a2/612
TYPE=2/0/0
INTERFACE=2/6/0
MODALIAS=usb:v0525pA4A2d0612dc02dsc00dp00ic02isc06ip00in00
''';

/// A USB-C dock's gigabit adapter. Same driver, different silicon.
const dockUevent = '''
DEVTYPE=usb_interface
DRIVER=cdc_ether
PRODUCT=b95/1790/100
TYPE=2/0/0
INTERFACE=2/6/0
MODALIAS=usb:v0B95p1790d0100dc00dsc00dp00ic02isc06ip00in00
''';

/// A phone sharing its connection over USB.
const tetherUevent = '''
DEVTYPE=usb_interface
DRIVER=rndis_host
PRODUCT=18d1/4ee4/510
TYPE=2/0/0
MODALIAS=usb:v18D1p4EE4d0510dc00dsc00dp00ic02isc06ip00in00
''';

void main() {
  late Directory temp;
  late FakeSys sys;
  final service = NetworkService();

  setUp(() {
    temp = Directory.systemTemp.createTempSync('sysfs-');
    sys = FakeSys(temp);
  });

  tearDown(() => temp.deleteSync(recursive: true));

  group('uevent parsing', () {
    test('MODALIAS pads the ids to four digits', () {
      expect(NetworkService.ueventIdentifiesGadget(gadgetUevent), isTrue);
    });

    test('PRODUCT drops leading zeros and is still ours', () {
      expect(
        NetworkService.ueventIdentifiesGadget('PRODUCT=525/a4a2/612\n'),
        isTrue,
      );
    });

    test('another vendor is not ours on either line', () {
      expect(NetworkService.ueventIdentifiesGadget(dockUevent), isFalse);
      expect(NetworkService.ueventIdentifiesGadget(tetherUevent), isFalse);
    });

    test('a product id that merely starts with ours is not ours', () {
      expect(
        NetworkService.ueventIdentifiesGadget('PRODUCT=525/a4a20/612\n'),
        isFalse,
      );
    });
  });

  group('sysfs ids', () {
    test('hex ids are parsed as hex, not compared as text', () {
      expect(NetworkService.usbIdsIdentifyGadget('0525', 'a4a2'), isTrue);
      expect(NetworkService.usbIdsIdentifyGadget('0525\n', 'A4A2\n'), isTrue);
      expect(NetworkService.usbIdsIdentifyGadget('525', 'a4a2'), isTrue);
      expect(NetworkService.usbIdsIdentifyGadget('0b95', '1790'), isFalse);
    });
  });

  group('interface selection', () {
    test('the gadget is found by its uevent', () async {
      sys.addInterface('usb0', uevent: gadgetUevent);
      expect(
        await service.isLibrescootInterface('usb0', sysRoot: temp.path),
        isTrue,
      );
    });

    test('the gadget is found by idVendor/idProduct alone', () async {
      sys.addInterface('usb0', idVendor: '0525', idProduct: 'a4a2');
      expect(
        await service.isLibrescootInterface('usb0', sysRoot: temp.path),
        isTrue,
      );
    });

    test('a generic cdc_ether adapter is not the gadget', () async {
      sys.addInterface(
        'enp0s20u1',
        uevent: dockUevent,
        idVendor: '0b95',
        idProduct: '1790',
      );
      expect(
        await service.isLibrescootInterface('enp0s20u1', sysRoot: temp.path),
        isFalse,
      );
    });

    test('an rndis_host tether is not the gadget', () async {
      sys.addInterface(
        'enp0s20u2',
        uevent: tetherUevent,
        idVendor: '18d1',
        idProduct: '4ee4',
        driver: 'rndis_host',
      );
      expect(
        await service.isLibrescootInterface('enp0s20u2', sysRoot: temp.path),
        isFalse,
      );
    });

    test('an interface with no identity at all is refused', () async {
      // Driver still binds, so the old fallback would have claimed this one.
      sys.addInterface('enp0s20u3', driver: 'cdc_ncm');
      expect(
        await service.isLibrescootInterface('enp0s20u3', sysRoot: temp.path),
        isFalse,
      );
    });

    test('the gadget wins a host full of generic adapters', () async {
      // Named so that plain readdir order would very likely hand back a
      // decoy first; the finder sorts, and only identity decides.
      sys.addInterface('eth0', uevent: dockUevent);
      sys.addInterface('enp0s20u1', uevent: tetherUevent, driver: 'rndis_host');
      sys.addInterface('enp0s20u2', driver: 'cdc_subset');
      sys.addInterface('usb0', uevent: gadgetUevent);

      final found = await service.findLinuxInterfaceOnce(sysRoot: temp.path);
      expect(found?.name, 'usb0');
    });

    test('a host with only generic adapters finds nothing', () async {
      sys.addInterface('eth0', uevent: dockUevent);
      sys.addInterface('enp0s20u1', driver: 'cdc_ncm');

      expect(await service.findLinuxInterfaceOnce(sysRoot: temp.path), isNull);
    });
  });
}
