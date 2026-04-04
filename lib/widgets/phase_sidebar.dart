import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../l10n/app_localizations.dart';
import '../l10n/phase_l10n.dart';
import '../models/download_state.dart';
import '../models/installer_phase.dart';

class PhaseSidebar extends StatelessWidget {
  const PhaseSidebar({
    super.key,
    required this.currentPhase,
    required this.completedPhases,
    this.downloadItems = const [],
  });

  final InstallerPhase currentPhase;
  final Set<InstallerPhase> completedPhases;
  final List<DownloadItem> downloadItems;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: 220,
      color: const Color(0xFF1A1A2E),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SvgPicture.asset(
                        'assets/logotype.svg',
                        height: 24,
                        colorFilter: const ColorFilter.mode(
                          Colors.tealAccent,
                          BlendMode.srcIn,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Installer',
                        style: TextStyle(
                          color: Colors.tealAccent.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                for (final phase in InstallerPhase.values)
                  _PhaseItem(
                    phase: phase,
                    isCurrent: phase == currentPhase,
                    isCompleted: completedPhases.contains(phase),
                    isPast: phase.index < currentPhase.index,
                  ),
              ],
            ),
          ),
          if (downloadItems.isNotEmpty && !downloadItems.every((i) => i.isComplete))
            _DownloadStatus(items: downloadItems, l10n: l10n),
        ],
      ),
    );
  }
}

class _PhaseItem extends StatelessWidget {
  const _PhaseItem({
    required this.phase,
    required this.isCurrent,
    required this.isCompleted,
    required this.isPast,
  });

  final InstallerPhase phase;
  final bool isCurrent;
  final bool isCompleted;
  final bool isPast;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final Color textColor;
    final Widget leading;

    if (isCompleted || isPast) {
      textColor = Colors.grey;
      leading = const Icon(Icons.check, size: 16, color: Colors.grey);
    } else if (isCurrent) {
      textColor = Colors.tealAccent;
      leading = const Icon(Icons.circle, size: 12, color: Colors.tealAccent);
    } else {
      textColor = Colors.grey.shade700;
      leading = Icon(Icons.circle_outlined, size: 12, color: Colors.grey.shade700);
    }

    return Container(
      color: isCurrent ? Colors.tealAccent.withValues(alpha: 0.08) : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 24, child: Center(child: leading)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              phase.localizedTitle(l10n),
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DownloadStatus extends StatelessWidget {
  const _DownloadStatus({required this.items, required this.l10n});

  final List<DownloadItem> items;
  final AppLocalizations l10n;

  static const _labels = {
    DownloadItemType.mdbFirmware: 'MDB',
    DownloadItemType.mdbBmap: 'Bmap',
    DownloadItemType.dbcFirmware: 'DBC',
    DownloadItemType.dbcBmap: 'Bmap',
    DownloadItemType.osmTiles: 'Maps',
    DownloadItemType.valhallaTiles: 'Routes',
  };

  @override
  Widget build(BuildContext context) {
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
              Text('Downloads',
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.isComplete ? Icons.check_circle : Icons.circle_outlined,
                      size: 10,
                      color: item.isComplete ? Colors.tealAccent : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      _labels[item.type] ?? '',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
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
