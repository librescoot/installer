import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

class DashboardHandoffSignalGuide extends StatelessWidget {
  const DashboardHandoffSignalGuide({super.key});

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
            );
            final installing = _SignalStateCard(
              title: l10n.handoffDbcRecognized,
              description: l10n.handoffInstallingSignals,
              waiting: false,
            );
            if (constraints.maxWidth < 620) {
              return Column(
                children: [waiting, const SizedBox(height: 12), installing],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: waiting),
                const SizedBox(width: 12),
                Expanded(child: installing),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.12),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.55)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            l10n.handoffContinueWhenReady,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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
  });

  final String title;
  final String description;
  final bool waiting;

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
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Center(child: _DashboardLed(waiting: waiting)),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 108,
                  width: 57,
                  child: _ScooterRing(waiting: waiting),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardLed extends StatefulWidget {
  const _DashboardLed({required this.waiting});

  final bool waiting;

  @override
  State<_DashboardLed> createState() => _DashboardLedState();
}

class _DashboardLedState extends State<_DashboardLed>
    with SingleTickerProviderStateMixin {
  static const _sourceWidth = 2467.0;
  static const _sourceHeight = 2136.0;
  static const _ledCenter = Offset(2260, 1007);
  static const _imageHeight = 150.0;
  static const _imageWidth = _imageHeight * _sourceWidth / _sourceHeight;
  static const _ledDiameter = 14.0;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat();

  late final Animation<double> _brightness = TweenSequence<double>([
    TweenSequenceItem(tween: ConstantTween<double>(0), weight: 20),
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
    TweenSequenceItem(tween: ConstantTween<double>(1), weight: 30),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 15),
    TweenSequenceItem(tween: ConstantTween<double>(0), weight: 20),
  ]).animate(_pulse);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = _imageHeight / _sourceHeight;
    return SizedBox(
      width: _imageWidth,
      height: _imageHeight,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              key: const Key('handoff-dashboard-full-dbc-asset'),
              'assets/images/dbc-flash-error-off.png',
              fit: BoxFit.fill,
              excludeFromSemantics: true,
            ),
          ),
          Positioned(
            left: _ledCenter.dx * scale - _ledDiameter / 2,
            top: _ledCenter.dy * scale - _ledDiameter / 2,
            child: AnimatedBuilder(
              animation: _brightness,
              builder: (context, child) {
                final level = widget.waiting ? _brightness.value : 1.0;
                final amber = const Color(0xFFFFB300).withValues(alpha: level);
                return Container(
                  key: const Key('handoff-dashboard-amber-led'),
                  width: _ledDiameter,
                  height: _ledDiameter,
                  decoration: BoxDecoration(
                    color: amber,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: amber.withValues(alpha: level * 0.85),
                        blurRadius: 12,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
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
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(off, fit: BoxFit.contain, excludeFromSemantics: true),
        if (widget.waiting)
          FadeTransition(
            key: const Key('handoff-scooter-ring-pulse'),
            opacity: _lit ?? const AlwaysStoppedAnimation<double>(0),
            child: Image.asset(
              lit,
              fit: BoxFit.contain,
              excludeFromSemantics: true,
            ),
          ),
      ],
    );
  }
}
