import 'package:flutter/material.dart';
import '../models/download_state.dart';

class DownloadProgressWidget extends StatelessWidget {
  const DownloadProgressWidget({super.key, required this.items});

  final List<DownloadItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Downloads', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                if (item.isComplete)
                  const Icon(Icons.check_circle, size: 16, color: Colors.tealAccent)
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
                    _labelFor(item.type),
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

  String _labelFor(DownloadItemType type) => switch (type) {
        DownloadItemType.mdbFirmware => 'MDB Firmware',
        DownloadItemType.dbcFirmware => 'DBC Firmware',
        DownloadItemType.osmTiles => 'Map Tiles',
        DownloadItemType.valhallaTiles => 'Routing Tiles',
      };
}
