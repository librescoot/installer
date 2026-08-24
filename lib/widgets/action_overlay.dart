import 'package:flutter/material.dart';

import '../theme.dart';
import 'overlay_card.dart';

/// An overlay for a wait that ends when a person does something.
///
/// The wait overlay is about the machine: which step is running and how long
/// it usually takes. Neither reads on a screen that is waiting for a hand on
/// the scooter, so this card says what to do, shows that the installer is
/// watching for it, and carries the way out.
class ActionOverlay extends StatelessWidget {
  const ActionOverlay({
    super.key,
    required this.title,
    required this.instruction,
    required this.watching,
    this.icon = Icons.lock_open,
    this.hints = const [],
    this.actions = const [],
  });

  final String title;

  /// What the user has to do.
  final String instruction;

  /// What happens once they have done it.
  final String watching;

  final IconData icon;

  /// The ways to do it, one line each.
  final List<String> hints;

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return OverlayCard(
      title: title,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 28, color: kAccent),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                instruction,
                style: const TextStyle(fontSize: 14, color: kTextPrimary),
              ),
            ),
          ],
        ),
        if (hints.isNotEmpty) ...[
          const SizedBox(height: 14),
          for (final hint in hints)
            Padding(
              padding: const EdgeInsets.only(left: 44, bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6, right: 8),
                    child: SizedBox(
                      width: 4,
                      height: 4,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                            color: kTextMuted, shape: BoxShape.circle),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      hint,
                      style: const TextStyle(fontSize: 13, color: kTextMuted),
                    ),
                  ),
                ],
              ),
            ),
        ],
        const SizedBox(height: 18),
        Row(
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                watching,
                style: const TextStyle(fontSize: 13, color: kTextMuted),
              ),
            ),
          ],
        ),
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                actions[i],
              ],
            ],
          ),
        ],
      ],
    );
  }
}
