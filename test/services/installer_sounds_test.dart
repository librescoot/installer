import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/models/installer_phase.dart';
import 'package:librescoot_installer/services/installer_sounds.dart';

void main() {
  test('manual power and restart steps use the stronger cue', () {
    expect(cueForPhase(InstallerPhase.scooterPrep), InstallerCue.critical);
    expect(cueForPhase(InstallerPhase.mdbBoot), InstallerCue.critical);
    expect(cueForPhase(InstallerPhase.cbbReconnect), InstallerCue.critical);
  });

  test('ordinary actions use the gentle cue, automated phases stay quiet', () {
    expect(
      cueForPhase(InstallerPhase.bluetoothPairing),
      InstallerCue.attention,
    );
    expect(cueForPhase(InstallerPhase.keycardSetup), InstallerCue.attention);
    expect(cueForPhase(InstallerPhase.mdbFlash), isNull);
  });

  test('attention chime is softer than the urgent cue', () {
    int peak(String name) {
      final wav = File('assets/sounds/$name.wav').readAsBytesSync();
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      final samples = ByteData.sublistView(wav);
      var maximum = 0;
      for (var offset = 44; offset < wav.length; offset += 2) {
        final value = samples.getInt16(offset, Endian.little).abs();
        if (value > maximum) maximum = value;
      }
      return maximum;
    }

    expect(peak('attention'), lessThan(peak('critical') ~/ 2));
  });
}
