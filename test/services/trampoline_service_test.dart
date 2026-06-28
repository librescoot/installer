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
    test('catalogue covers the 15 German regions plus neighbours', () {
      expect(Region.all.length, 20);
      final germanCount =
          Region.all.where((r) => r.country == 'Deutschland').length;
      expect(germanCount, 15);
    });

    test('berlin_brandenburg slug is correct', () {
      final region = Region.all.firstWhere((r) => r.name.contains('Berlin'));
      expect(region.slug, 'berlin_brandenburg');
      expect(region.country, 'Deutschland');
    });

    test('fromSlug humanises unknown slugs under the catch-all country', () {
      final region = Region.fromSlug('italy-nord-est');
      expect(region.name, 'Italy Nord Est');
      expect(region.country, 'Weitere');
    });

    test('equality and hashCode are by slug', () {
      const a = Region(name: 'Bayern', slug: 'bayern', country: 'Deutschland');
      final b = Region.fromSlug('bayern');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });
}
