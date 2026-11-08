import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

class CompletionCueSettings extends StatelessWidget {
  const CompletionCueSettings({
    super.key,
    required this.soundEnabled,
    required this.onChanged,
  });

  final bool soundEnabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.completionCueHeading,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Text(l10n.completionCueVisualDescription),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: soundEnabled,
          onChanged: (value) => onChanged(value ?? false),
          title: Text(l10n.completionCueSoundLabel),
          subtitle: Text(l10n.completionCueSoundDescription),
        ),
      ],
    );
  }
}
