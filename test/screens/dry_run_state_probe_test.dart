import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
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
