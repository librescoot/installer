import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/download_state.dart';
import '../theme.dart';

class FirmwareChannelSelector extends StatelessWidget {
  const FirmwareChannelSelector({
    super.key,
    required this.channels,
    required this.selected,
    required this.onSelected,
  });

  final Map<DownloadChannel, ({String tag, String date})>? channels;
  final DownloadChannel selected;
  final ValueChanged<DownloadChannel> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final channelInfo = <DownloadChannel, ({String name, String desc})>{
      DownloadChannel.stable: (
        name: l10n.channelStable,
        desc: l10n.channelStableDesc,
      ),
      DownloadChannel.testing: (
        name: l10n.channelTesting,
        desc: l10n.channelTestingDesc,
      ),
      DownloadChannel.nightly: (
        name: l10n.channelNightly,
        desc: l10n.channelNightlyDesc,
      ),
    };

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final channel in DownloadChannel.values) ...[
            if (channel.index > 0) const SizedBox(width: 12),
            Expanded(
              child: _card(
                channel: channel,
                name: channelInfo[channel]!.name,
                description: channelInfo[channel]!.desc,
                release: channels?[channel],
                available: channels?.containsKey(channel) ?? false,
                selected: selected == channel,
                l10n: l10n,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _card({
    required DownloadChannel channel,
    required String name,
    required String description,
    required ({String tag, String date})? release,
    required bool available,
    required bool selected,
    required AppLocalizations l10n,
  }) {
    final recommended = channel == DownloadChannel.stable;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        key: ValueKey('channel-${channel.name}'),
        onTap: available ? () => onSelected(channel) : null,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? kAccent
                  : recommended && available
                  ? kAccent.withValues(alpha: 0.6)
                  : kOutline,
            ),
            color: selected
                ? kAccent.withValues(alpha: 0.08)
                : recommended && available
                ? kAccent.withValues(alpha: 0.03)
                : available
                ? Colors.transparent
                : kSurfaceLow,
          ),
          child: Opacity(
            opacity: available ? 1.0 : 0.4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: selected ? kAccent : null,
                        ),
                      ),
                    ),
                    if (recommended)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: kAccent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          l10n.channelRecommended,
                          style: const TextStyle(
                            color: kOnAccent,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                ),
                const Spacer(),
                if (release case final info?) ...[
                  Text(
                    info.tag,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade300,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    info.date,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  ),
                ] else
                  Text(
                    l10n.channelNoReleases,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
