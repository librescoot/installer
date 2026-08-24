import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/theme.dart';
import 'package:librescoot_installer/widgets/action_overlay.dart';
import 'package:librescoot_installer/widgets/wait_scaffold.dart';

/// The card that asks for a hand on the scooter. What it must not do is look
/// like the wait card: there is nothing running and nothing to time.
void main() {
  Widget host(Widget child) =>
      MaterialApp(theme: librescootTheme(), home: Scaffold(body: child));

  testWidgets('the ask, the ways to do it, and the way out', (tester) async {
    var cancelled = false;
    await tester.pumpWidget(host(WaitScaffold(
      backdrop: const Text('the screen behind'),
      overlay: ActionOverlay(
        title: 'Roller entsperren',
        instruction: 'Entsperre den Roller.',
        hints: const ['Karte an den Leser', 'Oder ein Handy'],
        watching: 'Der Installer macht von allein weiter.',
        actions: [
          TextButton(
            onPressed: () => cancelled = true,
            child: const Text('Abbrechen'),
          ),
        ],
      ),
    )));

    expect(find.text('Roller entsperren'), findsOneWidget);
    expect(find.text('Entsperre den Roller.'), findsOneWidget);
    expect(find.text('Karte an den Leser'), findsOneWidget);
    expect(find.text('Oder ein Handy'), findsOneWidget);
    expect(find.text('Der Installer macht von allein weiter.'), findsOneWidget);
    // The screen it covers stays legible behind it, dimmed.
    expect(find.text('the screen behind'), findsOneWidget);

    await tester.tap(find.text('Abbrechen'));
    expect(cancelled, isTrue);
  });

  testWidgets('without hints it is the ask and the spinner', (tester) async {
    await tester.pumpWidget(host(const ActionOverlay(
      title: 'Roller parken',
      instruction: 'Seitenständer ausklappen.',
      watching: 'Der Installer wartet darauf.',
    )));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
  });
}
