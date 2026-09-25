import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/models/installer_phase.dart';
import 'package:librescoot_installer/services/installer_sounds.dart';

void main() {
  test('manual power and restart steps use the stronger cue', () {
    expect(cueForPhase(InstallerPhase.notices), InstallerCue.critical);
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

  test('installer cues use the selected dashboard assets', () {
    expect(InstallerCue.critical.assetName, 'toast-warning.wav');
    expect(InstallerCue.error.assetName, 'toast-error.wav');
    expect(InstallerCue.attention.assetName, 'toast-info.wav');
    expect(InstallerCue.confirmed.assetName, 'nav-start.wav');
    expect(InstallerCue.release.assetName, 'blinker-pulse.wav');
    expect(InstallerCue.pull.assetName, 'nav-hop.wav');
    for (final cue in InstallerCue.values) {
      final wav = File('assets/sounds/${cue.assetName}').readAsBytesSync();
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    }
  });

  test('brake release and pull sounds fit inside a one-second blip', () {
    for (final cue in [InstallerCue.release, InstallerCue.pull]) {
      final wav = File('assets/sounds/${cue.assetName}').readAsBytesSync();
      // Both cues are 48 kHz stereo 16-bit PCM.
      expect(wav.length, lessThan(48000 * 2 * 2 + 1024));
      final samples = ByteData.sublistView(wav, 44);
      var peak = 0;
      for (var i = 0; i < samples.lengthInBytes; i += 2) {
        final amplitude = samples.getInt16(i, Endian.little).abs();
        if (amplitude > peak) peak = amplitude;
      }
      expect(peak, greaterThan(20000));
    }
  });
}
