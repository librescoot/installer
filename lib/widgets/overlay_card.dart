import 'package:flutter/material.dart';

import '../theme.dart';

/// The card an overlay draws on the dimmed screen behind it.
///
/// Shared so that a wait and a request for a physical action arrive as the
/// same object in the same place, and differ only in what they say.
class OverlayCard extends StatelessWidget {
  const OverlayCard({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 560),
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kOutline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: kAccent),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}
