import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// The brake-lever restart gesture: hold both levers for forty seconds, let
/// go of the right one for about a second at each ten second mark, and release
/// after the last stretch. This is the wording the vehicle's own maker
/// published for it.
///
/// The nRF52 watches the brake line itself, so this works with the main
/// processor stopped in the bootloader, which is exactly when the installer
/// needs a restart and exactly when nothing else can reach the vehicle. It
/// needs no tools, no seatbox and no cable.
///
/// The firmware behind it watches one debounced brake line rather than two,
/// so what the left lever contributes is a property of the harness and not of
/// the code. The holds have a window either side of them and the release has
/// to be brief, so a hold that runs long or a release that drags restarts the
/// count from nothing. Ten seconds sits in the middle of every hold window,
/// which is what makes one paced number workable for all four.
/// The blips land ON the ten second marks and count toward the forty, rather
/// than pausing the clock: the whole gesture is forty seconds, not forty plus
/// three. So the opening stretch is a full ten and the three after it are one
/// second short, each ending on its own mark.
const brakeMarkSeconds = 10;
const brakeBlipSeconds = 1;
const brakeSegments = 4;
const brakeTotalSeconds = brakeMarkSeconds * brakeSegments;

/// The firmware measures each squeeze from its own press rather than against a
/// clock spanning the whole gesture, and its window is wide enough that both
/// nine and ten sit comfortably inside it.
int brakeHoldSecondsFor(int segment) =>
    segment == 1 ? brakeMarkSeconds : brakeMarkSeconds - brakeBlipSeconds;

/// Long enough to step from the laptop to the handlebars and get a hand on
/// each lever. Without it the count starts when the button is pressed, which
/// is a different moment from when the squeeze starts, and every beat after
/// that inherits the gap.
const brakeLeadInSeconds = 5;

/// The pattern at a glance: one long squeeze of both levers, with the right
/// one blipped at each ten second mark. Drawn to scale, so the eye takes in
/// "hold throughout, three brief interruptions" before reading a word.
class BrakeGestureDiagram extends StatelessWidget {
  const BrakeGestureDiagram({
    super.key,
    this.activeSegment,
    this.blipping = false,
    this.finished = false,
  });

  /// 1-based ten second segment to highlight, or null for the inert diagram.
  final int? activeSegment;

  /// Highlight the blip at the end of [activeSegment] rather than the hold.
  final bool blipping;

  /// Draw the closing "let go of both" marker as reached.
  final bool finished;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final row = <Widget>[];
    for (var segment = 1; segment <= brakeSegments; segment++) {
      final isHold = activeSegment == segment && !blipping;
      row.add(Expanded(
        flex: brakeHoldSecondsFor(segment),
        child: _Block(
          label: '${segment * brakeMarkSeconds}s',
          color: isHold ? Colors.cyanAccent : Colors.cyan.shade900,
          textColor: isHold ? Colors.black : Colors.cyan.shade100,
          emphasised: isHold,
        ),
      ));
      // No blip after the last segment: that one ends by letting go of both.
      if (segment < brakeSegments) {
        final isBlip = activeSegment == segment && blipping;
        row.add(Expanded(
          flex: brakeBlipSeconds,
          child: _Block(
            label: '',
            color: isBlip ? Colors.orangeAccent : Colors.orange.shade900,
            textColor: Colors.transparent,
            emphasised: isBlip,
          ),
        ));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The band above the timeline is the part people get wrong: the left
        // lever never moves, so it is drawn as one unbroken run.
        Container(
          height: 22,
          decoration: BoxDecoration(
            color: Colors.cyan.shade900.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          child: Text(l10n.brakeBandBothHeld,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.cyan.shade100)),
        ),
        const SizedBox(height: 3),
        SizedBox(height: 40, child: Row(children: row)),
        const SizedBox(height: 6),
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                  color: Colors.orange.shade900,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(l10n.brakeDiagramBlipLegend,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Icon(Icons.flag_outlined,
                size: 12,
                color: finished ? Colors.greenAccent : Colors.grey.shade500),
            const SizedBox(width: 4),
            Expanded(
              child: Text(l10n.brakeDiagramEndLegend(brakeTotalSeconds),
                  style: TextStyle(
                      fontSize: 11,
                      color: finished
                          ? Colors.greenAccent
                          : Colors.grey.shade400)),
            ),
          ],
        ),
      ],
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({
    required this.label,
    required this.color,
    required this.textColor,
    required this.emphasised,
  });

  final String label;
  final Color color;
  final Color textColor;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
        border: emphasised ? Border.all(color: Colors.white, width: 2) : null,
      ),
      alignment: Alignment.bottomCenter,
      padding: const EdgeInsets.only(bottom: 3),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.bold, color: textColor)),
    );
  }
}

/// Paces the gesture so the user does not have to count while holding two
/// levers. The vehicle cannot confirm any of this from the bootloader, so this
/// is a metronome and not a progress bar: it says what to do and when, and the
/// scooter itself is what tells the user whether it worked.
class BrakeGesturePacer extends StatefulWidget {
  const BrakeGesturePacer({super.key, this.onSequenceComplete});

  final VoidCallback? onSequenceComplete;

  @override
  State<BrakeGesturePacer> createState() => _BrakeGesturePacerState();
}

enum _PacerPhase { idle, leadIn, hold, blip, done }

class _BrakeGesturePacerState extends State<BrakeGesturePacer> {
  Timer? _ticker;
  _PacerPhase _phase = _PacerPhase.idle;
  int _segment = 1;
  int _remaining = 0;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _start() {
    _ticker?.cancel();
    setState(() {
      _phase = _PacerPhase.leadIn;
      _segment = 1;
      _remaining = brakeLeadInSeconds;
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _stop() {
    _ticker?.cancel();
    _ticker = null;
    setState(() => _phase = _PacerPhase.idle);
  }

  void _tick() {
    if (!mounted) return;
    setState(() {
      _remaining--;
      if (_remaining > 0) return;
      if (_phase == _PacerPhase.leadIn) {
        // Zero is the squeeze cue, so the first hold starts on the same beat
        // the user's hands do.
        _phase = _PacerPhase.hold;
        _segment = 1;
        _remaining = brakeHoldSecondsFor(1);
      } else if (_phase == _PacerPhase.hold) {
        if (_segment == brakeSegments) {
          _phase = _PacerPhase.done;
          _ticker?.cancel();
          _ticker = null;
          widget.onSequenceComplete?.call();
        } else {
          _phase = _PacerPhase.blip;
          _remaining = brakeBlipSeconds;
        }
      } else if (_phase == _PacerPhase.blip) {
        _segment++;
        _phase = _PacerPhase.hold;
        _remaining = brakeHoldSecondsFor(_segment);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final counting = _phase == _PacerPhase.leadIn ||
        _phase == _PacerPhase.hold ||
        _phase == _PacerPhase.blip;
    // The lead-in belongs to no segment, so nothing is lit until the squeeze.
    final onPattern = _phase == _PacerPhase.hold || _phase == _PacerPhase.blip;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BrakeGestureDiagram(
          activeSegment: onPattern ? _segment : null,
          blipping: _phase == _PacerPhase.blip,
          finished: _phase == _PacerPhase.done,
        ),
        const SizedBox(height: 18),
        if (counting) ...[
          Text(
            switch (_phase) {
              _PacerPhase.leadIn => l10n.brakeLeadInLabel,
              _PacerPhase.blip => l10n.brakeBlipRight,
              _ => l10n.brakeKeepHolding,
            },
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: switch (_phase) {
                _PacerPhase.leadIn => Colors.white,
                _PacerPhase.blip => Colors.orangeAccent,
                _ => Colors.cyanAccent,
              },
            ),
          ),
          const SizedBox(height: 2),
          Text('$_remaining',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  fontFeatures: [FontFeature.tabularFigures()])),
          const SizedBox(height: 2),
          Text(
            _phase == _PacerPhase.leadIn
                ? l10n.brakeLeadInHint
                : l10n.brakeLeftStaysHint,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 10),
          Center(
            child:
                TextButton(onPressed: _stop, child: Text(l10n.brakePacerStop)),
          ),
        ],
        if (_phase == _PacerPhase.done) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 10),
              Flexible(
                child: Text(l10n.brakePacerDone,
                    style: const TextStyle(fontSize: 14)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Center(
            child: TextButton(
                onPressed: _start, child: Text(l10n.brakePacerRestart)),
          ),
        ],
        if (_phase == _PacerPhase.idle)
          Center(
            child: FilledButton.icon(
              onPressed: _start,
              icon: const Icon(Icons.timer_outlined),
              label: Text(l10n.brakePacerStart),
            ),
          ),
      ],
    );
  }
}
