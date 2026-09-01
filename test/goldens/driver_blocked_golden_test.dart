@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/l10n/app_localizations.dart';
import 'package:librescoot_installer/services/driver_service.dart';
import 'package:librescoot_installer/theme.dart';
import 'package:librescoot_installer/widgets/driver_blocked_panel.dart';
import 'package:librescoot_installer/widgets/phase_layout.dart';

import 'font_harness.dart';

/// Real capture: in-box usbser.inf force-installed onto a live MDB, then read
/// back through the shipping parsers.
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
  setUpAll(loadRealFonts);

  for (final locale in const [Locale('de'), Locale('en')]) {
    testWidgets('the driver-blocked screen in ${locale.languageCode}',
        (tester) async {
      tester.view.physicalSize = const Size(982, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final diagnosis = _hijacked();
      final details = DriverService.describeForSupport(diagnosis);

      await tester.pumpWidget(MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: librescootTheme(),
        home: Builder(builder: (context) {
          final l10n = AppLocalizations.of(context)!;
          return Scaffold(
            body: DriverBlockedPanel(
              title: l10n.driverClaimedHeading,
              body: l10n.driverClaimedBody(
                DriverService.describeHolder(diagnosis),
              ),
              detailsLabel: l10n.driverClaimedDetailsLabel,
              details: details,
              actions: [
                PhaseAction(
                  label: l10n.driverRecheck,
                  icon: Icons.refresh,
                  primary: true,
                  onPressed: () {},
                ),
                PhaseAction(
                  label: l10n.copyToClipboard,
                  icon: Icons.copy,
                  onPressed: () {},
                ),
              ],
            ),
          );
        }),
      ));
      await tester.pump(const Duration(milliseconds: 400));

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('driver_blocked_${locale.languageCode}.png'),
      );
    });
  }
}
