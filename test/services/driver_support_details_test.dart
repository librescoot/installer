import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/driver_service.dart';

const _hijackedXml = r'''
<?xml version="1.0" encoding="utf-8"?>
<PnpUtil Version="10.0.26220">
    <Device InstanceId="USB\VID_0525&amp;PID_A4A2\6&amp;3365fbaf&amp;0&amp;8">
        <DeviceDescription>USB Serial Device (COM6)</DeviceDescription>
        <ClassName>Ports</ClassName>
        <Status>Started</Status>
        <DriverName>usbser.inf</DriverName>
        <MatchingDrivers>
            <DriverName DriverName="oem76.inf">
                <ProviderName>Acer Incorporated.</ProviderName>
                <DriverVersion>01/13/2010 1.0.0.0</DriverVersion>
                <MatchingDeviceId>USB\VID_0525&amp;PID_A4A2</MatchingDeviceId>
                <Rank>00FF0001</Rank>
                <Status>BestRanked</Status>
            </DriverName>
            <DriverName DriverName="usbser.inf">
                <ProviderName>Microsoft</ProviderName>
                <DriverVersion>06/21/2006 10.0.26100.8925</DriverVersion>
                <MatchingDeviceId>USB\Class_02&amp;SubClass_02</MatchingDeviceId>
                <Rank>00FF2004</Rank>
                <Status>Outranked/Installed</Status>
            </DriverName>
        </MatchingDrivers>
    </Device>
</PnpUtil>
''';

DriverDiagnosis _hijacked() => DriverService.parseBindingProbe(
      0,
      'PRESENT\tUSB\\VID_0525&PID_A4A2\\6&3365FBAF&0&8\tPorts\tusbser\t0\t'
          'usbser.inf\n',
    ).withReport(DriverService.parseEnumDevicesXml(_hijackedXml));

void main() {
  group('describeHolder', () {
    test('names the program a person would go looking for', () {
      expect(
        DriverService.describeHolder(_hijacked()),
        'Microsoft (usbser.inf)',
      );
    });

    test('falls back to the bound INF when there is no ranking', () {
      final d = DriverService.parseBindingProbe(
        0,
        'PRESENT\tid\tPorts\tusbser\t0\tsomevendor.inf\n',
      );
      expect(DriverService.describeHolder(d), 'somevendor.inf');
    });
  });

  group('describeForSupport', () {
    test('carries what took the port and what should have won', () {
      final text = DriverService.describeForSupport(_hijacked());

      expect(text, contains('State:   wrongDriver'));
      expect(text, contains('Class:   ports'));
      expect(text, contains('Bound:   usbser.inf (Microsoft)'));
      expect(text, contains('rank 0x00FF2004'));
      expect(text, contains('Best:    oem76.inf (Acer Incorporated.)'));
      expect(text, contains('rank 0x00FF0001'));
      // The reader can reproduce the finding themselves, without admin.
      expect(
        text,
        contains(
          r'pnputil /enum-devices /deviceid "USB\VID_0525&PID_A4A2" /drivers',
        ),
      );
    });

    test('reports a problem code when the driver will not start', () {
      final d = DriverService.parseBindingProbe(
        0,
        'PRESENT\tid\tNet\tUSB_RNDIS\t39\toem76.inf\n',
      );
      final text = DriverService.describeForSupport(d);
      expect(text, contains('deviceError'));
      expect(text, contains('problem code 39'));
    });

    test('says something useful even with no ranking available', () {
      final d = DriverService.parseBindingProbe(0, 'ABSENT\n');
      final text = DriverService.describeForSupport(d);
      expect(text, contains('notPresent'));
      expect(text, contains(r'USB\VID_0525&PID_A4A2'));
    });
  });
}
