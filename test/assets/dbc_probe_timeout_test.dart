import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  final helpers = File('assets/device.sh').absolute.path;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('dbc-probe-timeout-');
    for (final name in ['sleep', 'grep']) {
      await Link('${root.path}/$name').create('/bin/$name');
    }
  });
  tearDown(() => root.delete(recursive: true));

  Future<ProcessResult> run(String body) => Process.run(
    '/bin/sh',
    ['-c', ". '$helpers'\n$body"],
    environment: {'PATH': root.path},
  );

  test('fallback preserves successful output and failure status', () async {
    final success = await run("dbc_probe_timeout 5 /bin/echo identified");
    expect(success.exitCode, 0);
    expect(success.stdout, 'identified\n');
    final failure = await run("dbc_probe_timeout 5 /bin/sh -c 'exit 7'");
    expect(failure.exitCode, 7);
  });

  test('fallback terminates a stalled command within its deadline', () async {
    final elapsed = Stopwatch()..start();
    final result = await run('dbc_probe_timeout 0.1 /bin/sleep 30');
    expect(result.exitCode, isNot(0));
    expect(elapsed.elapsed, lessThan(const Duration(seconds: 2)));
  });

  test(
    'USB and PPP identity probes work without a timeout executable',
    () async {
      for (final link in ['usb0', 'ppp0']) {
        final result = await run('''
MODE=upgrade
DBC_MENDER=/data/dbc.mender
ip() { echo '192.168.7.2 dev $link'; }
ping() { return 0; }
ssh() { return 0; }
${link == 'usb0' ? 'dbc_usb_identified' : 'dbc_ppp_upgrade_identified'}
''');
        expect(result.exitCode, 0, reason: result.stderr.toString());
      }
    },
  );

  test('failed SSH identity is rejected without timeout executable', () async {
    final result = await run('''
ip() { echo '192.168.7.2 dev usb0'; }
ping() { return 0; }
ssh() { return 1; }
dbc_usb_identified
''');
    expect(result.exitCode, 1);
  });
}
