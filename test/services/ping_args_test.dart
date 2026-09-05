import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/network_service.dart';

void main() {
  group('the ping wait means a second on every platform', () {
    test('this host asks for a second, however it has to spell it', () {
      final args = NetworkService.pingArgs('192.168.7.1');
      expect(args.last, '192.168.7.1');
      if (Platform.isWindows) {
        expect(args, containsAllInOrder(['-n', '1', '-w', '1000']));
      } else if (Platform.isMacOS) {
        expect(args, containsAllInOrder(['-c', '1', '-W', '1000']));
      } else {
        expect(args, containsAllInOrder(['-c', '1', '-W', '1']));
      }
    });

    test('macOS and Linux do not share a number', () {
      final source =
          File('lib/services/network_service.dart').readAsStringSync();
      final fn = source.substring(
        source.indexOf('static List<String> pingArgs(String host) {'),
        source.indexOf('/// Check if MDB is reachable'),
      );
      expect(fn, contains('Platform.isWindows'));
      expect(fn, contains('Platform.isMacOS'));
    });

    test('nothing builds its own ping arguments any more', () {
      var found = 0;
      for (final path in [
        'lib/services/network_service.dart',
        'lib/services/usb_detector.dart',
        'lib/screens/installer_screen.dart',
      ]) {
        final source = File(path).readAsStringSync();
        for (final m in RegExp("'ping',").allMatches(source)) {
          found++;
          final args = source.substring(m.end, m.end + 80);
          expect(args, contains('pingArgs('),
              reason: '$path builds its own arguments: $args');
        }
      }
      expect(found, 3, reason: 'all three ping call sites must be checked');
    });
  });
}
