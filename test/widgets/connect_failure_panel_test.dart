import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/widgets/connect_failure_panel.dart';
import 'package:librescoot_installer/widgets/notice_card.dart';

const _details = 'Phase:    MDB connect\n'
    'Verdict:  sshTimeout\n'
    'Error:    TimeoutException: after 0:00:15.000000';

Future<void> _pump(
  WidgetTester tester, {
  required String body,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: ConnectFailurePanel(
        title: 'No answer from the scooter',
        body: body,
        checklistTitle: 'What to check',
        detailsLabel: 'Technical details',
        details: _details,
        copyLabel: 'Copy to clipboard',
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  const checklist = 'The board is on USB and said nothing back.\n'
      '• Check the cable at both ends\n'
      '• Plug into the laptop directly\n'
      'Nothing on the scooter has been changed.';

  testWidgets('the diagnosis leads and the checklist is a list',
      (tester) async {
    await _pump(tester, body: checklist);

    // The heading is what the screen is for. The exception used to be here
    // instead, which told a user with a loose cable nothing.
    expect(find.text('No answer from the scooter'), findsOneWidget);
    expect(find.text('The board is on USB and said nothing back.'),
        findsOneWidget);

    // Real list items, not a paragraph with bullet characters in it. The
    // whole point of the card is that it can be scanned while holding a
    // screwdriver.
    expect(find.byType(NoticeCard), findsOneWidget);
    expect(find.text('Check the cable at both ends'), findsOneWidget);
    expect(find.text('Plug into the laptop directly'), findsOneWidget);
    expect(find.text('Nothing on the scooter has been changed.'),
        findsOneWidget);
  });

  testWidgets('the exception is folded away, not thrown away', (tester) async {
    await _pump(tester, body: checklist);

    // Open, it is the loudest thing on a screen whose job is to say what to
    // do next, and it is shown to someone who cannot act on it.
    expect(find.textContaining('TimeoutException'), findsNothing);
    expect(find.text('Technical details'), findsOneWidget);

    await tester.tap(find.text('Technical details'));
    await tester.pumpAndSettle();

    // Gone entirely it would take the only evidence a bug report has with it.
    expect(find.textContaining('TimeoutException'), findsOneWidget);
    expect(find.text('Copy to clipboard'), findsOneWidget);
  });

  testWidgets('copying puts the raw block on the clipboard', (tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    await _pump(tester, body: checklist);
    await tester.tap(find.text('Technical details'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy to clipboard'));
    await tester.pumpAndSettle();

    // Verbatim. This is what gets pasted into Discord, so a reformatted or
    // translated version of it is worth less than nothing.
    expect(copied, [_details]);
  });

  testWidgets('prose with no bullets keeps its paragraph breaks',
      (tester) async {
    // The macOS permission message is three paragraphs and no list. Running
    // it through the bullet splitter drops the blank lines and runs the
    // paragraphs together into one block.
    const prose = 'The USB connection is fine.\n\n'
        'Open Privacy and Security, then switch the installer on.\n\n'
        'It carries on by itself as soon as you do.';
    await _pump(tester, body: prose);

    expect(find.text(prose), findsOneWidget);
    expect(find.byType(NoticeCard), findsNothing);
  });
}
