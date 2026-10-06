import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:librescoot_installer/theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/l10n/app_localizations.dart';
import 'package:librescoot_installer/l10n/app_localizations_de.dart';
import 'package:librescoot_installer/models/board_state.dart';
import 'package:librescoot_installer/models/install_plan.dart';
import 'package:librescoot_installer/models/install_time_estimate.dart';
import 'package:librescoot_installer/widgets/dashboard_handoff_status.dart';
import 'package:librescoot_installer/widgets/phase_layout.dart';
import 'package:librescoot_installer/widgets/preparation_step.dart';

Widget host(Widget Function(AppLocalizations) build) => MaterialApp(
  theme: librescootTheme(),
  locale: const Locale('de'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        width: 1016,
        child: Builder(
          builder: (context) => build(AppLocalizations.of(context)!),
        ),
      ),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'Inter',
    )..addFont(rootBundle.load('assets/fonts/InterVariable.ttf'))).load();
  });
  testWidgets(
    'status, estimate and full outcome cards fit the recording window',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var successes = 0;
      final estimate = InstallTimeEstimate.forAutonomousHandoff(
        plan: InstallPlan(
          mdb: const BoardPlan(board: Board.mdb, action: BoardAction.leave),
          dbc: const BoardPlan(
            board: Board.dbc,
            action: BoardAction.cleanInstall,
          ),
        ),
        assets: const InstallEstimateAssets(
          dbcStage0ImageBytes: 150000000,
          dbcArtifactBytes: 110000000,
        ),
      );
      await tester.pumpWidget(
        host(
          (l10n) => PhaseLayout(
            title: l10n.dbcFlashInProgress,
            subtitle: l10n.handoffDisconnected,
            onBack: () {},
            backLabel: l10n.handoffCableInstructions,
            child: DashboardHandoffStatus(
              estimate: estimate,
              disconnectedAt: DateTime.now(),
              onError: () {},
              onSuccess: () => successes++,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      expect(
        tester
            .getBottomRight(
              find.text(AppLocalizationsDe().dbcFlashSuccessPrompt),
            )
            .dy,
        lessThan(743),
      );
      expect(
        tester
            .getBottomRight(find.text(AppLocalizationsDe().dbcFlashErrorPrompt))
            .dy,
        lessThan(743),
      );
      await tester.tap(find.text('ERFOLG'));
      expect(successes, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'preparation photos use a full-width row below the instructions',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        host(
          (l10n) => PhaseLayout(
            title: l10n.physicalPrepHeading,
            child: PreparationStep(
              number: 1,
              title: l10n.removeFootwellCover,
              description: l10n.removeFootwellCoverDesc,
              images: const [
                'assets/images/lsi-unu_scooter_footwell_closed.jpg',
                'assets/images/lsi-unu_scooter_footwell_open.jpg',
              ],
            ),
          ),
        ),
      );
      final images = find.byType(Image);
      expect(images, findsNWidgets(2));
      expect(tester.getSize(images.first).height, 260);
      expect(
        tester.getTopLeft(images.first).dy,
        greaterThan(
          tester
              .getBottomLeft(find.textContaining('Löse die vier Schrauben'))
              .dy,
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
