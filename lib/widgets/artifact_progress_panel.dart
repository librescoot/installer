import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Body of the artifact install phase: a progress bar while it runs, and
/// mender's own stderr when it fails. The ways out live in the phase's action
/// bar, where every other phase keeps them.
class ArtifactProgressPanel extends StatelessWidget {
  const ArtifactProgressPanel({
    super.key,
    required this.status,
    required this.progress,
    required this.error,
  });

  final String status;
  final double progress;

  /// mender's stderr, verbatim. Null while things are going well.
  final String? error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(status, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        if (error == null)
          LinearProgressIndicator(
              value: progress > 0 ? progress : null, minHeight: 6),
        if (error != null) ...[
          Text(l10n.artifactInstallFailedHeading,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SelectableText(error!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }
}
