import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/models/region.dart';
import 'package:librescoot_installer/models/trampoline_status.dart';

void main() {
  group('TrampolineStatus', () {
    test('parses success', () {
      final status = TrampolineStatus.parse('success\nAll done in 5m');
      expect(status.result, TrampolineResult.success);
      expect(status.message, 'All done in 5m');
    });

    test('parses error', () {
      final status = TrampolineStatus.parse(
        'error: DBC UMS device not found\nlog line 1\nlog line 2',
      );
      expect(status.result, TrampolineResult.error);
      expect(status.errorLog, contains('log line'));
    });

    test('handles empty content', () {
      final status = TrampolineStatus.parse('');
      expect(status.result, TrampolineResult.unknown);
    });
  });

  group('Region', () {
    test('has 15 regions', () {
      expect(Region.all.length, 15);
    });

    test('berlin_brandenburg slug is correct', () {
      final region = Region.all.firstWhere((r) => r.name.contains('Berlin'));
      expect(region.slug, 'berlin_brandenburg');
    });
  });
}
