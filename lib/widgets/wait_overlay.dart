import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/wait_plan.dart';
import '../theme.dart';

/// The card shown while the installer is waiting on the scooter.
///
/// It replaces a phase whose whole content was a spinner and one status line
/// in an otherwise empty window. What it adds is expectation: the steps of
/// this phase, how long each usually takes, which one is running, and how
/// long it has been running. The log underneath is for the case the numbers
/// stop being reassuring.
class WaitOverlay extends StatefulWidget {
  const WaitOverlay({
    super.key,
    required this.title,
    required this.steps,
    required this.currentStep,
    required this.startedAt,
    this.stepStartedAt,
    this.progress,
    this.warning,
    this.logTail = const [],
    this.actions = const [],
    this.now,
  });

  final String title;
  final List<WaitStep> steps;

  /// Index into [steps]. Everything before it is done, everything after is
  /// still to come.
  final int currentStep;

  /// When the phase started, for the total elapsed readout.
  final DateTime startedAt;

  /// When the current step started, for the overdue mark. Falls back to the
  /// phase start, which is right for a single-step phase.
  final DateTime? stepStartedAt;

  /// Fraction for the active step where the work reports one. Null draws an
  /// indeterminate bar, which is honest for a step that cannot count.
  final double? progress;

  final String? warning;

  /// Last lines of whatever the phase is doing, behind a disclosure.
  final List<String> logTail;

  /// Anything the user can do while this runs. Usually empty.
  final List<Widget> actions;

  /// Injectable clock for tests.
  final DateTime Function()? now;

  @override
  State<WaitOverlay> createState() => _WaitOverlayState();
}

class _WaitOverlayState extends State<WaitOverlay> {
  Timer? _tick;
  bool _logOpen = false;

  @override
  void initState() {
    super.initState();
    // Only to redraw the two clocks; the work reports itself through the
    // widget's own fields.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  DateTime get _now => (widget.now ?? DateTime.now)();

  static String formatDuration(Duration d) {
    final s = d.inSeconds.abs();
    final m = s ~/ 60;
    return '$m:${(s % 60).toString().padLeft(2, '0')}';
  }

  /// "~2 min" for the long ones, "~40 s" for the short: a step that usually
  /// takes forty seconds should not be advertised as "~1 min".
  static String formatTypical(Duration d) =>
      d.inSeconds >= 90 ? '~${(d.inSeconds / 60).round()} min' : '~${d.inSeconds} s';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final now = _now;
    final total = now.difference(widget.startedAt);
    final stepElapsed = now.difference(widget.stepStartedAt ?? widget.startedAt);
    final active = widget.steps.isEmpty
        ? null
        : widget.steps[widget.currentStep.clamp(0, widget.steps.length - 1)];
    final overdue =
        active != null && waitStepIsOverdue(stepElapsed, active.typical);

    return Container(
      constraints: const BoxConstraints(maxWidth: 560),
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
      decoration: BoxDecoration(
        color: kBgSidebar,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
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
          Text(widget.title,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: kAccent)),
          const SizedBox(height: 16),
          // A phase can render before its work has said what its steps are:
          // the builder runs on the frame the work is scheduled, not after
          // it. One line and a bar until then, rather than an exception.
          if (widget.steps.isEmpty) ...[
            LinearProgressIndicator(
              value: widget.progress,
              minHeight: 4,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
            ),
            const SizedBox(height: 14),
          ],
          for (var i = 0; i < widget.steps.length; i++)
            _stepRow(
              step: widget.steps[i],
              state: i < widget.currentStep
                  ? WaitStepState.done
                  : i == widget.currentStep
                      ? WaitStepState.active
                      : WaitStepState.todo,
              elapsed: stepElapsed,
              overdue: overdue,
              l10n: l10n,
            ),
          const SizedBox(height: 14),
          if (widget.steps.isNotEmpty)
          Row(
            children: [
              Text(
                l10n.waitStepCounter(
                    (widget.currentStep + 1).clamp(1, widget.steps.length),
                    widget.steps.length),
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontFamily: 'monospace'),
              ),
              const Spacer(),
              Text(
                l10n.waitElapsed(formatDuration(total)),
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontFamily: 'monospace'),
              ),
            ],
          ),
          if (widget.warning != null) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.power_off, size: 16, color: Colors.orange.shade300),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(widget.warning!,
                      style: TextStyle(
                          fontSize: 13, color: Colors.orange.shade200)),
                ),
              ],
            ),
          ],
          if (widget.logTail.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
            InkWell(
              onTap: () => setState(() => _logOpen = !_logOpen),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Icon(_logOpen ? Icons.expand_less : Icons.expand_more,
                        size: 18, color: kAccent),
                    const SizedBox(width: 6),
                    Text(_logOpen ? l10n.waitHideLog : l10n.waitShowLog,
                        style: const TextStyle(fontSize: 13, color: kAccent)),
                  ],
                ),
              ),
            ),
            if (_logOpen)
              Container(
                constraints: const BoxConstraints(maxHeight: 132),
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E1214),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: SingleChildScrollView(
                  reverse: true,
                  child: Text(
                    widget.logTail.join('\n'),
                    style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        height: 1.4,
                        color: Colors.grey.shade400),
                  ),
                ),
              ),
          ],
          if (widget.actions.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                for (final a in widget.actions) ...[
                  const SizedBox(width: 8),
                  a,
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _stepRow({
    required WaitStep step,
    required WaitStepState state,
    required Duration elapsed,
    required bool overdue,
    required AppLocalizations l10n,
  }) {
    final Color colour = switch (state) {
      WaitStepState.done => Colors.grey.shade500,
      WaitStepState.active => Colors.white,
      WaitStepState.todo => Colors.grey.shade600,
    };
    final Widget marker = switch (state) {
      WaitStepState.done =>
        const Icon(Icons.check_circle, size: 14, color: kAccent),
      WaitStepState.active => Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
                color: overdue ? Colors.orange.shade300 : kAccent, width: 2),
          ),
        ),
      WaitStepState.todo => Icon(Icons.circle_outlined,
          size: 12, color: Colors.grey.shade700),
    };

    final String timing = switch (state) {
      WaitStepState.done => '',
      WaitStepState.active => overdue
          ? l10n.waitLongerThanUsual(_WaitOverlayState.formatDuration(elapsed))
          : '${_WaitOverlayState.formatDuration(elapsed)} / '
              '${_WaitOverlayState.formatTypical(step.typical)}',
      WaitStepState.todo => _WaitOverlayState.formatTypical(step.typical),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(width: 16, child: Center(child: marker)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(step.label,
                    style: TextStyle(fontSize: 14, color: colour)),
              ),
              const SizedBox(width: 10),
              Text(timing,
                  style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: overdue && state == WaitStepState.active
                          ? Colors.orange.shade300
                          : Colors.grey.shade500)),
            ],
          ),
          if (state == WaitStepState.active) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: LinearProgressIndicator(
                value: widget.progress,
                minHeight: 4,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
