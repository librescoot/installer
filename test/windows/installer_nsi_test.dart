import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('passes the persistent wrapper path to the inner executable', () {
    final source = File('windows/installer.nsi').readAsStringSync();
    final environment = source.indexOf(
      r'SetEnvironmentVariable(t "LIBRESCOOT_OUTER_WRAPPER_PATH", t "$EXEPATH")',
    );
    final launch = source.indexOf('ExecWait');

    expect(environment, greaterThanOrEqualTo(0));
    expect(launch, greaterThan(environment));
  });
}
