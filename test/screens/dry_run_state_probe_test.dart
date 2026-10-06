import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'dry-run pairing returns before Bluetooth and vehicle-state commands',
    () {
      final source = File(
        'lib/screens/installer_screen.dart',
      ).readAsStringSync();
      final start = source.indexOf('Future<void> _startBluetoothPairing()');
      final pairing = source.substring(
        start,
        source.indexOf('void _startBleAdvRearm()', start),
      );
      final dryStart = pairing.indexOf('if (_isDryRun)');
      final dryEnd = pairing.indexOf('Future<void> stopStaleStart()');
      expect(dryStart, greaterThanOrEqualTo(0));
      expect(dryEnd, lessThan(pairing.indexOf('_sshService.')));
      final dry = pairing.substring(dryStart, dryEnd);
      expect(dry, contains("_blePinCode = '123456'"));
      expect(dry, contains('_bleConnected = true'));
      expect('if (!isCurrent()) return;'.allMatches(dry), hasLength(2));
      expect(dry.trim(), endsWith('return;\n    }'));
    },
  );

  test('dry-run board state probes return before SSH or Redis', () {
    final source = File('lib/screens/installer_screen.dart').readAsStringSync();
    final mdbStart = source.indexOf('Future<BoardState> _detectMdbState()');
    final dbcStart = source.indexOf('Future<BoardState> _detectDbcState()');
    final mdb = source.substring(mdbStart, dbcStart);
    final dbc = source.substring(
      dbcStart,
      source.indexOf('bool get _isUntestedStockFirmware', dbcStart),
    );
    expect(
      mdb.indexOf('if (_isDryRun)'),
      lessThan(mdb.indexOf('_sshService.readOsRelease()')),
    );
    expect(mdb, contains("version: 'v1.15.0'"));
    expect(
      dbc.indexOf('if (_isDryRun)'),
      lessThan(dbc.indexOf('_sshService.redisHgetall(')),
    );
    expect(dbc, contains('return BoardState.unknown'));
  });
}
