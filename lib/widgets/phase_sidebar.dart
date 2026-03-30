import 'package:flutter/material.dart';
import '../models/installer_phase.dart';

class PhaseSidebar extends StatelessWidget {
  const PhaseSidebar({
    super.key,
    required this.currentPhase,
    required this.completedPhases,
  });

  final InstallerPhase currentPhase;
  final Set<InstallerPhase> completedPhases;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: const Color(0xFF1A1A2E),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'LibreScoot Installer',
              style: TextStyle(
                color: Colors.tealAccent,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (final phase in InstallerPhase.values)
            _PhaseItem(
              phase: phase,
              isCurrent: phase == currentPhase,
              isCompleted: completedPhases.contains(phase),
              isPast: phase.index < currentPhase.index,
            ),
        ],
      ),
    );
  }
}

class _PhaseItem extends StatelessWidget {
  const _PhaseItem({
    required this.phase,
    required this.isCurrent,
    required this.isCompleted,
    required this.isPast,
  });

  final InstallerPhase phase;
  final bool isCurrent;
  final bool isCompleted;
  final bool isPast;

  @override
  Widget build(BuildContext context) {
    final Color textColor;
    final Widget leading;

    if (isCompleted || isPast) {
      textColor = Colors.grey;
      leading = const Icon(Icons.check, size: 16, color: Colors.grey);
    } else if (isCurrent) {
      textColor = Colors.tealAccent;
      leading = const Icon(Icons.circle, size: 12, color: Colors.tealAccent);
    } else {
      textColor = Colors.grey.shade700;
      leading = Icon(Icons.circle_outlined, size: 12, color: Colors.grey.shade700);
    }

    return Container(
      color: isCurrent ? Colors.tealAccent.withValues(alpha: 0.08) : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 24, child: Center(child: leading)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              phase.title,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
