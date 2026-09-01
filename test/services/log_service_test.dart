import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/log_service.dart';
import 'package:path/path.dart' as p;

void main() {
  group('LogService', () {
    test('uses Explorer select syntax that supports paths with spaces', () {
      expect(
        LogService.windowsExplorerArgs(r'C:\Users\Jane Doe\Documents\Librescoot Installer\run.log'),
        [r'/select,', r'C:\Users\Jane Doe\Documents\Librescoot Installer\run.log'],
      );
    });

    test('appends to the path handed down by the unelevated process', () async {
      final tmp = Directory.systemTemp.createTempSync('librescoot_log_');
      addTearDown(() => tmp.deleteSync(recursive: true));

      final handoff = p.join(tmp.path, 'librescoot-installer-20260101-000000.log');
      File(handoff).writeAsStringSync('2026-01-01 00:00:00.000 [user] parent line\n');

      await LogService.init(
        handoffPath: handoff,
        version: 'test',
        locale: 'en',
        args: ['--auto-start', '--log-file=$handoff'],
      );
      LogService.write('child line');

      expect(LogService.filePath, handoff);
      final contents = File(handoff).readAsStringSync();
      // The parent's lines survive, and the child's carry the admin tag.
      expect(contents, contains('[user] parent line'));
      expect(contents, contains('[admin] child line'));
      expect(contents, contains('elevated process'));
    });
  });
}
