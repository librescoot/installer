import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/install_time_estimate.dart';
import '../theme.dart';

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
    return (0.50 * elapsedMs / typicalMs).clamp(0.0, 0.50).toDouble();
  }
  return (0.50 + 0.40 * (elapsedMs - typicalMs) / (upperMs - typicalMs))
      .clamp(0.50, 0.90)
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
    final rawTypical = widget.estimate.typical;
    final rawUpper = widget.estimate.conservativeUpper;
    final typical = rawTypical + Duration(seconds: rawTypical.inSeconds ~/ 5);
    final upperPadding = Duration(
      seconds: (rawUpper.inSeconds ~/ 10).clamp(300, 3600),
    );
    final upper = rawUpper + upperPadding;
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
      final high = upper - elapsed;
      timing = low > Duration.zero
          ? l10n.handoffEstimateRemainingRange(
              _minutes(l10n, low),
              _minutes(l10n, high),
            )
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
