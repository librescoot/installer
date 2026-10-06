import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/install_time_estimate.dart';
import 'dbc_flash_outcomes.dart';
import 'estimated_handoff_progress.dart';

class DashboardHandoffStatus extends StatelessWidget {
  const DashboardHandoffStatus({
    super.key,
    required this.estimate,
    required this.disconnectedAt,
    required this.onError,
    required this.onSuccess,
  });

  final InstallTimeEstimate estimate;
  final DateTime disconnectedAt;
  final VoidCallback onError;
  final VoidCallback? onSuccess;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.amber),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.dbcFlashHandsOffHeading,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(l10n.handoffHandsOffBody, style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 12),
        EstimatedHandoffProgress(estimate: estimate, startedAt: disconnectedAt),
        const SizedBox(height: 12),
        Text(
          l10n.dbcFlashChooseOutcomeHint,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        DbcFlashOutcomes(onError: onError, onSuccess: onSuccess),
      ],
    );
  }
}
