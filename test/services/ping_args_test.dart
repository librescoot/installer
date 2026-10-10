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
  });
}
