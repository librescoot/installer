import 'package:flutter/material.dart';

import '../models/substep.dart';
import '../theme.dart';

class SubstepList extends StatelessWidget {
  const SubstepList({
    super.key,
    required this.substeps,
    this.compact = false,
  });

  final List<Substep> substeps;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: substeps.map((s) => _SubstepRow(substep: s, compact: compact)).toList(),
    );
  }
}

class _SubstepRow extends StatelessWidget {
  const _SubstepRow({required this.substep, required this.compact});

  final Substep substep;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (substep.state) {
      SubstepState.done => (
          const Icon(Icons.check_circle, size: 16, color: kAccent),
          Colors.grey.shade500,
        ),
      SubstepState.active => (
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          Colors.white,
        ),
      SubstepState.failed => (
          Icon(Icons.error_outline, size: 16, color: Colors.red.shade300),
          Colors.red.shade200,
        ),
      SubstepState.pending => (
          Icon(Icons.radio_button_unchecked, size: 14, color: Colors.grey.shade700),
          Colors.grey.shade600,
        ),
    };
    final fontWeight = substep.state == SubstepState.active ? FontWeight.w600 : FontWeight.normal;
    final padY = compact ? 2.0 : 4.0;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: padY),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 20, height: 20, child: Center(child: icon)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  substep.label,
                  style: TextStyle(
                    color: color,
                    fontSize: compact ? 12 : 13,
                    fontWeight: fontWeight,
                  ),
                ),
                if (substep.detail != null && substep.state == SubstepState.active)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      substep.detail!,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: compact ? 11 : 12,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
