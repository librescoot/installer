import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/widgets/connect_failure_panel.dart';
import 'package:librescoot_installer/widgets/driver_blocked_panel.dart';
import 'package:librescoot_installer/widgets/phase_layout.dart';

void main() {
  // The phase host gives a PhaseLayout the height and wraps everything else
  // in a scroll view. These two return a PhaseLayout from build, which the
  // host cannot see by type, so without the marker their Expanded body met
  // unbounded height and every connect failure screen threw instead of
  // rendering.
  test('panels that build a PhaseLayout say so', () {
    final connect = ConnectFailurePanel(
      title: 't',
      body: 'b',
      checklistTitle: 'c',
      detailsLabel: 'd',
      details: '',
      copyLabel: 'copy',
      actions: const [],
    );
    final driver = DriverBlockedPanel(
      title: 't',
      body: 'b',
      detailsLabel: 'd',
      details: '',
      actions: const [],
    );
    expect(connect, isA<OwnsPhaseLayout>());
    expect(driver, isA<OwnsPhaseLayout>());
  });

  testWidgets('a panel renders when given the height', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ConnectFailurePanel(
          title: 't',
          body: 'line\n\n• one\n• two',
          checklistTitle: 'c',
          detailsLabel: 'd',
          details: '',
          copyLabel: 'copy',
          actions: const [],
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
  });
}
