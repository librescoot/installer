import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../l10n/app_localizations.dart';
import '../l10n/phase_l10n.dart';
import '../main.dart' show appVersion;
import '../models/download_state.dart';
import '../models/installer_phase.dart';
import '../theme.dart';
import 'language_switcher.dart';

class PhaseSidebar extends StatelessWidget {
  const PhaseSidebar({
    super.key,
    required this.currentPhase,
    required this.completedPhases,
    this.skippedPhases = const {},
    this.upgradingSteps = const {},
    this.downloadItems = const [],
  });

  final InstallerPhase currentPhase;
  final Set<InstallerPhase> completedPhases;
  final Set<InstallerPhase> skippedPhases;

  /// Major steps whose board the plan is upgrading rather than flashing.
  /// Only changes the wording; the phases themselves are the same.
  final Set<MajorStep> upgradingSteps;
  final List<DownloadItem> downloadItems;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      // Wide enough for the longest step title in either language ("MDB
      // aktualisieren", 238px at this weight) to stay on one line. At 220
      // they wrapped and left the markers hanging beside ragged text.
      width: 300,
      color: kBgSidebar,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: SvgPicture.asset(
                          'assets/logotype.svg',
                          height: 24,
                          colorFilter: const ColorFilter.mode(
                            kAccent,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Installer',
                                style: TextStyle(
                                  color: kAccent.withValues(alpha: 0.7),
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                appVersion,
                                style: TextStyle(
                                  color: kAccent.withValues(alpha: 0.45),
                                  fontSize: 10,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 4),
                          const LanguageSwitcher(),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                for (final major in MajorStep.values) ...[
                  _MajorStepItem(
                    step: major,
                    isActive: major.isActive(currentPhase),
                    isCompleted: major.isCompleted(currentPhase),
                    isSkipped: major.phases.every((p) => skippedPhases.contains(p)),
                    isUpgrade: upgradingSteps.contains(major),
                    l10n: l10n,
                  ),
                  // Show substeps only for the active major step
                  if (major.isActive(currentPhase) && major.phases.length > 1)
                    for (final phase in major.phases)
                      if (!phase.hiddenUnlessActive || phase == currentPhase)
                        _SubStepItem(
                          phase: phase,
                          isCurrent: phase == currentPhase,
                          isCompleted: completedPhases.contains(phase) || phase.index < currentPhase.index,
                          l10n: l10n,
                        ),
                ],
              ],
            ),
          ),
          if (downloadItems.isNotEmpty)
            downloadItems.every((i) => i.isComplete)
                ? const _DownloadsFinished()
                : _DownloadStatus(items: downloadItems),
        ],
      ),
    );
  }
}

class _MajorStepItem extends StatelessWidget {
  const _MajorStepItem({
    required this.step,
    required this.isActive,
    required this.isCompleted,
    required this.l10n,
    this.isSkipped = false,
    this.isUpgrade = false,
  });

  final MajorStep step;
  final bool isActive;
  final bool isCompleted;
  final bool isSkipped;
  final bool isUpgrade;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final Color textColor;
    final Widget leading;
    final int stepNum = step.index + 1;

    if (isSkipped) {
      textColor = Colors.grey.shade700;
      leading = Icon(Icons.circle_outlined, size: 18, color: Colors.grey.shade700);
    } else if (isCompleted) {
      textColor = Colors.grey;
      leading = const Icon(Icons.check_circle, size: 18, color: kAccent);
    } else if (isActive) {
      textColor = kAccent;
      leading = Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: kAccent,
        ),
        child: Center(
          child: Text(
            '$stepNum',
            style: const TextStyle(color: kOnAccent, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
      );
    } else {
      textColor = Colors.grey.shade600;
      leading = Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade700),
        ),
        child: Center(
          child: Text(
            '$stepNum',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 11),
          ),
        ),
      );
    }

    return Container(
      color: isActive ? kAccent.withValues(alpha: 0.06) : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          leading,
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.localizedTitle(l10n, upgrade: isUpgrade),
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                // Its own line rather than a suffix in brackets, which pushed
                // the title into a second, ragged line of its own.
                if (isSkipped)
                  Text(
                    l10n.majorStepSkippedSuffix,
                    style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 11,
                        fontStyle: FontStyle.italic),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SubStepItem extends StatelessWidget {
  const _SubStepItem({
    required this.phase,
    required this.isCurrent,
    required this.isCompleted,
    required this.l10n,
  });

  final InstallerPhase phase;
  final bool isCurrent;
  final bool isCompleted;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final Color textColor;
    final Widget leading;

    if (isCompleted) {
      textColor = Colors.grey.shade500;
      leading = Icon(Icons.check, size: 12, color: Colors.grey.shade500);
    } else if (isCurrent) {
      textColor = kAccent;
      leading = const Icon(Icons.arrow_right, size: 14, color: kAccent);
    } else {
      textColor = Colors.grey.shade700;
      leading = Icon(Icons.circle_outlined, size: 8, color: Colors.grey.shade700);
    }

    return Padding(
      padding: const EdgeInsets.only(left: 44, right: 16, top: 2, bottom: 2),
      child: Row(
        children: [
          SizedBox(width: 16, child: Center(child: leading)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              phase.localizedTitle(l10n),
              style: TextStyle(
                color: textColor,
                fontSize: 11,
                fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DownloadsFinished extends StatelessWidget {
  const _DownloadsFinished();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade800)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, size: 14, color: kAccent),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.downloadsFinished,
                    style: const TextStyle(fontSize: 11, color: kAccent)),
                const SizedBox(height: 2),
                Text(l10n.downloadsFinishedHint,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DownloadStatus extends StatelessWidget {
  const _DownloadStatus({required this.items});

  final List<DownloadItem> items;

  /// The chips were English in a German window: Artifact, Maps, Routes.
  static String? _label(DownloadItemType type, AppLocalizations l10n) =>
      switch (type) {
        DownloadItemType.mdbArtifact => l10n.assetChipMdbArtifact,
        DownloadItemType.dbcArtifact => l10n.assetChipDbcArtifact,
        DownloadItemType.mdbFirmware => l10n.assetChipMdbImage,
        DownloadItemType.dbcFirmware => l10n.assetChipDbcImage,
        DownloadItemType.osmTiles => l10n.assetChipMaps,
        DownloadItemType.valhallaTiles => l10n.assetChipRoutes,
        // Tiny, and tracked with the firmware they belong to.
        DownloadItemType.mdbBmap || DownloadItemType.dbcBmap => null,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final totalBytes = items.fold<int>(0, (s, i) => s + i.expectedSize);
    final downloadedBytes = items.fold<int>(0, (s, i) => s + i.bytesDownloaded);
    final overallProgress = totalBytes > 0 ? downloadedBytes / totalBytes : 0.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade800)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.download, size: 14, color: Colors.grey.shade400),
              const SizedBox(width: 6),
              Text(l10n.downloads,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
              const Spacer(),
              Text(
                '${(downloadedBytes / 1024 / 1024).toStringAsFixed(0)} / ${(totalBytes / 1024 / 1024).toStringAsFixed(0)} MB',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: overallProgress,
            minHeight: 3,
            backgroundColor: Colors.grey.shade800,
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: [
              for (final item in items)
                if (_label(item.type, l10n) case final label?)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.isComplete
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                        size: 10,
                        color: item.isComplete ? kAccent : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        label,
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
            ],
          ),
        ],
      ),
    );
  }
}
