import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/board_state.dart';
import '../models/install_plan.dart';

/// The per-board decision screen. Replaces the two skip checkboxes on the
/// health check with one line per board saying what will happen to it.
class InstallPlanPanel extends StatelessWidget {
  const InstallPlanPanel({
    super.key,
    required this.plan,
    required this.mdbState,
    required this.dbcState,
    required this.targetVersion,
    required this.onChanged,
  });

  final InstallPlan plan;
  final BoardState mdbState;
  final BoardState dbcState;
  final String targetVersion;
  final ValueChanged<InstallPlan> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Only the board cards and warnings live here now. The heading and the
    // Continue button are the enclosing PhaseLayout's job, which is where
    // every other phase keeps them too; this panel used to pin them itself
    // because it was the only screen that needed to.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _boardCard(context, l10n, l10n.boardMdb, mdbState, plan.mdb,
            (p) => onChanged(plan.withMdb(p))),
        const SizedBox(height: 12),
        _boardCard(context, l10n, l10n.boardDbc, dbcState, plan.dbc,
            (p) => onChanged(plan.withDbc(p))),
        if (plan.installTiles && !plan.needsDbcWork)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(l10n.planTilesNeedDbcHandoff,
                style: Theme.of(context).textTheme.bodySmall),
          ),
        if (plan.dbcWorkStrandedOn(mdbState))
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(l10n.planDbcNeedsLibrescootMdb,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.orange.shade300)),
          ),
        if (plan.isNoOp)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(l10n.planNothingToDo,
                style: Theme.of(context).textTheme.bodySmall),
          ),
      ],
    );
  }

  Widget _boardCard(
    BuildContext context,
    AppLocalizations l10n,
    String title,
    BoardState state,
    BoardPlan boardPlan,
    ValueChanged<BoardPlan> onBoardChanged,
  ) {
    assert(state.board == boardPlan.board,
        'state and boardPlan must describe the same board');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(_versionLabel(l10n, state),
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            // RadioListTile's own groupValue/onChanged were deprecated after
            // Flutter 3.32 and this checkout is 3.41.9, so selection state
            // lives on the enclosing RadioGroup and an unavailable option is
            // turned off with `enabled` rather than a null callback.
            RadioGroup<BoardAction>(
              groupValue: boardPlan.action,
              onChanged: (v) {
                if (v != null) onBoardChanged(boardPlan.withAction(v));
              },
              child: Column(
                children: [
                  for (final action in const [
                    BoardAction.upgrade,
                    BoardAction.cleanInstall,
                    BoardAction.leave,
                  ])
                    RadioListTile<BoardAction>(
                      value: action,
                      enabled: !(action == BoardAction.upgrade &&
                              !boardPlan.canUpgrade) &&
                          !_leavingStockMdbIsPointless(action, state),
                      title: Text(_actionLabel(l10n, action)),
                      // A disabled option explains itself in place. The
                      // reason used to sit at the bottom of the card, below
                      // the fold on a short window, so the user met a greyed
                      // out choice with nothing saying why.
                      subtitle: Text(
                        _leavingStockMdbIsPointless(action, state)
                            ? l10n.actionLeaveBlockedStockMdb
                            : action == BoardAction.upgrade &&
                                    boardPlan.blocker != null
                                ? _blockerLabel(l10n, boardPlan.blocker!)
                                : _actionDetail(l10n, action, state.board),
                      ),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                ],
              ),
            ),
            // Upgrade keeps /data. That is only safe while the services that
            // will read it are at least as new as the ones that wrote it, so
            // going backwards or sideways has to say so before it runs.
            if (boardPlan.action == BoardAction.upgrade) ...[
              if (_keepDataWarning(l10n, state) != null) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        size: 16, color: Colors.orangeAccent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _keepDataWarning(l10n, state)!,
                        style: const TextStyle(fontSize: 12, color: Colors.orangeAccent),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  /// The warning to show under an Upgrade, or null when the target is at least
  /// as new as what the board runs.
  String? _keepDataWarning(AppLocalizations l10n, BoardState state) =>
      switch (InstallPlan.versionDirection(state.version, targetVersion)) {
        VersionDirection.older => l10n.upgradeDowngradeWarning,
        VersionDirection.otherChannel => l10n.upgradeChannelSwitchWarning,
        _ => null,
      };

  String _versionLabel(AppLocalizations l10n, BoardState state) {
    final version = state.version;
    if (version == null || version.isEmpty) return l10n.boardVersionUnknown;
    return state.provenance == StateProvenance.lastSeen
        ? l10n.boardVersionLastSeen(version)
        : l10n.boardVersionCurrent(version);
  }

  String _actionLabel(AppLocalizations l10n, BoardAction action) =>
      switch (action) {
        BoardAction.upgrade => l10n.actionUpgrade,
        BoardAction.cleanInstall => l10n.actionCleanInstall,
        BoardAction.leave => l10n.actionLeave,
        BoardAction.fullImage => l10n.artifactFallBackToFullImage,
      };

  /// What each action costs, per board. Settings, keycards and trips all live
  /// on the main board; the dashboard's own storage holds the offline maps and
  /// nothing else, so wiping it loses only those, and only until the maps are
  /// written back.
  String _actionDetail(
          AppLocalizations l10n, BoardAction action, Board board) =>
      switch ((action, board)) {
        (BoardAction.upgrade, Board.dbc) => l10n.actionUpgradeDetailDbc,
        (BoardAction.cleanInstall, Board.dbc) ||
        (BoardAction.fullImage, Board.dbc) =>
          l10n.actionCleanInstallDetailDbc,
        (BoardAction.upgrade, _) => l10n.actionUpgradeDetail,
        (BoardAction.cleanInstall, _) || (BoardAction.fullImage, _) =>
          l10n.actionCleanInstallDetail,
        (BoardAction.leave, _) => l10n.actionLeaveDetail,
      };

  /// Leaving a stock main board alone leads nowhere. The dashboard is only
  /// reachable through it and the tools that do the reaching are Librescoot's,
  /// so with the MDB untouched there is no dashboard work and no tiles either,
  /// and the only remaining plan is to do nothing at all. Better to take the
  /// option away here than to let it be chosen and refuse the whole plan later.
  bool _leavingStockMdbIsPointless(BoardAction action, BoardState state) =>
      action == BoardAction.leave &&
      state.board == Board.mdb &&
      !state.isLibrescoot;

  String _blockerLabel(AppLocalizations l10n, UpgradeBlocker blocker) =>
      switch (blocker) {
        UpgradeBlocker.notLibrescoot => l10n.upgradeBlockedNotLibrescoot,
        UpgradeBlocker.stateUnknown => l10n.upgradeBlockedStateUnknown,
        UpgradeBlocker.minimalImage => l10n.upgradeBlockedMinimalImage,
        UpgradeBlocker.noMender => l10n.upgradeBlockedNoMender,
      };
}
