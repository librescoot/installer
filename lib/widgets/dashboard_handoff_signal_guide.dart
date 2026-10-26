import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'dbc_led_image.dart';

class DashboardHandoffSignalGuide extends StatelessWidget {
  const DashboardHandoffSignalGuide({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final waiting = _SignalStateCard(
              title: l10n.handoffWaitingForDbc,
              description: l10n.handoffWaitingSignals,
              waiting: true,
              compact: compact,
            );
            final installing = _SignalStateCard(
              title: l10n.handoffDbcRecognized,
              description: l10n.handoffInstallingSignals,
              waiting: false,
              compact: compact,
            );
            if (constraints.maxWidth < 620) {
              return Column(
                children: [
                  waiting,
                  SizedBox(height: compact ? 8 : 12),
                  installing,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: waiting),
                SizedBox(width: compact ? 8 : 12),
                Expanded(child: installing),
              ],
            );
          },
        ),
        SizedBox(height: compact ? 8 : 12),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: compact ? 8 : 10,
          ),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.12),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.55)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            l10n.handoffContinueWhenReady,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: compact ? 14 : 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _SignalStateCard extends StatelessWidget {
  const _SignalStateCard({
    required this.title,
    required this.description,
    required this.waiting,
    required this.compact,
  });

  final String title;
  final String description;
  final bool waiting;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.28),
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 8 : 10),
        child: Column(
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: compact ? 15 : 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: compact ? 6 : 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: compact ? 72 : 104,
                  child: DbcLedImage(
                    color: const Color(0xFFFFB300),
                    pulsing: waiting,
                    indicatorKey: const Key('handoff-dashboard-amber-led'),
                    assetKey: const Key('handoff-dashboard-full-dbc-asset'),
                  ),
                ),
                SizedBox(width: compact ? 8 : 10),
                SizedBox(
                  height: compact ? 90 : 128,
                  width: compact ? 124 : 176,
                  child: _ScooterRing(waiting: waiting),
                ),
              ],
            ),
            SizedBox(height: compact ? 6 : 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: compact ? 11 : 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScooterRing extends StatefulWidget {
  const _ScooterRing({required this.waiting});

  final bool waiting;

  @override
  State<_ScooterRing> createState() => _ScooterRingState();
}

class _ScooterRingState extends State<_ScooterRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController? _cycle = widget.waiting
      ? (AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 2750),
        )..repeat())
      : null;

  late final Animation<double>? _lit = _cycle == null
      ? null
      : TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 500),
          TweenSequenceItem(tween: ConstantTween<double>(1), weight: 1500),
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 250),
          TweenSequenceItem(tween: ConstantTween<double>(0), weight: 500),
        ]).animate(_cycle);

  @override
  void dispose() {
    _cycle?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const off = 'assets/images/dbc-flash-success-front-off.png';
    const lit = 'assets/images/dbc-flash-success-front.png';
    const ringFocus = Alignment(0, -0.33);
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          off,
          fit: BoxFit.cover,
          alignment: ringFocus,
          excludeFromSemantics: true,
        ),
        if (widget.waiting)
          FadeTransition(
            key: const Key('handoff-scooter-ring-pulse'),
            opacity: _lit ?? const AlwaysStoppedAnimation<double>(0),
            child: Image.asset(
              lit,
              fit: BoxFit.cover,
              alignment: ringFocus,
              excludeFromSemantics: true,
            ),
          ),
      ],
    );
  }
}
