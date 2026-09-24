import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

class DbcFlashOutcomes extends StatelessWidget {
  const DbcFlashOutcomes({
    super.key,
    required this.onError,
    required this.onSuccess,
  });

  final VoidCallback onError;
  final VoidCallback? onSuccess;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final error = _card(
          label: l10n.dbcFlashErrorLabel,
          description: l10n.dbcFlashErrorPrompt,
          color: Colors.redAccent,
          onPressed: onError,
          image: Image.asset(
            'assets/images/dbc-flash-error.png',
            height: 210,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
          ),
        );
        final success = _card(
          label: l10n.dbcFlashSuccessLabel,
          description: l10n.dbcFlashSuccessPrompt,
          color: Colors.greenAccent,
          onPressed: onSuccess,
          image: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                flex: 4,
                child: Image.asset(
                  'assets/images/dbc-flash-success-side.png',
                  height: 210,
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Image.asset(
                  'assets/images/dbc-flash-success-front.png',
                  height: 210,
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                ),
              ),
            ],
          ),
        );
        if (constraints.maxWidth < 660) {
          return Column(children: [error, const SizedBox(height: 16), success]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: error),
            const SizedBox(width: 16),
            Expanded(child: success),
          ],
        );
      },
    );
  }

  Widget _card({
    required String label,
    required String description,
    required Color color,
    required VoidCallback? onPressed,
    required Widget image,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 325,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          foregroundColor: color,
          backgroundColor: color.withValues(alpha: 0.06),
          side: BorderSide(color: color.withValues(alpha: 0.65), width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Column(
          children: [
            Expanded(child: Center(child: image)),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 42,
              child: Text(
                description,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
