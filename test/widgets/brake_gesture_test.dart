import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/l10n/app_localizations.dart';
import 'package:librescoot_installer/l10n/app_localizations_de.dart';
import 'package:librescoot_installer/widgets/brake_gesture.dart';
import 'package:librescoot_installer/services/installer_sounds.dart';

Widget _host(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'),
  home: Scaffold(body: child),
);

/// Advance the pacer's one-second ticker by [seconds].
Future<void> _advance(WidgetTester tester, int seconds) async {
  for (var i = 0; i < seconds; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
}

void main() {
  testWidgets('Start cues the first pull as the hold appears', (tester) async {
    final cues = <InstallerCue>[];
    await tester.pumpWidget(_host(BrakeGesturePacer(onCue: cues.add)));

    await tester.tap(find.text('Start the timer'));
    expect(cues, [InstallerCue.pull]);
    await tester.pump();
    expect(find.text('Pull and hold both brakes'), findsOneWidget);
    expect(find.text('${brakeHoldSecondsFor(1)}'), findsOneWidget);
    expect(
      tester
          .widget<BrakeGestureDiagram>(find.byType(BrakeGestureDiagram))
          .activeSegment,
      1,
    );
  });

  testWidgets('a hold is followed by the right-lever blip, then another hold', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const BrakeGesturePacer()));
    await tester.tap(find.text('Start the timer'));
    await tester.pump();

    await _advance(tester, brakeHoldSecondsFor(1));
    expect(find.text('Right lever off, now'), findsOneWidget);
    expect(find.text('$brakeBlipSeconds'), findsOneWidget);

    await _advance(tester, brakeBlipSeconds);
    expect(find.text('Pull and hold both brakes'), findsOneWidget);
    expect(find.text('${brakeHoldSecondsFor(2)}'), findsOneWidget);
  });

  testWidgets('the fourth hold ends the sequence, with no fifth squeeze', (
    tester,
  ) async {
    var completed = 0;
    await tester.pumpWidget(
      _host(BrakeGesturePacer(onSequenceComplete: () => completed++)),
    );
    await tester.tap(find.text('Start the timer'));
    await tester.pump();

    // Three hold-and-blip rounds, then the fourth hold on its own.
    for (var i = 0; i < brakeSegments - 1; i++) {
      await _advance(tester, brakeHoldSecondsFor(i + 1) + brakeBlipSeconds);
      expect(completed, 0, reason: 'finished early, after round ${i + 1}');
    }
    await _advance(tester, brakeHoldSecondsFor(1));

    // Completion fires the moment the levers should be let go; the release
    // cue then stays up in large type before the done summary replaces it.
    expect(completed, 1);
    expect(find.text('Right lever off, now'), findsNothing);
    expect(find.text('Let go of both brakes'), findsOneWidget);

    await _advance(tester, brakeReleaseSeconds);
    expect(find.text('Let go of both brakes'), findsNothing);
    expect(
      find.textContaining('should restart within 10–20 seconds'),
      findsOneWidget,
    );
  });

  testWidgets('audio cues only the moments to engage and release', (
    tester,
  ) async {
    final cues = <InstallerCue>[];
    await tester.pumpWidget(_host(BrakeGesturePacer(onCue: cues.add)));
    await tester.tap(find.text('Start the timer'));
    await tester.pump();
    expect(cues, [InstallerCue.pull]);
    await _advance(tester, brakeHoldSecondsFor(1) - 1);
    expect(cues, [InstallerCue.pull]);
    await _advance(tester, 1);
    expect(cues, [InstallerCue.pull, InstallerCue.release]);
    expect(find.text('Right lever off, now'), findsOneWidget);
    expect(
      tester
          .widget<BrakeGestureDiagram>(find.byType(BrakeGestureDiagram))
          .blipping,
      isTrue,
    );
    await _advance(tester, brakeBlipSeconds);
    expect(cues, [InstallerCue.pull, InstallerCue.release, InstallerCue.pull]);
    expect(find.text('Pull and hold both brakes'), findsOneWidget);
    expect(
      tester
          .widget<BrakeGestureDiagram>(find.byType(BrakeGestureDiagram))
          .blipping,
      isFalse,
    );
    await _advance(
      tester,
      brakeTotalSeconds -
          brakeHoldSecondsFor(1) -
          brakeBlipSeconds +
          brakeReleaseSeconds,
    );
    expect(cues.where((cue) => cue == InstallerCue.pull).length, 4);
    expect(cues.where((cue) => cue == InstallerCue.release).length, 4);
    expect(cues.last, InstallerCue.release);
  });

  testWidgets('stopping mid-count returns to the start, ticker and all', (
    tester,
  ) async {
    final cues = <InstallerCue>[];
    await tester.pumpWidget(_host(BrakeGesturePacer(onCue: cues.add)));
    await tester.tap(find.text('Start the timer'));
    await tester.pump();
    await _advance(tester, 3);

    await tester.tap(find.text('Stop'));
    await tester.pump();
    final countAtStop = cues.length;

    expect(find.text('Start the timer'), findsOneWidget);
    // A ticker left running would keep counting behind the idle screen and
    // fire the sequence at whatever moment the user pressed start again.
    await _advance(tester, brakeTotalSeconds);
    expect(find.text('Start the timer'), findsOneWidget);
    expect(cues.length, countAtStop);
  });

  test('German guidance names the restart window and dashboard LED', () {
    final message = AppLocalizationsDe().brakePacerDone;
    expect(message, contains('10–20 Sekunden'));
    expect(message, contains('LED im Tacho'));
  });

  test('the whole gesture is forty seconds, blips included', () {
    // The blips land on the ten second marks and count toward the forty,
    // rather than pausing the clock and pushing the end out to forty-three.
    final held = [
      for (var s = 1; s <= brakeSegments; s++) brakeHoldSecondsFor(s),
    ].reduce((a, b) => a + b);
    final blips = (brakeSegments - 1) * brakeBlipSeconds;
    expect(held + blips, brakeTotalSeconds);
  });

  testWidgets('the diagram lights nothing until the squeeze cue', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const BrakeGestureDiagram()));
    expect(find.text('${brakeMarkSeconds}s'), findsOneWidget);
    expect(find.text('$brakeTotalSeconds'), findsNothing);
    // The left lever never moves, so the band spans the whole run.
    expect(find.text('Left lever held down throughout'), findsOneWidget);
  });
}
