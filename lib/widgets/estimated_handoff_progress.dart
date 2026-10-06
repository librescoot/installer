import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/install_time_estimate.dart';
import '../theme.dart';

/// Elapsed time is only an estimate: never indicate confirmed completion.
@visibleForTesting
double? estimatedHandoffFraction({
  required Duration elapsed,
  required Duration typical,
  required Duration conservativeUpper,
  required bool indeterminate,
}) {
  if (indeterminate || typical <= Duration.zero) return null;
  final elapsedMs = elapsed.inMilliseconds.clamp(
    0,
    conservativeUpper.inMilliseconds,
  );
  final typicalMs = typical.inMilliseconds;
  final upperMs = conservativeUpper.inMilliseconds;
  if (elapsedMs >= upperMs) return null;
  if (elapsedMs <= typicalMs || upperMs <= typicalMs) {
    return (elapsedMs / typicalMs).clamp(0.0, 0.90).toDouble();
  }
  return (0.90 + 0.07 * (elapsedMs - typicalMs) / (upperMs - typicalMs))
      .clamp(0.90, 0.97)
      .toDouble();
}

class EstimatedHandoffProgress extends StatefulWidget {
  const EstimatedHandoffProgress({
    super.key,
    required this.estimate,
    required this.startedAt,
    this.now,
  });

  final InstallTimeEstimate estimate;
  final DateTime startedAt;
  final DateTime Function()? now;

  @override
  State<EstimatedHandoffProgress> createState() =>
      _EstimatedHandoffProgressState();
}

class _EstimatedHandoffProgressState extends State<EstimatedHandoffProgress> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _minutes(AppLocalizations l10n, Duration duration) => l10n
      .handoffEstimateMinutes((duration.inSeconds / 60).ceil().clamp(1, 9999));

  String _clock(Duration duration) {
    final seconds = duration.inSeconds.clamp(0, 359999);
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final elapsed = (widget.now ?? DateTime.now)().difference(widget.startedAt);
    final typical = widget.estimate.typical;
    final upper = widget.estimate.conservativeUpper;
    final overdue = upper > Duration.zero && elapsed >= upper;
    final progress = estimatedHandoffFraction(
      elapsed: elapsed,
      typical: typical,
      conservativeUpper: upper,
      indeterminate: widget.estimate.isIndeterminate,
    );
    final String timing;
    if (overdue) {
      timing = l10n.handoffEstimateTakingLonger;
    } else if (widget.estimate.isIndeterminate) {
      timing = l10n.handoffEstimateTotalRange(
        _minutes(l10n, typical),
        _minutes(l10n, upper),
      );
    } else {
      final low = typical - elapsed;
      timing = low > Duration.zero
          ? l10n.handoffEstimateRemaining(_minutes(l10n, low))
          : l10n.handoffEstimateRemainingUpper(_minutes(l10n, upper - elapsed));
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kAccent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.handoffEstimateBriefDisclaimer,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            borderRadius: BorderRadius.circular(5),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  timing,
                  style: TextStyle(
                    fontSize: 13,
                    color: overdue ? Colors.orange.shade200 : kTextMuted,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                l10n.handoffElapsed(_clock(elapsed)),
                style: const TextStyle(
                  fontSize: 13,
                  color: kTextMuted,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
