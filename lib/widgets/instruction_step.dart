import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme.dart';

class InstructionStep extends StatelessWidget {
  const InstructionStep({
    super.key,
    required this.number,
    required this.title,
    required this.description,
    this.isWarning = false,
    this.imagePlaceholder,
    this.imageAsset,
    this.beforeImageAsset,
  });

  final int number;
  final String title;
  final String description;
  final bool isWarning;
  final String? imagePlaceholder;
  final String? imageAsset;
  final String? beforeImageAsset;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: isWarning ? Colors.orange.shade700 : Colors.grey.shade800,
        ),
        borderRadius: BorderRadius.circular(8),
        color: isWarning ? Colors.orange.shade900.withValues(alpha: 0.2) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: isWarning ? Colors.orange : kAccent,
            foregroundColor: Colors.black,
            child: Text('$number', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text(description, style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                if (beforeImageAsset != null && imageAsset != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.asset(beforeImageAsset!, height: 240, fit: BoxFit.cover),
                            ),
                            const SizedBox(height: 4),
                            Text(l10n.beforeImageLabel, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.arrow_forward, color: Colors.grey, size: 20),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.asset(imageAsset!, height: 240, fit: BoxFit.cover),
                            ),
                            const SizedBox(height: 4),
                            Text(l10n.afterImageLabel, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ] else if (imageAsset != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.asset(imageAsset!, height: 300, fit: BoxFit.cover),
                  ),
                ] else if (imagePlaceholder != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text(imagePlaceholder!,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
