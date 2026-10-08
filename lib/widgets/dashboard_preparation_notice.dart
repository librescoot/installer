import 'package:flutter/material.dart';
import 'package:optimal_wrap_text/optimal_wrap_text.dart';

import '../l10n/app_localizations.dart';
import '../theme.dart';

class DashboardPreparationNotice extends StatelessWidget {
  const DashboardPreparationNotice({super.key, this.error});

  final String? error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OptimalWrapText(
            error == null
                ? l10n.filesStagedWaitingForHandoff
                : l10n.handoffPreparationFailed,
            width: constraints.maxWidth,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: error == null ? kAccent : kDanger,
              fontSize: 13,
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(
              error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: kDanger, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}
