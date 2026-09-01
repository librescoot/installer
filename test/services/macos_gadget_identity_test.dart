import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/usb_detector.dart';

/// Correlating the MDB's USB identity to the interface macOS gave it, so the
/// installer stops handing 192.168.7.50 to whatever `en` happened to be up
/// without an address. This is the macOS twin of the Linux sysfs check.
///
/// PROVENANCE. Measured, not invented. Captured on macOS 15.7.7 with a real
/// board attached in ethernet gadget mode, indentation preserved.
///
/// The chain is four levels below the USB device and the leaf is NOT an
/// IOEthernetInterface, which is worth knowing before anyone "tidies" this
/// walk:
///
///   IOUSBHostDevice
///     > AppleUSBCDCCompositeDevice   (!registered, !matched)
///       > AppleUserECM
///         > IOSkywalkLegacyEthernet  (!registered, !matched)
///           > en12                   (IOSkywalkLegacyEthernetInterface)
///
/// Two of the four intermediate nodes are unmatched, so a walk that skipped
/// unmatched nodes, or stopped at one as a dead branch, would never reach the
/// interface. And the leaf class is IOSkywalkLegacyEthernetInterface, so a walk
/// that matched on the class name rather than on the "BSD Name" key would fail
/// here while passing every fixture written from expectation.
///
/// Skywalk is the newer networking stack, so this depth and these names are
/// release-dependent. That is why the walk tracks indent and nothing else.
const _ethernetWithInterface = '''
  +-o RNDIS/Ethernet Gadget@00100000  <class IOUSBHostDevice, registered, matched>
    |   "idProduct" = 42146
    |   "idVendor" = 1317
    +-o AppleUSBCDCCompositeDevice  <class AppleUSBCDCCompositeDevice, !registered, !matched>
    | |   "idVendor" = 1317
    | +-o AppleUserECM  <class IOUserNetworkEthernet, registered, matched>
    |   +-o IOSkywalkLegacyEthernet  <class IOSkywalkLegacyEthernet, !registered, !matched>
    |   | +-o en12  <class IOSkywalkLegacyEthernetInterface, registered, matched>
    |   |   |   "BSD Name" = "en12"
''';

/// A dock's gigabit adapter enumerated alongside the MDB. Different vendor,
/// same generic stack, its own interface. This is the case the old rule got
/// wrong: en5 is up with no address of its own and looked just as good.
const _gadgetBesideADock = '''
  +-o USB 10/100/1000 LAN@01200000  <class IOUSBHostDevice, id 0x10002a001>
    |   "idProduct" = 6032
    |   "idVendor" = 2965
    | +-o IOUSBHostInterface@0  <class IOUSBHostInterface>
    |   | +-o AppleUSBECMData  <class IOService>
    |   |     +-o en5  <class IOEthernetInterface, id 0x10002a110>
    |   |       |   "BSD Name" = "en5"
  +-o RNDIS_Ethernet Gadget@01100000  <class IOUSBHostDevice, id 0x10002f111>
    |   "idProduct" = 42146
    |   "idVendor" = 1317
    +-o AppleUSBCDCCompositeDevice  <class AppleUSBCDCCompositeDevice, !registered, !matched>
    | +-o AppleUserECM  <class IOUserNetworkEthernet, registered, matched>
    |   +-o IOSkywalkLegacyEthernet  <class IOSkywalkLegacyEthernet, !registered, !matched>
    |   | +-o en12  <class IOSkywalkLegacyEthernetInterface, registered, matched>
    |   |   |   "BSD Name" = "en12"
''';

/// The MDB in mass storage, from usb_detector_ioreg_test.dart. No interface
/// anywhere in its subtree.
const _massStorageOnly = '''
  +-o USB download gadget@01100000  <class IOUSBHostDevice, id 0x10002f8a1>
    |   "idProduct" = 42149
    |   "idVendor" = 1317
    | +-o IOUSBHostInterface@0  <class IOUSBHostInterface, id 0x10002fb01>
    |   | +-o IOUSBMassStorageDriverNub  <class IOUSBMassStorageDriverNub>
    |   |     +-o Linux UMS disk 0 Media  <class IOMedia, id 0x10002fbf0>
    |   |       |   "BSD Name" = "disk8"
''';

void main() {
  test('the gadget interface is found under its own device', () {
    expect(
      UsbDetector.parseIoregEthernetInterface(_ethernetWithInterface),
      'en12',
    );
  });

  test('a dock adapter beside it is not mistaken for the gadget', () {
    expect(UsbDetector.parseIoregEthernetInterface(_gadgetBesideADock), 'en12');
  });

  test('a dock adapter on its own yields nothing', () {
    final dockOnly = _gadgetBesideADock.split('  +-o RNDIS').first;
    expect(UsbDetector.parseIoregEthernetInterface(dockOnly), isNull);
  });

  test('mass storage publishes no interface', () {
    // Wrong product id, and nothing en-shaped in the tree either.
    expect(UsbDetector.parseIoregEthernetInterface(_massStorageOnly), isNull);
  });

  test('the disk lookup is unmoved by the shared walk', () {
    expect(UsbDetector().parseIoregDiskNumber(_massStorageOnly), 8);
    expect(UsbDetector().parseIoregDiskNumber(_ethernetWithInterface), isNull);
  });

  test('an interface outside any matching subtree is not claimed', () {
    // A device that publishes no descriptors of its own must not inherit the
    // gadget's identity from the node before it.
    const orphan = '''
  +-o RNDIS_Ethernet Gadget@01100000  <class IOUSBHostDevice, id 0x10002f111>
    |   "idProduct" = 42146
    |   "idVendor" = 1317
  +-o Some Other Device@01300000  <class IOUSBHostDevice, id 0x10002b001>
    | +-o IOUSBHostInterface@0  <class IOUSBHostInterface>
    |   | +-o AppleUSBECMData  <class IOService>
    |   |     +-o en9  <class IOEthernetInterface, id 0x10002b110>
    |   |       |   "BSD Name" = "en9"
''';
    expect(UsbDetector.parseIoregEthernetInterface(orphan), isNull);
  });

  test('hex ids are read as well as decimal', () {
    const hexForm = '''
  +-o RNDIS_Ethernet Gadget@01100000  <class IOUSBHostDevice, id 0x10002f111>
    |   "idProduct" = 0xa4a2
    |   "idVendor" = 0x525
    | +-o IOUSBHostInterface@0  <class IOUSBHostInterface>
    |   |     +-o en12  <class IOEthernetInterface, id 0x10002fc10>
    |   |       |   "BSD Name" = "en12"
''';
    expect(UsbDetector.parseIoregEthernetInterface(hexForm), 'en12');
  });

  test('unmatched intermediate nodes do not stop the walk', () {
    // Two of the four real intermediate nodes are !registered, !matched. A
    // walk that treated an unmatched node as a dead branch would never reach
    // the interface, and would do so only on hardware.
    expect(_ethernetWithInterface, contains('!registered, !matched'));
    expect(
      UsbDetector.parseIoregEthernetInterface(_ethernetWithInterface),
      'en12',
    );
  });

  test('the leaf is found by its key, not by its class name', () {
    // The real leaf is an IOSkywalkLegacyEthernetInterface, not an
    // IOEthernetInterface. Matching on the class would pass any fixture
    // written from expectation and fail on a real Mac.
    expect(
      _ethernetWithInterface,
      isNot(contains('<class IOEthernetInterface')),
    );
    expect(
      UsbDetector.parseIoregEthernetInterface(_ethernetWithInterface),
      'en12',
    );
  });

  test('empty and unrelated output yield nothing', () {
    expect(UsbDetector.parseIoregEthernetInterface(''), isNull);
    expect(
      UsbDetector.parseIoregEthernetInterface('no usb devices here'),
      isNull,
    );
  });
}
