import 'package:flutter/material.dart';

import '../theme.dart';

/// A wait: the screen the user just left, dimmed and inert, with the wait
/// overlay over it.
///
/// It is its own type so the phase host can tell it apart from ordinary
/// content. Ordinary content goes into a scroll view, which would hand this
/// an unbounded height and leave the card pinned to the top corner with the
/// veil painted only behind itself.
class WaitScaffold extends StatelessWidget {
  const WaitScaffold({super.key, required this.overlay, this.backdrop});

  /// The card. Sized by its own content.
  final Widget overlay;

  /// The last screen that had something to show. Null on the rare wait that
  /// is the first thing the user sees.
  final Widget? backdrop;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (backdrop != null)
          IgnorePointer(child: ExcludeSemantics(child: backdrop!)),
        // Enough to push the frozen screen back without hiding it: the point
        // is that the user still recognises where they are.
        Container(color: kBgPrimary.withValues(alpha: 0.78)),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(child: overlay),
          ),
        ),
      ],
    );
  }
}
