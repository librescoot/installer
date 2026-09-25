import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/l10n/app_localizations.dart';
import 'package:librescoot_installer/models/board_state.dart';
import 'package:librescoot_installer/models/install_plan.dart';
import 'package:librescoot_installer/widgets/install_plan_panel.dart';

// The panel is the scrolling body of a PhaseLayout in the app, so it is given
// one here too. Hosting a bare Column in a fixed-size window overflows on the
// taller plans and reports a layout error rather than the assertion under test.
Widget _host(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'),
  home: Scaffold(body: SingleChildScrollView(child: child)),
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
const _librescootDbc = BoardState(
  board: Board.dbc,
  isLibrescoot: true,
  provenance: StateProvenance.lastSeen,
  version: 'v1.2.0',
  hasMender: true,
);

void main() {
  testWidgets('shows both boards with their current versions', (tester) async {
    final plan = InstallPlan.defaults(
      mdb: _mdbState,
      dbc: _stockDbc,
      targetVersion: 'v1.2.1',
    );
    await tester.pumpWidget(
      _host(
        InstallPlanPanel(
          plan: plan,
          mdbState: _mdbState,
          dbcState: _stockDbc,
          targetVersion: 'v1.2.1',
          onChanged: (_) {},
        ),
      ),
    );

    expect(find.text('MDB (main board)'), findsOneWidget);
    expect(find.text('DBC (dashboard)'), findsOneWidget);
    // The distribution is named alongside the version: the two use
    // overlapping numbering, so a bare number says nothing about which one it
    // belongs to.
    expect(find.text('Currently Librescoot v1.2.0'), findsOneWidget);
    expect(find.text('Version unknown'), findsOneWidget);
    expect(find.text('Upgrade to Librescoot v1.2.1'), findsNWidgets(2));
    expect(find.text('Clean install Librescoot v1.2.1'), findsNWidgets(2));
  });

  testWidgets('names bootstrap images instead of installed Librescoot', (
    tester,
  ) async {
    const minimalMdb = BoardState(
      board: Board.mdb,
      isLibrescoot: true,
      provenance: StateProvenance.live,
      version: 'v1.3.0',
      hasMender: true,
      isMinimalImage: true,
    );
    const minimalDbc = BoardState(
      board: Board.dbc,
      isLibrescoot: true,
      provenance: StateProvenance.lastSeen,
      version: 'v1.3.1',
      hasMender: true,
      isMinimalImage: true,
    );
    await tester.pumpWidget(
      _host(
        InstallPlanPanel(
          plan: InstallPlan.defaults(
            mdb: minimalMdb,
            dbc: minimalDbc,
            targetVersion: 'v1.3.1',
          ),
          mdbState: minimalMdb,
          dbcState: minimalDbc,
          targetVersion: 'v1.3.1',
          onChanged: (_) {},
        ),
      ),
    );

    expect(
      find.text('Currently Librescoot Bootstrap Image (MDB) v1.3.0'),
      findsOneWidget,
    );
    expect(
      find.text('Last seen running Librescoot Bootstrap Image (DBC) v1.3.1'),
      findsOneWidget,
    );
    expect(find.textContaining('Currently Librescoot v1.3.0'), findsNothing);
  });

  testWidgets('disables Upgrade for a board that cannot take one', (
    tester,
  ) async {
    InstallPlan? seen;
    final plan = InstallPlan.defaults(
      mdb: _mdbState,
      dbc: _stockDbc,
      targetVersion: 'v1.2.1',
    );
    await tester.pumpWidget(
      _host(
        InstallPlanPanel(
          plan: plan,
          mdbState: _mdbState,
          dbcState: _stockDbc,
          targetVersion: 'v1.2.1',
          onChanged: (p) => seen = p,
        ),
      ),
    );

    expect(
      find.text('Upgrade needs a known version on this board'),
      findsOneWidget,
    );

    // The DBC's Upgrade tile is the disabled one: tapping it must not be
    // able to select it. This is the property that actually protects the
    // user, not just the blocker text rendering.
    final upgradeLabels = find.text('Upgrade to Librescoot v1.2.1');
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

  testWidgets('the reason a board cannot upgrade sits on the disabled option', (
    tester,
  ) async {
    final plan = InstallPlan.defaults(
      mdb: _mdbState,
      dbc: _stockDbc,
      targetVersion: 'v1.2.1',
    );
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _host(
        InstallPlanPanel(
          plan: plan,
          mdbState: _mdbState,
          dbcState: _stockDbc,
          targetVersion: 'v1.2.1',
          onChanged: (_) {},
        ),
      ),
    );

    // The reason used to be the last line of the card, which a short window
    // pushed below the fold: the user met a greyed out choice with nothing
    // saying why. It belongs to the option it disables.
    final reason = find.text('Upgrade needs a known version on this board');
    expect(reason, findsOneWidget);
    final reasonBox = tester.getRect(reason);
    final upgradeBox = tester.getRect(
      find.text('Upgrade to Librescoot v1.2.1').at(1),
    );
    expect(reasonBox.top, greaterThan(upgradeBox.top));
    expect(reasonBox.top - upgradeBox.bottom, lessThan(24.0));

    // And it is on screen without scrolling.
    expect(reasonBox.bottom, lessThanOrEqualTo(600.0));
  });

  testWidgets('a stock main board cannot be left alone', (tester) async {
    const stockMdb = BoardState(
      board: Board.mdb,
      isLibrescoot: false,
      provenance: StateProvenance.live,
    );
    InstallPlan? seen;
    final plan = InstallPlan.defaults(
      mdb: stockMdb,
      dbc: _stockDbc,
      targetVersion: 'v1.2.1',
    );
    await tester.pumpWidget(
      _host(
        InstallPlanPanel(
          plan: plan,
          mdbState: stockMdb,
          dbcState: _stockDbc,
          targetVersion: 'v1.2.1',
          onChanged: (p) => seen = p,
        ),
      ),
    );

    // It leads nowhere: the dashboard is only reachable through the MDB and
    // the tools that reach it are Librescoot's, so leaving it stock means
    // there is no plan left to make.
    expect(
      find.text(
        'A stock main board has to be installed before anything '
        'else can be done',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Leave alone').first);
    await tester.pump();
    expect(seen, isNull);
  });

  testWidgets('choosing an action reports a new plan', (tester) async {
    InstallPlan? seen;
    final plan = InstallPlan.defaults(
      mdb: _mdbState,
      dbc: _stockDbc,
      targetVersion: 'v1.2.1',
    );
    await tester.pumpWidget(
      _host(
        InstallPlanPanel(
          plan: plan,
          mdbState: _mdbState,
          dbcState: _stockDbc,
          targetVersion: 'v1.2.1',
          onChanged: (p) => seen = p,
        ),
      ),
    );

    await tester.tap(find.text('Leave alone').first);
    await tester.pump();

    expect(seen, isNotNull);
    expect(seen!.mdb.action, BoardAction.leave);
  });

  testWidgets('offline navigation installs from the DBC header checkbox', (
    tester,
  ) async {
    InstallPlan? seen;
    final plan = InstallPlan(
      mdb: const BoardPlan(board: Board.mdb, action: BoardAction.upgrade),
      dbc: const BoardPlan(board: Board.dbc, action: BoardAction.leave),
      installTiles: true,
    );
    await tester.pumpWidget(
      _host(
        InstallPlanPanel(
          plan: plan,
          mdbState: _mdbState,
          dbcState: _librescootDbc,
          targetVersion: 'v1.2.1',
          onChanged: (p) => seen = p,
        ),
      ),
    );

    expect(find.text('Install offline maps and navigation'), findsOneWidget);
    expect(find.textContaining('Adds a dashboard step'), findsNothing);
    final header = tester.getRect(find.text('DBC (dashboard)'));
    final checkbox = tester.getRect(find.byType(Checkbox));
    expect((header.center.dy - checkbox.center.dy).abs(), lessThan(26));

    await tester.ensureVisible(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(seen, isNotNull);
    expect(seen!.installTiles, isFalse);
  });

  testWidgets('compact DBC card wraps the maps checkbox without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(480, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _host(
        InstallPlanPanel(
          plan: const InstallPlan(
            mdb: BoardPlan(board: Board.mdb, action: BoardAction.upgrade),
            dbc: BoardPlan(board: Board.dbc, action: BoardAction.leave),
            installTiles: true,
          ),
          mdbState: _mdbState,
          dbcState: _librescootDbc,
          targetVersion: 'testing-20260924T225338',
          onChanged: (_) {},
        ),
      ),
    );
    await tester.ensureVisible(
      find.text('Install offline maps and navigation'),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('unknown unchanged DBC cannot receive offline maps', (
    tester,
  ) async {
    InstallPlan? seen;
    await tester.pumpWidget(
      _host(
        InstallPlanPanel(
          plan: const InstallPlan(
            mdb: BoardPlan(board: Board.mdb, action: BoardAction.upgrade),
            dbc: BoardPlan(board: Board.dbc, action: BoardAction.leave),
            installTiles: true,
          ),
          mdbState: _mdbState,
          dbcState: _stockDbc,
          targetVersion: 'v1.2.1',
          onChanged: (p) => seen = p,
        ),
      ),
    );

    expect(
      find.textContaining('The DBC software could not be identified'),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Choose Clean install for the DBC, or continue without maps',
      ),
      findsOneWidget,
    );
    final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
    expect(checkbox.value, isFalse);
    expect(checkbox.onChanged, isNull);
    expect(seen, isNull);
  });

  testWidgets('bootstrap DBC explains why maps are unavailable', (
    tester,
  ) async {
    const bootstrapDbc = BoardState(
      board: Board.dbc,
      isLibrescoot: true,
      provenance: StateProvenance.lastSeen,
      version: 'v1.3.1',
      hasMender: true,
      isMinimalImage: true,
    );
    await tester.pumpWidget(
      _host(
        InstallPlanPanel(
          plan: const InstallPlan(
            mdb: BoardPlan(board: Board.mdb, action: BoardAction.upgrade),
            dbc: BoardPlan(board: Board.dbc, action: BoardAction.leave),
          ),
          mdbState: _mdbState,
          dbcState: bootstrapDbc,
          targetVersion: 'v1.3.1',
          onChanged: (_) {},
        ),
      ),
    );

    expect(
      find.textContaining('The DBC is running a bootstrap image'),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Choose Clean install for the DBC, or continue without maps',
      ),
      findsOneWidget,
    );
    final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
    expect(checkbox.value, isFalse);
    expect(checkbox.onChanged, isNull);
  });

  testWidgets('leaving an unknown DBC clears selected maps', (tester) async {
    InstallPlan? seen;
    await tester.pumpWidget(
      _host(
        InstallPlanPanel(
          plan: const InstallPlan(
            mdb: BoardPlan(board: Board.mdb, action: BoardAction.upgrade),
            dbc: BoardPlan(board: Board.dbc, action: BoardAction.cleanInstall),
            installTiles: true,
          ),
          mdbState: _mdbState,
          dbcState: _stockDbc,
          targetVersion: 'v1.2.1',
          onChanged: (p) => seen = p,
        ),
      ),
    );

    await tester.tap(find.text('Leave alone').last);
    await tester.pump();
    expect(seen, isNotNull);
    expect(seen!.dbc.action, BoardAction.leave);
    expect(seen!.installTiles, isFalse);
  });

  testWidgets('maps that were never downloaded cannot be chosen here', (
    tester,
  ) async {
    InstallPlan? seen;
    await tester.pumpWidget(
      _host(
        InstallPlanPanel(
          plan: InstallPlan(
            mdb: const BoardPlan(board: Board.mdb, action: BoardAction.upgrade),
            dbc: const BoardPlan(board: Board.dbc, action: BoardAction.leave),
            installTiles: false,
          ),
          mdbState: _mdbState,
          dbcState: _stockDbc,
          targetVersion: 'v1.2.1',
          tilesAvailable: false,
          onChanged: (p) => seen = p,
        ),
      ),
    );

    expect(find.textContaining('were not downloaded'), findsOneWidget);
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(seen, isNull, reason: 'a disabled control must not change the plan');
  });

  testWidgets('says so when the plan selects nothing', (tester) async {
    // The Continue button itself now lives in the enclosing PhaseLayout, so
    // what this panel still owes the user is the reason it is disabled.
    const plan = InstallPlan(
      mdb: BoardPlan(board: Board.mdb, action: BoardAction.leave),
      dbc: BoardPlan(board: Board.dbc, action: BoardAction.leave),
    );
    await tester.pumpWidget(
      _host(
        InstallPlanPanel(
          plan: plan,
          mdbState: _mdbState,
          dbcState: _stockDbc,
          targetVersion: 'v1.2.1',
          onChanged: (_) {},
        ),
      ),
    );

    expect(plan.isNoOp, isTrue);
    expect(
      find.text('Nothing selected. Pick at least one action to continue.'),
      findsOneWidget,
    );
  });

  testWidgets('a dashboard wipe does not claim to erase settings or keycards', (
    tester,
  ) async {
    // Settings and keycards are main-board state. The dashboard's
    // own storage holds the offline maps, so promising more than that talks
    // people out of a clean install for a cost it does not have.
    await tester.pumpWidget(
      _host(
        InstallPlanPanel(
          mdbState: _mdbState,
          dbcState: _stockDbc,
          plan: const InstallPlan(
            mdb: BoardPlan(board: Board.mdb, action: BoardAction.cleanInstall),
            dbc: BoardPlan(board: Board.dbc, action: BoardAction.cleanInstall),
          ),
          targetVersion: 'v1.2.1',
          onChanged: (_) {},
        ),
      ),
    );

    expect(find.text('Erases offline maps and navigation data'), findsOneWidget);
    // Main-board data is erased, while detected preservable configuration is
    // offered as a separate choice rather than silently discarded.
    expect(
      find.text(
        'Erases main-board data. Detected device configurations can be '
        'selected in the next step',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a locked MDB shows its note and offers no choice', (
    tester,
  ) async {
    // The direct mass-storage route: the MDB cannot be read and can only be
    // clean-installed, so its radios show what will happen rather than ask.
    // The dashboard card stays a choice.
    const unknownMdb = BoardState(
      board: Board.mdb,
      isLibrescoot: false,
      provenance: StateProvenance.unknown,
    );
    final plan = InstallPlan.directMassStorage();
    await tester.pumpWidget(
      _host(
        InstallPlanPanel(
          plan: plan,
          mdbState: unknownMdb,
          dbcState: _stockDbc,
          targetVersion: 'v1.3.0',
          mdbLockedNote: 'locked note',
          onChanged: (_) {},
        ),
      ),
    );

    expect(find.text('locked note'), findsOneWidget);
    final tiles = tester
        .widgetList<RadioListTile<BoardAction>>(
          find.byType(RadioListTile<BoardAction>),
        )
        .toList();
    // Three per board, MDB first.
    expect(tiles.length, 6);
    for (final tile in tiles.take(3)) {
      expect(tile.enabled, isFalse, reason: 'MDB ${tile.value} must be locked');
    }
    final dbcClean = tiles
        .skip(3)
        .firstWhere((t) => t.value == BoardAction.cleanInstall);
    expect(dbcClean.enabled, isTrue);
  });
}
