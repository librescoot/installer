import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

enum InstallerCue { beat, release, pull, confirmed, attention, boot }

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
      await player.play(AssetSource('sounds/${cue.name}.wav'));
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
