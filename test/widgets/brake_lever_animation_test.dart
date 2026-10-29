import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/widgets/brake_lever_animation.dart';

Widget host(BrakeLeverPose pose, {bool animate = true, bool reduced = false}) =>
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: Scaffold(
          body: SizedBox(
            width: 632,
            child: BrakeLeverAnimation(pose: pose, animate: animate),
          ),
        ),
      ),
    );

int frame(WidgetTester tester) =>
    tester.widget<BrakeLeverFrame>(find.byType(BrakeLeverFrame)).frame;

void main() {
  testWidgets('plays each movement once and holds its final pose', (
    tester,
  ) async {
    await tester.pumpWidget(host(BrakeLeverPose.released));
    expect(frame(tester), 0);
    await tester.pumpWidget(host(BrakeLeverPose.held));
    await tester.pump(const Duration(milliseconds: 220));
    expect(frame(tester), inInclusiveRange(5, 6));
    await tester.pump(const Duration(milliseconds: 220));
    expect(frame(tester), 11);
    await tester.pump(const Duration(seconds: 10));
    expect(frame(tester), 11);

    await tester.pumpWidget(host(BrakeLeverPose.rightReleased));
    await tester.pump(const Duration(milliseconds: 440));
    expect(frame(tester), 23);
    await tester.pumpWidget(host(BrakeLeverPose.held));
    await tester.pump(const Duration(milliseconds: 440));
    expect(frame(tester), 35);
    await tester.pumpWidget(host(BrakeLeverPose.released));
    await tester.pump(const Duration(milliseconds: 440));
    expect(frame(tester), 47);
  });

  testWidgets('stopping during a movement immediately resets both levers', (
    tester,
  ) async {
    await tester.pumpWidget(host(BrakeLeverPose.held));
    await tester.pumpWidget(host(BrakeLeverPose.rightReleased));
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pumpWidget(host(BrakeLeverPose.released, animate: false));
    expect(frame(tester), 0);
    await tester.pump(const Duration(seconds: 2));
    expect(frame(tester), 0);
  });

  testWidgets('reduced motion changes poses without playing the movement', (
    tester,
  ) async {
    await tester.pumpWidget(host(BrakeLeverPose.released, reduced: true));
    await tester.pumpWidget(host(BrakeLeverPose.held, reduced: true));
    expect(frame(tester), 11);
    await tester.pumpWidget(host(BrakeLeverPose.rightReleased, reduced: true));
    expect(frame(tester), 23);
    expect(
      find.descendant(
        of: find.byType(BrakeLeverAnimation),
        matching: find.byType(DecoratedBox),
      ),
      findsNothing,
    );
  });

  testWidgets('scales without overflow at narrow and wide desktop sizes', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final width in [280.0, 1050.0]) {
      await tester.binding.setSurfaceSize(Size(width, 600));
      await tester.pumpWidget(host(BrakeLeverPose.held));
      await tester.pump();
      final size = tester.getSize(find.byType(BrakeLeverFrame));
      expect(
        size.width / size.height,
        closeTo(BrakeLeverFrame.aspectRatio, 0.01),
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders the supplied artwork without atlas bleed or a border', (
    tester,
  ) async {
    const key = ValueKey('lever-poses');
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RepaintBoundary(
            key: key,
            child: SizedBox(
              width: 632,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BrakeLeverFrame(frame: 0),
                  BrakeLeverFrame(frame: 11),
                  BrakeLeverFrame(frame: 23),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => precacheImage(
        const AssetImage(BrakeLeverFrame.asset),
        tester.element(find.byKey(key)),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(key),
      matchesGoldenFile('../goldens/brake_levers.png'),
    );
  });
}
