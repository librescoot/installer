import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'notice_card.dart';
import 'phase_layout.dart';

/// The screen the connect phase lands on when it cannot reach the main board.
///
/// It leads with the diagnosis, follows with the things worth checking for
/// that diagnosis, and folds the exception away underneath, where it stays one
/// click from the clipboard because that is what ends up in Discord. The
/// alternative is the caught exception on its own, which is the same answer
/// for a cable in the wrong socket, a board that is still booting, and a macOS
/// permission dialog nobody answered.
class ConnectFailurePanel extends StatelessWidget with OwnsPhaseLayout {
  const ConnectFailurePanel({
    super.key,
    required this.title,
    required this.body,
    required this.checklistTitle,
    required this.detailsLabel,
    required this.details,
    required this.copyLabel,
    this.askForHelpLabel,
    this.onAskForHelp,
    this.actions = const [],
  });

  /// The diagnosis. It is the phase title, because it is the one thing on the
  /// screen the user has to read.
  final String title;

  /// One message per failure, carrying its own bullet list the way the
  /// pre-install notices do: easier to keep coherent across two languages
  /// than a key per line.
  final String body;

  /// Heading for the card the bullets go in.
  final String checklistTitle;

  /// Heading on the disclosure that hides [details].
  final String detailsLabel;

  /// The exception and its context. Untranslated on purpose: it gets pasted
  /// verbatim to someone who may not read the reporter's language.
  final String details;

  final String copyLabel;

  final String? askForHelpLabel;
  final VoidCallback? onAskForHelp;

  final List<PhaseAction> actions;

  @override
  Widget build(BuildContext context) {
    // Bodies that carry no bullets are prose with blank lines between the
    // paragraphs, and splitting them would eat the blank lines and run the
    // paragraphs together.
    final hasBullets = body.contains('•');
    final (lead, bullets, trail) = hasBullets
        ? NoticeCard.splitBullets(body)
        : (body, const <String>[], null);
    final prose = TextStyle(
      fontSize: 14,
      height: 1.5,
      color: Colors.grey.shade300,
    );

    return PhaseLayout(
      title: title,
      actions: actions,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (lead != null) Text(lead, style: prose),
          if (bullets.isNotEmpty) ...[
            const SizedBox(height: 18),
            NoticeCard(
              severity: NoticeSeverity.warning,
              title: checklistTitle,
              bullets: bullets,
              trail: trail,
            ),
          ] else if (trail != null) ...[
            const SizedBox(height: 12),
            Text(trail, style: prose),
          ],
          if (details.isNotEmpty) ...[
            const SizedBox(height: 22),
            _TechnicalDetails(
              label: detailsLabel,
              details: details,
              copyLabel: copyLabel,
              askForHelpLabel: askForHelpLabel,
              onAskForHelp: onAskForHelp,
            ),
          ],
        ],
      ),
    );
  }
}

/// The exception, folded away.
///
/// Open by default it is the loudest thing on a screen whose job is to say
/// what to do next, and shown to someone who cannot act on it. Removed
/// entirely it takes the only evidence a bug report has with it.
class _TechnicalDetails extends StatefulWidget {
  const _TechnicalDetails({
    required this.label,
    required this.details,
    required this.copyLabel,
    this.askForHelpLabel,
    this.onAskForHelp,
  });

  final String label;
  final String details;
  final String copyLabel;
  final String? askForHelpLabel;
  final VoidCallback? onAskForHelp;

  @override
  State<_TechnicalDetails> createState() => _TechnicalDetailsState();
}

class _TechnicalDetailsState extends State<_TechnicalDetails> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final askLabel = widget.askForHelpLabel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _open ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 6),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_open) ...[
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white10),
            ),
            // Selectable so the block can be dragged out even where the copy
            // button cannot reach a clipboard.
            child: SelectableText(
              widget.details,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                height: 1.4,
                color: Colors.grey.shade400,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => Clipboard.setData(
                  ClipboardData(text: widget.details),
                ),
                icon: const Icon(Icons.copy, size: 16),
                label: Text(widget.copyLabel),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
              if (askLabel != null && widget.onAskForHelp != null)
                OutlinedButton.icon(
                  onPressed: widget.onAskForHelp,
                  icon: const Icon(Icons.chat_bubble_outline, size: 16),
                  label: Text(askLabel),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
