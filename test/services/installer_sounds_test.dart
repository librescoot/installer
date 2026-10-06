import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/models/installer_phase.dart';
import 'package:librescoot_installer/services/installer_sounds.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('mute stops all sound instances and prevents new playback', () async {
    final originalAudio = AudioplayersPlatformInterface.instance;
    final originalGlobal = GlobalAudioplayersPlatformInterface.instance;
    final cacheDir = Directory.systemTemp.createTempSync(
      'installer-sounds-test-',
    );
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async => cacheDir.path);
    final audio = _RecordingAudioPlatform();
    AudioplayersPlatformInterface.instance = audio;
    GlobalAudioplayersPlatformInterface.instance = _TestGlobalAudioPlatform();
    InstallerSounds? first;
    InstallerSounds? second;
    try {
      InstallerSounds.muted.value = true;
      first = InstallerSounds();
      first.play(InstallerCue.attention);
      await Future<void>.delayed(Duration.zero);
      expect(audio.calls, isEmpty);

      InstallerSounds.muted.value = false;
      second = InstallerSounds();
      final playerCount = InstallerCue.values.length * 2;
      await _waitForCalls(audio, 'source', playerCount);
      expect(
        audio.calls.where((call) => call == 'create'),
        hasLength(playerCount),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(audio.calls.where((call) => call == 'resume'), isEmpty);
      for (final cue in InstallerCue.values) {
        first.play(cue);
      }
      await _waitForCalls(audio, 'resume', InstallerCue.values.length);
      expect(
        audio.calls.where((call) => call == 'source'),
        hasLength(playerCount),
      );

      InstallerSounds.muted.value = true;
      await _waitForCalls(audio, 'stop', playerCount);
      audio.calls.clear();
      first.play(InstallerCue.error);
      second.play(InstallerCue.critical);
      await Future<void>.delayed(Duration.zero);
      expect(
        audio.calls.where((call) => call == 'create' || call == 'resume'),
        isEmpty,
      );
    } finally {
      first?.dispose();
      second?.dispose();
      if (second != null) {
        await _waitForCalls(audio, 'dispose', InstallerCue.values.length * 2);
      }
      InstallerSounds.muted.value = false;
      AudioplayersPlatformInterface.instance = originalAudio;
      GlobalAudioplayersPlatformInterface.instance = originalGlobal;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, null);
      cacheDir.deleteSync(recursive: true);
    }
  });

  test('failed startup loads retry without playing a delayed cue', () async {
    final originalAudio = AudioplayersPlatformInterface.instance;
    final originalGlobal = GlobalAudioplayersPlatformInterface.instance;
    final cacheDir = Directory.systemTemp.createTempSync(
      'installer-audio-retry-',
    );
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async => cacheDir.path);
    final audio = _RecordingAudioPlatform()..failSources = true;
    AudioplayersPlatformInterface.instance = audio;
    GlobalAudioplayersPlatformInterface.instance = _TestGlobalAudioPlatform();
    InstallerSounds.muted.value = false;
    final sounds = InstallerSounds(
      retryDelay: const Duration(milliseconds: 100),
    );
    try {
      await _waitForCalls(audio, 'dispose', InstallerCue.values.length);
      sounds.play(InstallerCue.critical);
      expect(audio.calls.where((call) => call == 'resume'), isEmpty);
      audio.failSources = false;
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await _waitForCalls(audio, 'source', InstallerCue.values.length * 2);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(audio.calls.where((call) => call == 'resume'), isEmpty);
      sounds.play(InstallerCue.critical);
      await _waitForCalls(audio, 'resume', 1);
      sounds.dispose();
      await _waitForCalls(audio, 'dispose', InstallerCue.values.length * 2);
      final creates = audio.calls.where((call) => call == 'create').length;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      sounds.play(InstallerCue.error);
      expect(audio.calls.where((call) => call == 'create'), hasLength(creates));
      expect(audio.calls.where((call) => call == 'resume'), hasLength(1));
    } finally {
      sounds.dispose();
      InstallerSounds.muted.value = false;
      AudioplayersPlatformInterface.instance = originalAudio;
      GlobalAudioplayersPlatformInterface.instance = originalGlobal;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, null);
      cacheDir.deleteSync(recursive: true);
    }
  });

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

  test('all playback uses prepared sources and retries failed preloads', () {
    final source = File(
      'lib/services/installer_sounds.dart',
    ).readAsStringSync();
    final playback = source.substring(
      source.indexOf('void play(InstallerCue cue)'),
      source.indexOf('Future<void> _prepareCue'),
    );
    expect(playback, contains('unawaited(_resumeCue(cue))'));
    expect(source, contains('for (final cue in InstallerCue.values)'));
    expect(source, isNot(contains('await player.play(')));
    expect(playback, isNot(contains('await ')));
    expect(source, contains('await player.setSource(AssetSource('));
    expect(source, contains('_players.remove(cue)'));
    expect(source, contains('_retries[cue] = Timer('));
    expect(source, contains('retry.cancel()'));
  });

  test('brake release and pull sounds fit inside a one-second blip', () {
    for (final cue in [InstallerCue.release, InstallerCue.pull]) {
      final samples = _waveSamples(cue);
      expect(samples.length, lessThan(48000));
      expect(
        samples.map((sample) => sample.abs()).reduce(_max),
        greaterThan(3276),
      );
    }
  });

  test('cue waveforms have no clicks or clipping', () {
    for (final cue in InstallerCue.values) {
      final samples = _waveSamples(cue);
      expect(samples.first, 0, reason: cue.name);
      expect(samples.last, 0, reason: cue.name);
      expect(
        samples.map((sample) => sample.abs()).reduce(_max),
        lessThanOrEqualTo(27572),
        reason: cue.name,
      );
      var curvature = 0;
      for (var i = 2; i < samples.length; i++) {
        curvature = _max(
          curvature,
          (samples[i] - 2 * samples[i - 1] + samples[i - 2]).abs(),
        );
      }
      expect(curvature, lessThan(394), reason: cue.name);
    }
  });
}

int _max(int a, int b) => a > b ? a : b;

List<int> _waveSamples(InstallerCue cue) {
  final wav = File('assets/sounds/${cue.assetName}').readAsBytesSync();
  final bytes = ByteData.sublistView(wav);
  expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
  expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
  List<int>? samples;
  var validFormat = false;
  for (var offset = 12; offset + 8 <= wav.length;) {
    final type = String.fromCharCodes(wav.sublist(offset, offset + 4));
    final size = bytes.getUint32(offset + 4, Endian.little);
    final start = offset + 8;
    expect(start + size, lessThanOrEqualTo(wav.length));
    if (type == 'fmt ') {
      expect(bytes.getUint16(start, Endian.little), 1);
      expect(bytes.getUint16(start + 2, Endian.little), 1);
      expect(bytes.getUint32(start + 4, Endian.little), 48000);
      expect(bytes.getUint16(start + 14, Endian.little), 16);
      validFormat = true;
    } else if (type == 'data') {
      expect(size % 2, 0);
      samples = [
        for (var i = start; i < start + size; i += 2)
          bytes.getInt16(i, Endian.little),
      ];
    }
    offset = start + size + (size % 2);
  }
  expect(validFormat, isTrue);
  expect(samples, isNotNull);
  expect(samples, isNotEmpty);
  return samples!;
}

Future<void> _waitForCalls(
  _RecordingAudioPlatform audio,
  String method,
  int count,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (audio.calls.where((call) => call == method).length < count) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for $count $method calls: ${audio.calls}');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

class _TestGlobalAudioPlatform extends GlobalAudioplayersPlatformInterface {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());

  @override
  Future<void> init() async {}

  @override
  Stream<GlobalAudioEvent> getGlobalEventStream() => const Stream.empty();
}

class _RecordingAudioPlatform extends AudioplayersPlatformInterface {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());

  final List<String> calls = [];
  bool failSources = false;
  final Map<String, StreamController<AudioEvent>> streams = {};

  @override
  Future<void> create(String playerId) async {
    calls.add('create');
    streams[playerId] = StreamController<AudioEvent>.broadcast();
  }

  @override
  Stream<AudioEvent> getEventStream(String playerId) =>
      streams[playerId]!.stream;

  @override
  Future<void> setReleaseMode(String playerId, ReleaseMode releaseMode) async {}

  @override
  Future<void> setSourceUrl(
    String playerId,
    String url, {
    bool? isLocal,
    String? mimeType,
  }) async {
    calls.add('source');
    streams[playerId]!.add(
      const AudioEvent(eventType: AudioEventType.prepared, isPrepared: true),
    );
    if (failSources) throw StateError('Source unavailable');
  }

  @override
  Future<void> resume(String playerId) async => calls.add('resume');

  @override
  Future<void> release(String playerId) async {}

  @override
  Future<void> stop(String playerId) async => calls.add('stop');

  @override
  Future<int?> getCurrentPosition(String playerId) async => 0;

  @override
  Future<void> dispose(String playerId) async {
    await streams.remove(playerId)?.close();
    calls.add('dispose');
  }
}
