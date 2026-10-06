import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/install_time_estimate.dart';

/// USB disconnection is not the start of installation, so no elapsed clock is shown.
class HandoffDuration extends StatelessWidget {
  const HandoffDuration({super.key, required this.estimate});

  final InstallTimeEstimate estimate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    String minutes(Duration duration) => l10n.handoffEstimateMinutes(
      (duration.inSeconds / 60).ceil().clamp(1, 9999),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.handoffEstimateTotalRange(
            minutes(estimate.typical),
            minutes(estimate.conservativeUpper),
          ),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.handoffEstimateBriefDisclaimer,
          style: const TextStyle(fontSize: 13),
        ),
      ],
    );
  }
}
