import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/models/dashboard_messages.dart';
import 'package:librescoot_installer/services/trampoline_service.dart';

void main() {
  test('fills every dashboard line it declares', () {
    final out = TrampolineService.renderTemplate(
      File('assets/trampoline.sh.template').readAsStringSync(),
      upgradeMode: false,
      dbcImagePath: '/data/installer/dbc.sdimg.gz',
      dbcMenderPath: '/data/installer/dbc.mender',
      messages: DashboardMessages.english,
    );
    expect(out, isNot(contains('{{MSG_')));
    expect(out, contains('dbc_say "Installation failed"'));
    expect(out, contains(r'dbc_say "Firmware $DBC_VER running"'));
  });
}
