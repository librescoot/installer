import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/driver_service.dart';

/// Captured verbatim from `pnputil /enum-devices /deviceid "USB\VID_0525&PID_A4A2"
/// /drivers /format xml` on Windows 11 26100 against a real MDB.
///
/// The text output of the same command is built from pnputil.exe.mui and is
/// localized, so a German machine prints "Bestplatziert"/"Ausrangiert" there.
/// The XML Status tokens are compiled into pnputil.exe itself, and Rank is a
/// hex integer, so both survive any UI language.
const _healthy = r'''
<?xml version="1.0" encoding="utf-8"?>
<PnpUtil Version="10.0.26220" Command="/enum-devices /deviceid USB\VID_0525&amp;PID_A4A2 /drivers /format xml">
    <Device InstanceId="USB\VID_0525&amp;PID_A4A2\6&amp;3365fbaf&amp;0&amp;8">
        <DeviceDescription>USB Ethernet/RNDIS Gadget #3</DeviceDescription>
        <ClassName>Net</ClassName>
        <ClassGuid>{4d36e972-e325-11ce-bfc1-08002be10318}</ClassGuid>
        <ManufacturerName>Acer Incorporated.</ManufacturerName>
        <Status>Started</Status>
        <DriverName>oem76.inf</DriverName>
        <MatchingDrivers>
            <DriverName DriverName="oem76.inf">
                <OriginalName>rndis.inf</OriginalName>
                <ProviderName>Acer Incorporated.</ProviderName>
                <ClassName>Net</ClassName>
                <ClassGuid>{4d36e972-e325-11ce-bfc1-08002be10318}</ClassGuid>
                <DriverVersion>01/13/2010 1.0.0.0</DriverVersion>
                <SignerName>Microsoft Windows Hardware Compatibility Publisher</SignerName>
                <MatchingDeviceId>USB\VID_0525&amp;PID_A4A2</MatchingDeviceId>
                <Rank>00FF0001</Rank>
                <Status>BestRanked/Installed</Status>
            </DriverName>
            <DriverName DriverName="usbser.inf">
                <ProviderName>Microsoft</ProviderName>
                <ClassName>Ports</ClassName>
                <ClassGuid>{4d36e978-e325-11ce-bfc1-08002be10318}</ClassGuid>
                <DriverVersion>06/21/2006 10.0.26100.8925</DriverVersion>
                <SignerName>Microsoft Windows</SignerName>
                <MatchingDeviceId>USB\Class_02&amp;SubClass_02</MatchingDeviceId>
                <Rank>00FF2004</Rank>
                <Status>Outranked</Status>
            </DriverName>
        </MatchingDrivers>
    </Device>
</PnpUtil>
''';

/// Same device seconds later, after in-box usbser.inf was force-installed onto
/// it with UpdateDriverForPlugAndPlayDevices/INSTALLFLAG_FORCE. This is what a
/// third-party installer doing the same thing leaves behind.
const _hijacked = r'''
<?xml version="1.0" encoding="utf-8"?>
<PnpUtil Version="10.0.26220" Command="/enum-devices /deviceid USB\VID_0525&amp;PID_A4A2 /drivers /format xml">
    <Device InstanceId="USB\VID_0525&amp;PID_A4A2\6&amp;3365fbaf&amp;0&amp;8">
        <DeviceDescription>USB Serial Device (COM6)</DeviceDescription>
        <ClassName>Ports</ClassName>
        <ClassGuid>{4d36e978-e325-11ce-bfc1-08002be10318}</ClassGuid>
        <ManufacturerName>Microsoft</ManufacturerName>
        <Status>Started</Status>
        <DriverName>usbser.inf</DriverName>
        <MatchingDrivers>
            <DriverName DriverName="oem76.inf">
                <OriginalName>rndis.inf</OriginalName>
                <ProviderName>Acer Incorporated.</ProviderName>
                <ClassName>Net</ClassName>
                <ClassGuid>{4d36e972-e325-11ce-bfc1-08002be10318}</ClassGuid>
                <DriverVersion>01/13/2010 1.0.0.0</DriverVersion>
                <SignerName>Microsoft Windows Hardware Compatibility Publisher</SignerName>
                <MatchingDeviceId>USB\VID_0525&amp;PID_A4A2</MatchingDeviceId>
                <Rank>00FF0001</Rank>
                <Status>BestRanked</Status>
            </DriverName>
            <DriverName DriverName="usbser.inf">
                <ProviderName>Microsoft</ProviderName>
                <ClassName>Ports</ClassName>
                <ClassGuid>{4d36e978-e325-11ce-bfc1-08002be10318}</ClassGuid>
                <DriverVersion>06/21/2006 10.0.26100.8925</DriverVersion>
                <SignerName>Microsoft Windows</SignerName>
                <MatchingDeviceId>USB\Class_02&amp;SubClass_02</MatchingDeviceId>
                <Rank>00FF2004</Rank>
                <Status>Outranked/Installed</Status>
            </DriverName>
        </MatchingDrivers>
    </Device>
</PnpUtil>
''';

void main() {
  group('parseEnumDevicesXml', () {
    test('a healthy device is bound to its best-ranked driver', () {
      final report = DriverService.parseEnumDevicesXml(_healthy)!;

      expect(report.instanceId, r'USB\VID_0525&PID_A4A2\6&3365fbaf&0&8');
      expect(report.className, 'Net');
      expect(report.boundInf, 'oem76.inf');
      expect(report.candidates, hasLength(2));
      expect(report.isHijacked, isFalse);
      expect(report.incumbent!.infName, 'oem76.inf');
      expect(report.bestRanked!.infName, 'oem76.inf');
    });

    test('a hijacked device is bound to an outranked driver', () {
      final report = DriverService.parseEnumDevicesXml(_hijacked)!;

      expect(report.className, 'Ports');
      expect(report.boundInf, 'usbser.inf');
      expect(report.isHijacked, isTrue);
      // The whole detector, with no localized string anywhere in it.
      expect(report.incumbent!.rank, greaterThan(report.bestRanked!.rank));
    });

    test('the hijacker is identified well enough to tell the user', () {
      final report = DriverService.parseEnumDevicesXml(_hijacked)!;
      final thief = report.incumbent!;

      expect(thief.infName, 'usbser.inf');
      expect(thief.provider, 'Microsoft');
      expect(thief.className, 'Ports');
      expect(thief.driverVersion, '06/21/2006 10.0.26100.8925');
      expect(thief.signer, 'Microsoft Windows');
      expect(thief.matchingDeviceId, r'USB\Class_02&SubClass_02');
    });

    test('rank decodes into its match kind and index', () {
      final report = DriverService.parseEnumDevicesXml(_healthy)!;
      final ours = report.bestRanked!;
      final usbser = report.candidates.firstWhere(
        (c) => c.infName == 'usbser.inf',
      );

      // 0x00FF0001: hardware-ID match at index 1 of the device's hwid list.
      expect(ours.rank, 0x00FF0001);
      expect(ours.isCompatMatch, isFalse);
      expect(ours.matchIndex, 1);

      // 0x00FF2004: the 0x2000 bit marks a compatible-ID match, index 4.
      expect(usbser.rank, 0x00FF2004);
      expect(usbser.isCompatMatch, isTrue);
      expect(usbser.matchIndex, 4);
    });

    test('a compatible-ID match never outranks a hardware-ID match', () {
      // usbser's DriverVer is fifteen years newer than ours and it still loses,
      // because DriverVer only breaks ties within one rank. This is why a
      // stale DriverVer on our INF is survivable without signing a new one.
      final report = DriverService.parseEnumDevicesXml(_healthy)!;
      final ours = report.bestRanked!;
      final usbser = report.candidates.firstWhere(
        (c) => c.infName == 'usbser.inf',
      );

      expect(ours.isCompatMatch, isFalse);
      expect(usbser.isCompatMatch, isTrue);
      expect(ours.rank, lessThan(usbser.rank));
    });

    test('detection survives a non-English Windows', () {
      // Same bytes with the Status tokens replaced by plausible localized text.
      // Rank is a hex integer and the bound driver comes from the device-level
      // DriverName element, so neither reading depends on the UI language.
      final german = _hijacked
          .replaceAll('BestRanked', 'Bestplatziert')
          .replaceAll('Outranked/Installed', 'Ausrangiert/Installiert');

      final report = DriverService.parseEnumDevicesXml(german)!;
      expect(report.boundInf, 'usbser.inf');
      expect(report.isHijacked, isTrue);
    });

    test('XML entities are decoded in ids', () {
      final report = DriverService.parseEnumDevicesXml(_healthy)!;
      expect(report.instanceId, contains('&'));
      expect(report.instanceId, isNot(contains('&amp;')));
    });

    test('unparseable output yields null rather than a wrong answer', () {
      expect(DriverService.parseEnumDevicesXml(''), isNull);
      expect(DriverService.parseEnumDevicesXml('not xml at all'), isNull);
      expect(
        DriverService.parseEnumDevicesXml(
          '<?xml version="1.0"?><PnpUtil Version="10.0"></PnpUtil>',
        ),
        isNull,
      );
    });

    test('a device with no matching drivers still reports its binding', () {
      final bare = r'''
<?xml version="1.0" encoding="utf-8"?>
<PnpUtil Version="10.0.26220">
    <Device InstanceId="USB\VID_0525&amp;PID_A4A2\6&amp;3365fbaf&amp;0&amp;8">
        <DeviceDescription>USB Ethernet/RNDIS Gadget</DeviceDescription>
        <ClassName>USBDevice</ClassName>
        <Status>Started</Status>
    </Device>
</PnpUtil>
''';
      final report = DriverService.parseEnumDevicesXml(bare)!;
      expect(report.className, 'USBDevice');
      expect(report.boundInf, isNull);
      expect(report.candidates, isEmpty);
      // Nothing to compare against, so no hijack claim either way.
      expect(report.isHijacked, isFalse);
    });
  });
}
