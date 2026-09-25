import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../models/installer_phase.dart';

enum InstallerCue { release, pull, confirmed, attention, critical, error, boot }

extension InstallerCueAsset on InstallerCue {
  String get assetName => switch (this) {
    InstallerCue.release => 'blinker-pulse.wav',
    InstallerCue.pull => 'nav-hop.wav',
    InstallerCue.confirmed => 'nav-start.wav',
    InstallerCue.attention => 'toast-info.wav',
    InstallerCue.critical => 'toast-warning.wav',
    InstallerCue.error => 'toast-error.wav',
    InstallerCue.boot => 'boot.wav',
  };
}

InstallerCue? cueForPhase(InstallerPhase phase) => switch (phase) {
  InstallerPhase.notices ||
  InstallerPhase.scooterPrep ||
  InstallerPhase.mdbBoot ||
  InstallerPhase.cbbReconnect => InstallerCue.critical,
  InstallerPhase.physicalPrep ||
  InstallerPhase.installPlan ||
  InstallerPhase.configurationConfirmation ||
  InstallerPhase.bluetoothPairing ||
  InstallerPhase.keycardSetup ||
  InstallerPhase.reconnect ||
  InstallerPhase.finish => InstallerCue.attention,
  _ => null,
};

/// Best-effort local playback: audio must never interrupt an installation.
class InstallerSounds {
  final Map<InstallerCue, AudioPlayer> _players = {};
  bool _disposed = false;

  void play(InstallerCue cue) {
    if (_disposed) return;
    unawaited(_play(cue));
  }

  Future<void> _play(InstallerCue cue) async {
    try {
      final player = _players.putIfAbsent(cue, AudioPlayer.new);
      await player.setReleaseMode(ReleaseMode.stop);
      if (_disposed) return;
      await player.play(AssetSource('sounds/${cue.assetName}'));
    } catch (error) {
      debugPrint('Installer audio unavailable: $error');
    }
  }

  void dispose() {
    _disposed = true;
    for (final player in _players.values) {
      unawaited(player.dispose());
    }
    _players.clear();
  }
}
