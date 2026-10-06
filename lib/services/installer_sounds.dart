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
  InstallerSounds({Duration retryDelay = const Duration(seconds: 10)})
    : _retryDelay = retryDelay {
    muted.addListener(_onMuteChanged);
    if (!muted.value) _prepareCues();
  }

  static final ValueNotifier<bool> muted = ValueNotifier<bool>(false);

  final Duration _retryDelay;
  final Map<InstallerCue, AudioPlayer> _players = {};
  final Set<InstallerCue> _preparedCues = {};
  final Map<InstallerCue, Timer> _retries = {};
  bool _disposed = false;

  void _prepareCues() {
    for (final cue in InstallerCue.values) {
      if (!_players.containsKey(cue)) unawaited(_prepareCue(cue));
    }
  }

  void _onMuteChanged() {
    if (_disposed) return;
    if (muted.value) {
      for (final player in _players.values) {
        unawaited(_stopPlayer(player));
      }
    } else {
      _prepareCues();
    }
  }

  Future<void> _stopPlayer(AudioPlayer player) async {
    try {
      await player.stop();
    } catch (error) {
      debugPrint('Installer audio stop failed: $error');
    }
  }

  void play(InstallerCue cue) {
    if (_disposed || muted.value) return;
    if (!_preparedCues.contains(cue)) {
      debugPrint('Installer audio not ready: ${cue.name}');
      return;
    }
    unawaited(_resumeCue(cue));
  }

  Future<void> _prepareCue(InstallerCue cue) async {
    if (_disposed || muted.value) return;
    final player = AudioPlayer();
    _players[cue] = player;
    try {
      await player.setReleaseMode(ReleaseMode.stop);
      if (_disposed || _players[cue] != player) return;
      await player.setSource(AssetSource('sounds/${cue.assetName}'));
      if (!_disposed && _players[cue] == player) _preparedCues.add(cue);
    } catch (error) {
      debugPrint('Installer audio ${cue.name} unavailable: $error');
      if (_players[cue] == player) _players.remove(cue);
      unawaited(_disposePlayer(player));
      _scheduleRetry(cue);
    }
  }

  void _scheduleRetry(InstallerCue cue) {
    if (_disposed || muted.value || _retries.containsKey(cue)) return;
    _retries[cue] = Timer(_retryDelay, () {
      _retries.remove(cue);
      unawaited(_prepareCue(cue));
    });
  }

  Future<void> _disposePlayer(AudioPlayer player) async {
    try {
      await player.dispose();
    } catch (error) {
      debugPrint('Installer audio cleanup failed: $error');
    }
  }

  Future<void> _resumeCue(InstallerCue cue) async {
    final player = _players[cue]!;
    try {
      if (_disposed || muted.value) return;
      await player.resume();
      if (muted.value) await _stopPlayer(player);
    } catch (error) {
      debugPrint('Installer audio ${cue.name} unavailable: $error');
      if (_players[cue] == player) {
        _preparedCues.remove(cue);
        _players.remove(cue);
      }
      unawaited(_disposePlayer(player));
      _scheduleRetry(cue);
    }
  }

  void dispose() {
    _disposed = true;
    muted.removeListener(_onMuteChanged);
    for (final retry in _retries.values) {
      retry.cancel();
    }
    _retries.clear();
    for (final player in _players.values) {
      unawaited(_disposePlayer(player));
    }
    _players.clear();
    _preparedCues.clear();
  }
}
