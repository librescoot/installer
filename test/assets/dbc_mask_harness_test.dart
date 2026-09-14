import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _maskHelper(String source) {
  const opener = "<< 'DBC_MASK_SCRIPT'\n";
  final start = source.indexOf(opener);
  final end = source.indexOf('\nDBC_MASK_SCRIPT', start);
  if (start < 0 || end < 0) throw StateError('DBC mask helper not found');
  return source
      .substring(start + opener.length, end)
      .replaceAll(
        'RECOVERY_DIR=/data/librescoot-installer',
        'RECOVERY_DIR="\$TEST_ROOT/data/librescoot-installer"',
      )
      .replaceAll(
        'MOUNTPOINT=/run/librescoot-installer-target',
        'MOUNTPOINT="\$TEST_ROOT/mount"',
      )
      .replaceAll(
        'CONFIG=/etc/mender/mender.conf',
        'CONFIG="\$TEST_ROOT/mender.conf"',
      )
      .replaceAll('/proc/self/mountinfo', '"\$TEST_ROOT/mountinfo"')
      .replaceAll('/sys/class/block/', '\$TEST_ROOT/sys/class/block/')
      .replaceAll(
        '"/etc/systemd/system/\$UNIT"',
        '"\$TEST_ROOT/running/etc/systemd/system/\$UNIT"',
      )
      .replaceAll('[ -b "\$resolved" ]', '[ -e "\$resolved" ]');
}

void main() {
  late Directory root;
  late Directory bin;
  late File helper;
  late File mountinfo;
  late File events;
  late Map<String, String> environment;

  void writeConfig({bool ambiguousA = false}) {
    File('${root.path}/mender.conf').writeAsStringSync('''{
  "RootfsPartA": "/dev/root-a-alias",
  ${ambiguousA ? '"RootfsPartA": "/dev/root-a-second",' : ''}
  "RootfsPartB": "/dev/root-b-alias"
}
''');
  }

  void writeRecovery(String previous) {
    final recovery = File(
      '${root.path}/data/librescoot-installer/dbc-update-mask-recovery',
    );
    recovery.parent.createSync(recursive: true);
    recovery.writeAsStringSync('''run-id: run-1
state: prepared
previous-state: $previous
target-device: ${root.path}/dev/mmcB
target-id: 179:3
expected-artifact: release-v1.4.0
updated: 2026-01-01T00:00:00Z
''');
  }

  ProcessResult run(String action) => Process.runSync('sh', [
    helper.path,
    action,
    'run-1',
    'release-v1.4.0',
  ], environment: environment);

  setUp(() {
    root = Directory.systemTemp.createTempSync('dbc_mask_harness_');
    bin = Directory('${root.path}/bin')..createSync();
    Directory('${root.path}/dev').createSync();
    Directory('${root.path}/sys/class/block/mmcA').createSync(recursive: true);
    Directory('${root.path}/sys/class/block/mmcB').createSync(recursive: true);
    Directory(
      '${root.path}/fs-mmcA/usr/lib/systemd/system',
    ).createSync(recursive: true);
    Directory(
      '${root.path}/fs-mmcB/usr/lib/systemd/system',
    ).createSync(recursive: true);
    Directory(
      '${root.path}/running/etc/systemd/system',
    ).createSync(recursive: true);
    File('${root.path}/dev/mmcA').createSync();
    File('${root.path}/dev/mmcB').createSync();
    File('${root.path}/sys/class/block/mmcA/dev').writeAsStringSync('179:2\n');
    File('${root.path}/sys/class/block/mmcB/dev').writeAsStringSync('179:3\n');
    File(
      '${root.path}/fs-mmcA/usr/lib/systemd/system/librescoot-update.service',
    ).createSync();
    File(
      '${root.path}/fs-mmcB/usr/lib/systemd/system/librescoot-update.service',
    ).createSync();
    mountinfo = File('${root.path}/mountinfo')
      ..writeAsStringSync('36 25 179:2 / / rw - ext4 /dev/root rw\n');
    events = File('${root.path}/events')..createSync();
    writeConfig();

    File('${bin.path}/readlink').writeAsStringSync(r'''#!/bin/sh
if [ "$1" = -f ]; then
  case "$2" in
    /dev/root-a-alias|/dev/root-a-second) echo "$TEST_ROOT/dev/mmcA" ;;
    /dev/root-b-alias) echo "$TEST_ROOT/dev/mmcB" ;;
    *) /usr/bin/readlink -f "$2" ;;
  esac
else
  /usr/bin/readlink "$@"
fi
''');
    File('${bin.path}/mount').writeAsStringSync(r'''#!/bin/sh
while [ "${1#-}" != "$1" ]; do shift; [ "$1" = rw ] && shift; done
src="$1"; mp="$2"; base=${src##*/}
backing="$TEST_ROOT/fs-$base"
mkdir -p "$mp"
cp -a "$backing/." "$mp/"
id=$(cat "$TEST_ROOT/sys/class/block/$base/dev")
printf '40 25 %s / %s rw - ext4 %s rw\n' "$id" "$mp" "$src" >> "$TEST_ROOT/mountinfo"
printf '%s\n' "$backing" > "$TEST_ROOT/mounted-backing"
''');
    File('${bin.path}/umount').writeAsStringSync(r'''#!/bin/sh
mp="$1"; backing=$(cat "$TEST_ROOT/mounted-backing")
rm -rf "$backing"; mkdir -p "$backing"
cp -a "$mp/." "$backing/"
rm -rf "$mp"; mkdir -p "$mp"
grep -v " $mp " "$TEST_ROOT/mountinfo" > "$TEST_ROOT/mountinfo.new"
mv "$TEST_ROOT/mountinfo.new" "$TEST_ROOT/mountinfo"
''');
    File('${bin.path}/systemctl').writeAsStringSync(r'''#!/bin/sh
printf 'systemctl:%s\n' "$*" >> "$EVENTS"
''');
    File(
      '${bin.path}/mender-update',
    ).writeAsStringSync('#!/bin/sh\necho release-v1.4.0\n');
    File('${bin.path}/sync').writeAsStringSync('#!/bin/sh\nexit 0\n');
    for (final name in [
      'readlink',
      'mount',
      'umount',
      'systemctl',
      'mender-update',
      'sync',
    ]) {
      Process.runSync('chmod', ['755', '${bin.path}/$name']);
    }

    helper = File('${root.path}/dbc-updater-mask.sh')
      ..writeAsStringSync(
        _maskHelper(File('assets/trampoline.sh.template').readAsStringSync()),
      );
    Process.runSync('chmod', ['755', helper.path]);
    environment = {
      'PATH': '${bin.path}:${Platform.environment['PATH']}',
      'TEST_ROOT': root.path,
      'EVENTS': events.path,
    };
  });

  tearDown(() => root.deleteSync(recursive: true));

  test('resolves aliases, masks the inactive root, then restores in order', () {
    final prepared = run('prepare');
    expect(prepared.exitCode, 0, reason: prepared.stderr.toString());
    expect(prepared.stdout, contains('target-id: 179:3'));
    expect(
      Link(
        '${root.path}/fs-mmcB/etc/systemd/system/librescoot-update.service',
      ).targetSync(),
      '/dev/null',
    );

    Directory('${root.path}/running').deleteSync(recursive: true);
    Directory('${root.path}/running').createSync();
    Process.runSync('cp', [
      '-a',
      '${root.path}/fs-mmcB/.',
      '${root.path}/running/',
    ]);
    mountinfo.writeAsStringSync('36 25 179:3 / / rw - ext4 /dev/root rw\n');

    final restored = run('restore');
    expect(restored.exitCode, 0, reason: restored.stderr.toString());
    expect(
      Link(
        '${root.path}/running/etc/systemd/system/librescoot-update.service',
      ).existsSync(),
      isFalse,
    );
    expect(events.readAsLinesSync(), [
      'systemctl:daemon-reload',
      'systemctl:start librescoot-update.service',
    ]);
    expect(
      File(
        '${root.path}/data/librescoot-installer/history/run-1-dbc-update-mask',
      ).existsSync(),
      isTrue,
    );
  });

  test('rejects ambiguous configured roots and an already mounted target', () {
    writeConfig(ambiguousA: true);
    var result = run('prepare');
    expect(result.exitCode, isNot(0));
    expect(result.stderr, contains('RootfsPartA is missing or ambiguous'));

    writeConfig();
    mountinfo.writeAsStringSync('''36 25 179:2 / / rw - ext4 /dev/root rw
37 25 179:3 / /data rw - ext4 /dev/target rw
''');
    result = run('prepare');
    expect(result.exitCode, isNot(0));
    expect(result.stderr, contains('inactive target'));
  });

  test('preserves a pre-existing mask and resumes an interrupted mask', () {
    final mask = Link(
      '${root.path}/fs-mmcB/etc/systemd/system/librescoot-update.service',
    );
    mask.parent.createSync(recursive: true);
    mask.createSync('/dev/null');

    var result = run('prepare');
    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(result.stdout, contains('previous-state: preexisting-mask'));

    Directory('${root.path}/data').deleteSync(recursive: true);
    writeRecovery('absent');
    result = run('prepare');
    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(result.stdout, contains('previous-state: absent'));
  });
}
