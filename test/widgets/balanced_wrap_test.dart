import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/widgets/balanced_wrap.dart';

void main() {
  Widget host(double width, {TextDirection direction = TextDirection.ltr}) =>
      MaterialApp(
        home: Directionality(
          textDirection: direction,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: BalancedWrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < 7; i++)
                    SizedBox(key: ValueKey('pill-$i'), width: 100, height: 24),
                ],
              ),
            ),
          ),
        ),
      );

  testWidgets('balances the fewest rows while preserving order', (
    tester,
  ) async {
    await tester.pumpWidget(host(330));
    final tops = [
      for (var i = 0; i < 7; i++)
        tester.getTopLeft(find.byKey(ValueKey('pill-$i'))).dy,
    ];
    expect(<double>{...tops}, hasLength(3));
    expect(tops.last, tops[5]);
    expect(tops[1], tops.first);
    expect(tops, orderedEquals(tops.toList()..sort()));
    expect(tester.getSize(find.byType(BalancedWrap)).height, 88);

    await tester.pumpWidget(host(230));
    expect({
      for (var i = 0; i < 7; i++)
        tester.getTopLeft(find.byKey(ValueKey('pill-$i'))).dy,
    }, hasLength(4));
  });

  testWidgets('starts rows on the right in RTL', (tester) async {
    await tester.pumpWidget(host(330, direction: TextDirection.rtl));
    final first = tester.getTopLeft(find.byKey(const ValueKey('pill-0')));
    final second = tester.getTopLeft(find.byKey(const ValueKey('pill-1')));
    expect(first.dx, greaterThan(second.dx));
  });
}
