import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../models/download_state.dart';
import '../theme.dart';

class FirmwareChannelSelector extends StatefulWidget {
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
  State<FirmwareChannelSelector> createState() =>
      _FirmwareChannelSelectorState();
}

class _FirmwareChannelSelectorState extends State<FirmwareChannelSelector> {
  static const _nightlyAcknowledgementKey =
      'installer.nightly-risk-acknowledged.v1';
  bool _selectingNightly = false;

  Future<void> _selectChannel(DownloadChannel channel) async {
    if (channel == widget.selected || _selectingNightly) return;
    if (channel != DownloadChannel.nightly) {
      widget.onSelected(channel);
      return;
    }

    _selectingNightly = true;
    try {
      SharedPreferences? preferences;
      try {
        preferences = await SharedPreferences.getInstance();
      } catch (error) {
        debugPrint('Could not read installer preferences: $error');
      }
      if (!mounted || channel == widget.selected) return;
      if (preferences?.getBool(_nightlyAcknowledgementKey) != true) {
        final l10n = AppLocalizations.of(context)!;
        final accepted = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: Text(l10n.nightlyWarningTitle),
            content: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: l10n.nightlyWarningLead,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: '\n\n${l10n.nightlyWarningBody}'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(l10n.nightlyWarningCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(l10n.nightlyWarningAccept),
              ),
            ],
          ),
        );
        if (!mounted || accepted != true) return;
        if (preferences != null) {
          try {
            await preferences.setBool(_nightlyAcknowledgementKey, true);
          } catch (error) {
            debugPrint('Could not save Nightly acknowledgement: $error');
          }
        }
      }
      if (mounted) widget.onSelected(channel);
    } finally {
      _selectingNightly = false;
    }
  }

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
                release: widget.channels?[channel],
                available: widget.channels?.containsKey(channel) ?? false,
                selected: widget.selected == channel,
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
        onTap: available ? () => _selectChannel(channel) : null,
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
