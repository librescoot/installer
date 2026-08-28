import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/device_probe.dart';

void main() {
  group('parseDfFreeBytes', () {
    test('reads the Available column of df -kP', () {
      const out = '''
Filesystem     1024-blocks    Used Available Capacity Mounted on
/dev/mmcblk1p4     6182864 1932112   3936368      33% /data
''';
      expect(parseDfFreeBytes(out), 3936368 * 1024);
    });

    test('tolerates a wrapped Filesystem column', () {
      const out = '''
Filesystem           1024-blocks      Used Available Capacity Mounted on
/dev/mmcblk1p4          6182864   1932112   3936368      33% /data
''';
      expect(parseDfFreeBytes(out), 3936368 * 1024);
    });

    test('returns null on junk', () {
      expect(parseDfFreeBytes(''), isNull);
      expect(parseDfFreeBytes('df: /data: No such file or directory'), isNull);
    });
  });

  group('parseOsRelease', () {
    test('strips quotes and ignores comments', () {
      const out = '''
# comment
ID=librescoot
VERSION_ID="1.2.1"
PRETTY_NAME='Librescoot 1.2.1'
''';
      final map = parseOsRelease(out);
      expect(map['ID'], 'librescoot');
      expect(map['VERSION_ID'], '1.2.1');
      expect(map['PRETTY_NAME'], 'Librescoot 1.2.1');
    });

    test('returns an empty map for empty input', () {
      expect(parseOsRelease(''), isEmpty);
    });
  });
}
