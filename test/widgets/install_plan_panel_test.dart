import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/l10n/app_localizations.dart';
import 'package:librescoot_installer/models/board_state.dart';
import 'package:librescoot_installer/models/install_plan.dart';
import 'package:librescoot_installer/widgets/install_plan_panel.dart';

Widget _host(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(body: child),
    );

const _mdbState = BoardState(
  board: Board.mdb,
  isLibrescoot: true,
  provenance: StateProvenance.live,
  version: 'v1.2.0',
  hasMender: true,
);
const _stockDbc = BoardState(
  board: Board.dbc,
  isLibrescoot: false,
  provenance: StateProvenance.unknown,
);

void main() {
  testWidgets('shows both boards with their current versions', (tester) async {
    final plan = InstallPlan.defaults(
        mdb: _mdbState, dbc: _stockDbc, targetVersion: 'v1.2.1');
    await tester.pumpWidget(_host(InstallPlanPanel(
      plan: plan,
      mdbState: _mdbState,
      dbcState: _stockDbc,
      targetVersion: 'v1.2.1',
      onChanged: (_) {},
      onContinue: () {},
    )));

    expect(find.text('MDB (main board)'), findsOneWidget);
    expect(find.text('DBC (dashboard)'), findsOneWidget);
    expect(find.text('Currently v1.2.0'), findsOneWidget);
    expect(find.text('Version unknown'), findsOneWidget);
  });

  testWidgets('disables Upgrade for a board that cannot take one',
      (tester) async {
    InstallPlan? seen;
    final plan = InstallPlan.defaults(
        mdb: _mdbState, dbc: _stockDbc, targetVersion: 'v1.2.1');
    await tester.pumpWidget(_host(InstallPlanPanel(
      plan: plan,
      mdbState: _mdbState,
      dbcState: _stockDbc,
      targetVersion: 'v1.2.1',
      onChanged: (p) => seen = p,
      onContinue: () {},
    )));

    expect(find.text('Upgrade needs a known version on this board'),
        findsOneWidget);

    // The DBC's Upgrade tile is the disabled one: tapping it must not be
    // able to select it. This is the property that actually protects the
    // user, not just the blocker text rendering.
    final upgradeLabels = find.text('Upgrade');
    expect(upgradeLabels, findsNWidgets(2));
    await tester.tap(upgradeLabels.at(1));
    await tester.pump();
    expect(seen, isNull);

    // Sanity check that taps reach the panel at all: an enabled option that
    // is not already selected does trigger onChanged. (Tapping a tile for
    // the value it is already showing does not re-invoke onChanged in this
    // Flutter version's RadioGroup, so that would not be a valid check here.)
    await tester.tap(find.text('Leave alone').first);
    await tester.pump();
    expect(seen, isNotNull);
    expect(seen!.mdb.action, BoardAction.leave);
  });

  testWidgets('the reason a board cannot upgrade sits on the disabled option',
      (tester) async {
    final plan = InstallPlan.defaults(
        mdb: _mdbState, dbc: _stockDbc, targetVersion: 'v1.2.1');
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_host(InstallPlanPanel(
      plan: plan,
      mdbState: _mdbState,
      dbcState: _stockDbc,
      targetVersion: 'v1.2.1',
      onChanged: (_) {},
      onContinue: () {},
    )));

    // The reason used to be the last line of the card, which a short window
    // pushed below the fold: the user met a greyed out choice with nothing
    // saying why. It belongs to the option it disables.
    final reason = find.text('Upgrade needs a known version on this board');
    expect(reason, findsOneWidget);
    final reasonBox = tester.getRect(reason);
    final upgradeBox = tester.getRect(find.text('Upgrade').at(1));
    expect(reasonBox.top, greaterThan(upgradeBox.top));
    expect(reasonBox.top - upgradeBox.bottom, lessThan(24.0));

    // And it is on screen without scrolling.
    expect(reasonBox.bottom, lessThanOrEqualTo(600.0));
  });

  testWidgets('a stock main board cannot be left alone', (tester) async {
    const stockMdb = BoardState(
        board: Board.mdb, isLibrescoot: false, provenance: StateProvenance.live);
    InstallPlan? seen;
    final plan = InstallPlan.defaults(
        mdb: stockMdb, dbc: _stockDbc, targetVersion: 'v1.2.1');
    await tester.pumpWidget(_host(InstallPlanPanel(
      plan: plan,
      mdbState: stockMdb,
      dbcState: _stockDbc,
      targetVersion: 'v1.2.1',
      onChanged: (p) => seen = p,
      onContinue: () {},
    )));

    // It leads nowhere: the dashboard is only reachable through the MDB and
    // the tools that reach it are Librescoot's, so leaving it stock means
    // there is no plan left to make.
    expect(find.text('A stock main board has to be installed before anything '
        'else can be done'), findsOneWidget);
    await tester.tap(find.text('Leave alone').first);
    await tester.pump();
    expect(seen, isNull);
  });

  testWidgets('choosing an action reports a new plan', (tester) async {
    InstallPlan? seen;
    final plan = InstallPlan.defaults(
        mdb: _mdbState, dbc: _stockDbc, targetVersion: 'v1.2.1');
    await tester.pumpWidget(_host(InstallPlanPanel(
      plan: plan,
      mdbState: _mdbState,
      dbcState: _stockDbc,
      targetVersion: 'v1.2.1',
      onChanged: (p) => seen = p,
      onContinue: () {},
    )));

    await tester.tap(find.text('Leave alone').first);
    await tester.pump();

    expect(seen, isNotNull);
    expect(seen!.mdb.action, BoardAction.leave);
  });

  testWidgets('warns that tiles need the cable swap', (tester) async {
    final plan = InstallPlan(
      mdb: const BoardPlan(board: Board.mdb, action: BoardAction.upgrade),
      dbc: const BoardPlan(board: Board.dbc, action: BoardAction.leave),
      installTiles: true,
    );
    await tester.pumpWidget(_host(InstallPlanPanel(
      plan: plan,
      mdbState: _mdbState,
      dbcState: _stockDbc,
      targetVersion: 'v1.2.1',
      onChanged: (_) {},
      onContinue: () {},
    )));

    expect(
        find.textContaining('needs the DBC cable swap'), findsOneWidget);
  });

  testWidgets('blocks Continue when nothing is selected', (tester) async {
    const plan = InstallPlan(
      mdb: BoardPlan(board: Board.mdb, action: BoardAction.leave),
      dbc: BoardPlan(board: Board.dbc, action: BoardAction.leave),
    );
    await tester.pumpWidget(_host(InstallPlanPanel(
      plan: plan,
      mdbState: _mdbState,
      dbcState: _stockDbc,
      targetVersion: 'v1.2.1',
      onChanged: (_) {},
      onContinue: () {},
    )));

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    expect(find.text('Nothing selected. Pick at least one action to continue.'),
        findsOneWidget);
  });
  testWidgets('keeps Continue on screen and tappable in a short window',
      (tester) async {
    // Regression guard for the pinned Continue button. The panel scrolls its
    // own board list so the button stays reachable when the window is too
    // short for everything to fit, and that only holds while the panel is
    // given a bounded height: installer_screen renders this phase outside its
    // outer scroll view for exactly this reason. Nest it back inside one and
    // this test still passes the findsOneWidget, but the tap misses.
    tester.view.physicalSize = const Size(1000, 300);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var continued = false;
    final plan = InstallPlan.defaults(
        mdb: _mdbState, dbc: _stockDbc, targetVersion: 'v1.2.1');
    await tester.pumpWidget(_host(InstallPlanPanel(
      plan: plan,
      mdbState: _mdbState,
      dbcState: _stockDbc,
      targetVersion: 'v1.2.1',
      onChanged: (_) {},
      onContinue: () => continued = true,
    )));

    final continueButton = find.widgetWithText(FilledButton, 'Continue');
    expect(continueButton, findsOneWidget);
    await tester.tap(continueButton);
    expect(continued, isTrue,
        reason: 'Continue must stay hit-testable, not scroll off the bottom');
  });

  testWidgets('a dashboard wipe does not claim to erase settings or keycards',
      (tester) async {
    // Settings, keycards and trips are all main-board state. The dashboard's
    // own storage holds the offline maps, so promising more than that talks
    // people out of a clean install for a cost it does not have.
    await tester.pumpWidget(_host(InstallPlanPanel(
      mdbState: _mdbState,
      dbcState: _stockDbc,
      plan: const InstallPlan(
        mdb: BoardPlan(board: Board.mdb, action: BoardAction.cleanInstall),
        dbc: BoardPlan(board: Board.dbc, action: BoardAction.cleanInstall),
      ),
      targetVersion: 'v1.2.1',
      onChanged: (_) {},
      onContinue: () {},
    )));

    expect(find.text('Erases the offline maps only'), findsOneWidget);
    // The main board keeps the wording that is true for it.
    expect(find.text('Erases settings, keycards, maps and trips'),
        findsOneWidget);
  });
}
