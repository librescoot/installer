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
  InstallerSounds() {
    for (final cue in [InstallerCue.pull, InstallerCue.release]) {
      unawaited(_prepareBrakeCue(cue));
    }
  }

  final Map<InstallerCue, AudioPlayer> _players = {};
  final Set<InstallerCue> _preparedBrakeCues = {};
  final Map<InstallerCue, Timer> _brakeRetries = {};
  bool _disposed = false;

  void play(InstallerCue cue) {
    if (_disposed) return;
    if (cue == InstallerCue.pull || cue == InstallerCue.release) {
      if (!_preparedBrakeCues.contains(cue)) {
        debugPrint('Installer brake audio not ready: ${cue.name}');
        return;
      }
      unawaited(_resumeBrakeCue(cue));
      return;
    }
    unawaited(_play(cue));
  }

  Future<void> _prepareBrakeCue(InstallerCue cue) async {
    if (_disposed) return;
    final player = AudioPlayer();
    _players[cue] = player;
    try {
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setSource(AssetSource('sounds/${cue.assetName}'));
      if (!_disposed) _preparedBrakeCues.add(cue);
    } catch (error) {
      debugPrint('Installer brake audio ${cue.name} unavailable: $error');
      _players.remove(cue);
      unawaited(_disposePlayer(player));
      _scheduleBrakeRetry(cue);
    }
  }

  void _scheduleBrakeRetry(InstallerCue cue) {
    if (_disposed || _brakeRetries.containsKey(cue)) return;
    _brakeRetries[cue] = Timer(const Duration(seconds: 10), () {
      _brakeRetries.remove(cue);
      unawaited(_prepareBrakeCue(cue));
    });
  }

  Future<void> _disposePlayer(AudioPlayer player) async {
    try {
      await player.dispose();
    } catch (error) {
      debugPrint('Installer audio cleanup failed: $error');
    }
  }

  Future<void> _resumeBrakeCue(InstallerCue cue) async {
    final player = _players[cue]!;
    try {
      await player.resume();
    } catch (error) {
      debugPrint('Installer brake audio ${cue.name} unavailable: $error');
      _preparedBrakeCues.remove(cue);
      _players.remove(cue);
      unawaited(_disposePlayer(player));
      _scheduleBrakeRetry(cue);
    }
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
    for (final retry in _brakeRetries.values) {
      retry.cancel();
    }
    _brakeRetries.clear();
    for (final player in _players.values) {
      unawaited(_disposePlayer(player));
    }
    _players.clear();
    _preparedBrakeCues.clear();
  }
}
