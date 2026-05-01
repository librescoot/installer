import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/download_state.dart';
import '../theme.dart';

class DownloadProgressWidget extends StatelessWidget {
  const DownloadProgressWidget({super.key, required this.items});

  final List<DownloadItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.downloads, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                if (item.isComplete)
                  const Icon(Icons.check_circle, size: 16, color: kAccent)
                else
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      value: item.progress > 0 ? item.progress : null,
                      strokeWidth: 2,
                    ),
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _labelFor(item.type, l10n),
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade300),
                  ),
                ),
                Text(
                  item.isComplete
                      ? '${(item.expectedSize / 1024 / 1024).toStringAsFixed(0)} MB'
                      : '${(item.bytesDownloaded / 1024 / 1024).toStringAsFixed(0)} / ${(item.expectedSize / 1024 / 1024).toStringAsFixed(0)} MB',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _labelFor(DownloadItemType type, AppLocalizations l10n) => switch (type) {
        DownloadItemType.mdbFirmware => l10n.downloadMdbFirmware,
        DownloadItemType.mdbBmap => 'MDB Bmap',
        DownloadItemType.dbcFirmware => l10n.downloadDbcFirmware,
        DownloadItemType.dbcBmap => 'DBC Bmap',
        DownloadItemType.osmTiles => l10n.downloadMapTiles,
        DownloadItemType.valhallaTiles => l10n.downloadRoutingTiles,
      };
}
