import 'dart:io';

/// Shell fixtures exercise ordering and outcomes, not host-wide disk flushing.
Future<ProcessResult> runShellFixture(
  String scriptPath, {
  Map<String, String> environment = const {},
}) async {
  final bin = Directory('${File(scriptPath).parent.path}/test-bin');
  await bin.create(recursive: true);
  final sync = File('${bin.path}/sync');
  await sync.writeAsString('#!/bin/sh\nexit 0\n');
  final chmod = await Process.run('chmod', ['+x', sync.path]);
  if (chmod.exitCode != 0) throw StateError(chmod.stderr.toString());
  return Process.run(
    'sh',
    [scriptPath],
    environment: {
      ...environment,
      'PATH':
          '${bin.path}:${environment['PATH'] ?? Platform.environment['PATH']}',
    },
  );
}
