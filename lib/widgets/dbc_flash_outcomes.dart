import 'package:flutter/material.dart';

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
    return LayoutBuilder(
      builder: (context, constraints) {
        final error = _card(
          label: 'ERROR',
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
          label: 'SUCCESS',
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
    required Color color,
    required VoidCallback? onPressed,
    required Widget image,
  }) {
    return SizedBox(
      width: double.infinity,
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
            SizedBox(height: 210, child: Center(child: image)),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
