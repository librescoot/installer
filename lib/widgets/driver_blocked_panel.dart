import 'package:flutter/material.dart';

import 'phase_layout.dart';

/// The screen a Windows user lands on when the scooter's USB port is held by
/// something other than the network driver.
///
/// Carries the diagnosis rather than a connection error: which package took
/// the port, how to get it back, and a copyable block for a bug report. The
/// alternative this replaced was a generic SSH failure and a retry button
/// that re-ran the identical doomed sequence.
class DriverBlockedPanel extends StatelessWidget with OwnsPhaseLayout {
  const DriverBlockedPanel({
    super.key,
    required this.title,
    required this.body,
    required this.detailsLabel,
    required this.details,
    this.actions = const [],
  });

  final String title;
  final String body;

  /// Heading above the diagnostic block.
  final String detailsLabel;

  /// Device id, competing packages and the command to reproduce the finding.
  /// Untranslated on purpose: it gets pasted verbatim to someone who may not
  /// read the reporter's language. Empty hides the block.
  final String details;

  final List<PhaseAction> actions;

  @override
  Widget build(BuildContext context) {
    return PhaseLayout(
      title: title,
      actions: actions,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            body,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Colors.grey.shade300,
            ),
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              detailsLabel,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white10),
              ),
              // Selectable so the details can be dragged out even where the
              // copy button cannot reach a clipboard.
              child: SelectableText(
                details,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  height: 1.4,
                  color: Colors.grey.shade400,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
