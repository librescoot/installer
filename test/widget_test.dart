import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/models/installer_phase.dart';

void main() {
  test('InstallerPhase has 14 values', () {
    expect(InstallerPhase.values.length, 14);
  });

  test('InstallerPhase first is welcome, last is finish', () {
    expect(InstallerPhase.values.first, InstallerPhase.welcome);
    expect(InstallerPhase.values.last, InstallerPhase.finish);
  });
}
