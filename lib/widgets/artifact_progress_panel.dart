import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Body of the artifact install phase: a progress bar while it runs, and
/// mender's own stderr plus the two ways out when it fails.
class ArtifactProgressPanel extends StatelessWidget {
  const ArtifactProgressPanel({
    super.key,
    required this.status,
    required this.progress,
    required this.error,
    required this.onRetry,
    required this.onFallBackToFullImage,
  });

  final String status;
  final double progress;

  /// mender's stderr, verbatim. Null while things are going well.
  final String? error;
  final VoidCallback onRetry;
  final VoidCallback onFallBackToFullImage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
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
              SelectableText(error!,
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: Text(l10n.artifactRetry)),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: onFallBackToFullImage,
                child: Text(l10n.artifactFallBackToFullImage),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
