import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/l10n/app_localizations.dart';
import 'package:librescoot_installer/widgets/brake_gesture.dart';

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
  testWidgets('the count starts with a lead-in, not with the first hold',
      (tester) async {
    await tester.pumpWidget(_host(const BrakeGesturePacer()));

    await tester.tap(find.text('Start the timer'));
    await tester.pump();

    // The gap this closes: pressing the button and squeezing the levers are
    // different moments, and without the lead-in every later beat inherits
    // the difference.
    expect(find.text('Squeeze both brakes in'), findsOneWidget);
    expect(find.text('$brakeLeadInSeconds'), findsOneWidget);
    expect(find.text('Hold both brakes'), findsNothing);
  });

  testWidgets('the first hold begins when the lead-in reaches zero',
      (tester) async {
    await tester.pumpWidget(_host(const BrakeGesturePacer()));
    await tester.tap(find.text('Start the timer'));
    await tester.pump();

    await _advance(tester, brakeLeadInSeconds);

    expect(find.text('Hold both brakes'), findsOneWidget);
    expect(find.text('${brakeHoldSecondsFor(1)}'), findsOneWidget);
  });

  testWidgets('a hold is followed by the right-lever blip, then another hold',
      (tester) async {
    await tester.pumpWidget(_host(const BrakeGesturePacer()));
    await tester.tap(find.text('Start the timer'));
    await tester.pump();
    await _advance(tester, brakeLeadInSeconds);

    await _advance(tester, brakeHoldSecondsFor(1));
    expect(find.text('Right lever off, now'), findsOneWidget);
    expect(find.text('$brakeBlipSeconds'), findsOneWidget);

    await _advance(tester, brakeBlipSeconds);
    expect(find.text('Hold both brakes'), findsOneWidget);
    expect(find.text('${brakeHoldSecondsFor(2)}'), findsOneWidget);
  });

  testWidgets('the fourth hold ends the sequence, with no fifth squeeze',
      (tester) async {
    var completed = 0;
    await tester.pumpWidget(
        _host(BrakeGesturePacer(onSequenceComplete: () => completed++)));
    await tester.tap(find.text('Start the timer'));
    await tester.pump();
    await _advance(tester, brakeLeadInSeconds);

    // Three hold-and-blip rounds, then the fourth hold on its own.
    for (var i = 0; i < brakeSegments - 1; i++) {
      await _advance(tester, brakeHoldSecondsFor(i + 1) + brakeBlipSeconds);
      expect(completed, 0, reason: 'finished early, after round ${i + 1}');
    }
    await _advance(tester, brakeHoldSecondsFor(1));

    expect(completed, 1);
    expect(find.text('Right lever off, now'), findsNothing);
    expect(find.textContaining('That is the pattern'), findsOneWidget);
  });

  testWidgets('stopping mid-count returns to the start, ticker and all',
      (tester) async {
    await tester.pumpWidget(_host(const BrakeGesturePacer()));
    await tester.tap(find.text('Start the timer'));
    await tester.pump();
    await _advance(tester, brakeLeadInSeconds + 3);

    await tester.tap(find.text('Stop'));
    await tester.pump();

    expect(find.text('Start the timer'), findsOneWidget);
    // A ticker left running would keep counting behind the idle screen and
    // fire the sequence at whatever moment the user pressed start again.
    await _advance(tester, brakeTotalSeconds);
    expect(find.text('Start the timer'), findsOneWidget);
  });

  test('the whole gesture is forty seconds, blips included', () {
    // The blips land on the ten second marks and count toward the forty,
    // rather than pausing the clock and pushing the end out to forty-three.
    final held = [
      for (var s = 1; s <= brakeSegments; s++) brakeHoldSecondsFor(s)
    ].reduce((a, b) => a + b);
    final blips = (brakeSegments - 1) * brakeBlipSeconds;
    expect(held + blips, brakeTotalSeconds);
  });

  testWidgets('the diagram lights nothing until the squeeze cue',
      (tester) async {
    await tester.pumpWidget(_host(const BrakeGestureDiagram()));
    expect(find.text('${brakeMarkSeconds}s'), findsOneWidget);
    expect(find.text('$brakeTotalSeconds'), findsNothing);
    // The left lever never moves, so the band spans the whole run.
    expect(find.text('Left lever held down throughout'), findsOneWidget);
  });
}
