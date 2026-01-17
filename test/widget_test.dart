import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/main.dart';

void main() {
  testWidgets('Installer app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const LibreScootInstaller());
    expect(find.text('LibreScoot Installer'), findsOneWidget);
  });
}
