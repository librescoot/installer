@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/l10n/app_localizations.dart';
import 'package:librescoot_installer/models/board_state.dart';
import 'package:librescoot_installer/models/install_plan.dart';
import 'package:librescoot_installer/theme.dart';
import 'package:librescoot_installer/widgets/install_plan_panel.dart';
import 'package:librescoot_installer/widgets/phase_layout.dart';

import 'font_harness.dart';

void main() {
  setUpAll(loadRealFonts);

  testWidgets('plan with target versions and DBC maps toggle', (tester) async {
    tester.view.physicalSize = const Size(982, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const mdb = BoardState(
      board: Board.mdb,
      isLibrescoot: true,
      provenance: StateProvenance.live,
      version: 'v1.2.0',
      hasMender: true,
    );
    const dbc = BoardState(
      board: Board.dbc,
      isLibrescoot: true,
      provenance: StateProvenance.live,
      version: 'v1.2.0',
      hasMender: true,
    );
    const plan = InstallPlan(
      mdb: BoardPlan(board: Board.mdb, action: BoardAction.upgrade),
      dbc: BoardPlan(board: Board.dbc, action: BoardAction.cleanInstall),
      installTiles: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: librescootTheme(),
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PhaseLayout(
            title: 'Installation planen',
            subtitle: 'Wähle die gewünschte Aktion für Hauptboard und Display.',
            actions: const [PhaseAction(label: 'Weiter', primary: true)],
            child: InstallPlanPanel(
              plan: plan,
              mdbState: mdb,
              dbcState: dbc,
              targetVersion: 'v1.3.1',
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('install_plan.png'),
    );
  });
}
