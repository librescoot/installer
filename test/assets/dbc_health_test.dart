import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late File menderUpdate;
  late File redis;
  late Map<String, String> environment;

  setUp(() {
    root = Directory.systemTemp.createTempSync('dbc_health_');
    File('${root.path}/os-release').writeAsStringSync('VERSION_ID="v1.4.0"\n');
    File('${root.path}/boot-id').writeAsStringSync('boot-new\n');
    File('${root.path}/mountinfo').writeAsStringSync(
      '36 25 179:3 / / rw,relatime - ext4 /dev/mmcblk2p3 rw\n',
    );
    menderUpdate = File('${root.path}/mender-update')
      ..writeAsStringSync('''#!/bin/sh
[ "\$1" = show-artifact ] || exit 2
echo release-v1.4.0
''');
    redis = File('${root.path}/redis-cli')
      ..writeAsStringSync('#!/bin/sh\necho PONG\n');
    Process.runSync('chmod', ['755', menderUpdate.path, redis.path]);
    environment = {
      'OS_RELEASE': '${root.path}/os-release',
      'BOOT_ID_FILE': '${root.path}/boot-id',
      'MOUNTINFO_FILE': '${root.path}/mountinfo',
      'MENDER_UPDATE': menderUpdate.path,
      'REDIS_CLI': redis.path,
    };
  });

  tearDown(() => root.deleteSync(recursive: true));

  ProcessResult probe(String phase) => Process.runSync('sh', [
    'assets/dbc-health.sh',
    phase,
    'release-v1.4.0',
    'v1.4.0',
    'boot-old',
    '179:2',
    '179:3',
  ], environment: environment);

  test('pre-commit uses only changed identity, exact target, and Redis', () {
    menderUpdate.writeAsStringSync('#!/bin/sh\nexit 99\n');

    final result = probe('precommit');

    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(result.stdout.toString().trim(), 'boot-new|179:3|v1.4.0|');
  });

  test('post-commit requires exact mender-update show-artifact', () {
    final result = probe('committed');
    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(
      result.stdout.toString().trim(),
      'boot-new|179:3|v1.4.0|release-v1.4.0',
    );

    menderUpdate.writeAsStringSync('#!/bin/sh\necho release-v1.3.4\n');
    expect(probe('committed').exitCode, isNot(0));
  });

  test('requires changed boot and root identities', () {
    File('${root.path}/boot-id').writeAsStringSync('boot-old\n');
    expect(probe('precommit').exitCode, isNot(0));

    File('${root.path}/boot-id').writeAsStringSync('boot-new\n');
    File('${root.path}/mountinfo').writeAsStringSync(
      '36 25 179:2 / / rw,relatime - ext4 /dev/mmcblk2p2 rw\n',
    );
    expect(probe('precommit').exitCode, isNot(0));
  });

  test('canonicalizes version case but still requires its exact value', () {
    File('${root.path}/os-release').writeAsStringSync(
      'VERSION_ID="nightly-20260913t064252"\n',
    );
    final result = Process.runSync('sh', [
      'assets/dbc-health.sh',
      'precommit',
      'release-nightly-20260913T064252',
      'nightly-20260913T064252',
      'boot-old',
      '179:2',
      '179:3',
    ], environment: environment);
    expect(result.exitCode, 0, reason: result.stderr.toString());

    File('${root.path}/os-release').writeAsStringSync('VERSION_ID="1.4.0"\n');
    final mismatch = probe('precommit');
    expect(mismatch.exitCode, isNot(0));
    expect(mismatch.stderr.toString(), contains('health-fail: version'));

    File('${root.path}/os-release').writeAsStringSync('VERSION_ID="v1.4.0"\n');
    File('${root.path}/mountinfo').writeAsStringSync(
      '36 25 179:4 / / rw,relatime - ext4 /dev/mmcblk2p4 rw\n',
    );
    expect(probe('precommit').exitCode, isNot(0));
  });

  test('requires a DBC-originated Redis PONG', () {
    redis.writeAsStringSync('#!/bin/sh\necho NOPE\n');
    expect(probe('precommit').exitCode, isNot(0));
  });
}
