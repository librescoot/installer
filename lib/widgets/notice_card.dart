import 'package:flutter/material.dart';

/// How loud a notice is. Danger is for the one thing that ruins a scooter.
enum NoticeSeverity { danger, warning, info }

/// A titled notice on the pre-install screen.
///
/// Two are always shown, and two more appear only when downloads fail or a
/// release is missing assets. All four were hand-rolled from the same
/// Container, Row, Icon and Column, drifting in padding, icon size and border
/// weight.
class NoticeCard extends StatelessWidget {
  const NoticeCard({
    super.key,
    required this.severity,
    required this.title,
    this.body,
    this.bullets = const [],
    this.trail,
    this.trailing,
    this.footer,
  });

  final NoticeSeverity severity;
  final String title;
  final String? body;

  /// Rendered as real list items. They used to be newline-joined into [body]
  /// with literal bullet characters, which wrapped as prose and lost the one
  /// property a checklist has: being scannable.
  final List<String> bullets;

  /// Prose after the list, for the sentence that says why the list matters.
  final String? trail;

  /// Sits to the right of the text, for a card that carries an action.
  final Widget? trailing;

  /// Under the text, for a link that belongs to this notice.
  final Widget? footer;

  Color get _colour => switch (severity) {
        NoticeSeverity.danger => Colors.red.shade400,
        NoticeSeverity.warning => Colors.amber,
        NoticeSeverity.info => Colors.grey.shade500,
      };

  IconData get _icon => switch (severity) {
        NoticeSeverity.danger => Icons.dangerous,
        NoticeSeverity.warning => Icons.warning_amber,
        NoticeSeverity.info => Icons.info_outline,
      };

  @override
  Widget build(BuildContext context) {
    final danger = severity == NoticeSeverity.danger;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _colour.withValues(alpha: danger ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _colour.withValues(alpha: danger ? 1 : 0.4),
            width: danger ? 2 : 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_icon, color: _colour, size: danger ? 26 : 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _colour,
                    fontSize: danger ? 15 : 14,
                  ),
                ),
                if (body != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    body!,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: Colors.grey.shade200,
                    ),
                  ),
                ],
                for (final bullet in bullets) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _colour.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          bullet,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: Colors.grey.shade300,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (trail != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    trail!,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: Colors.grey.shade200,
                    ),
                  ),
                ],
                if (footer != null) ...[
                  const SizedBox(height: 8),
                  footer!,
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing!,
          ],
        ],
      ),
    );
  }

  /// Split a body that carries its own bullet list, which is how these strings
  /// are translated: one message per notice, easier to keep coherent than a
  /// key per line.
  static (String?, List<String>, String?) splitBullets(String text) {
    final lead = <String>[];
    final bullets = <String>[];
    final trail = <String>[];
    for (final line in text.split('\n')) {
      final t = line.trim();
      if (t.isEmpty) continue;
      if (t.startsWith('•')) {
        bullets.add(t.substring(1).trim());
      } else if (bullets.isEmpty) {
        lead.add(t);
      } else {
        // After the list, not before it: a closing sentence hoisted above the
        // bullets reads as their introduction.
        trail.add(t);
      }
    }
    return (
      lead.isEmpty ? null : lead.join('\n'),
      bullets,
      trail.isEmpty ? null : trail.join('\n'),
    );
  }
}
