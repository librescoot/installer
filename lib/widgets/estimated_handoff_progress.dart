import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/install_time_estimate.dart';
import '../theme.dart';

/// The bar tracks the calibrated estimate directly: elapsed over typical,
/// capped at 90%, with the typical-to-upper stretch creeping to 97%. It has
/// to agree with the countdown next to it; a bar visibly behind its own
/// "remaining" text reads as a stall. Never full: the vehicle cannot confirm
/// completion from here, so the last stretch belongs to the scooter's own
/// signals, and past the upper bound the bar goes indeterminate.
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

  DateTime get _now => (widget.now ?? DateTime.now)();

  String _elapsed(Duration duration) {
    final seconds = duration.inSeconds.clamp(0, 359999);
    final minutes = seconds ~/ 60;
    return '$minutes:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  String _minutes(AppLocalizations l10n, Duration duration) {
    final minutes = (duration.inSeconds / 60).ceil().clamp(1, 9999);
    return l10n.handoffEstimateMinutes(minutes);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final elapsed = _now.difference(widget.startedAt);
    // The stage durations are calibrated from measured runs, so the estimate
    // is presented as-is with a small pad rather than widened into a range
    // nobody can plan around.
    final rawTypical = widget.estimate.typical;
    final rawUpper = widget.estimate.conservativeUpper;
    final typical =
        rawTypical + Duration(seconds: (rawTypical.inSeconds * 0.05).ceil());
    final upper =
        rawUpper + Duration(seconds: (rawUpper.inSeconds * 0.05).ceil());
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
      // An asset without a final size cannot be estimated tightly; the broad
      // range is the honest statement here.
      timing = l10n.handoffEstimateTotalRange(
        _minutes(l10n, typical),
        _minutes(l10n, upper),
      );
    } else {
      final low = typical - elapsed;
      final high = upper - elapsed;
      timing = low > Duration.zero
          ? l10n.handoffEstimateRemaining(_minutes(l10n, low))
          : l10n.handoffEstimateRemainingUpper(_minutes(l10n, high));
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kAccent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.handoffEstimateTitle,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.handoffEstimateExplanation,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.35,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  timing,
                  style: TextStyle(
                    fontSize: 12,
                    color: overdue ? Colors.orange.shade200 : kTextMuted,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                l10n.waitElapsed(_elapsed(elapsed)),
                style: const TextStyle(
                  fontSize: 12,
                  color: kTextMuted,
                  fontFamily: 'Inter',
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
