import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every MDB to DBC call has to survive the DBC's host key changing under it:
/// a flash gives the board a new key while the MDB still has the old one
/// pinned in the known_hosts its own image shipped. `ssh -y -y` is what makes
/// that survivable, and dropbear's scp frontend has no equivalent, so scp must
/// not be the transport for anything here.
void main() {
  late String source;

  setUpAll(() {
    source = File('assets/trampoline.sh.template').readAsStringSync();
  });

  test('nothing in the trampoline reaches the DBC over scp', () {
    final scpCall = RegExp(r'(^|[;&|]\s*|\$\(\s*)scp\s', multiLine: true);
    expect(
      scpCall.hasMatch(source),
      isFalse,
      reason: 'scp cannot skip a mismatched host key on dropbear',
    );
  });

  test('the DBC copy streams through the ssh that skips the host key', () {
    final start = source.indexOf('dbc_put() {');
    expect(start, isNot(-1), reason: 'dbc_put not found');
    final end = source.indexOf('\n}\n', start);
    final body = source.substring(start, end);

    expect(body, contains(r'ssh -y -y root@$DBC_IP "cat > '));
    expect(body, contains(r'< "$src"'));
    // cat exits 0 on a stream that was cut short, so the size is what decides
    // whether the file is allowed into place.
    expect(body, contains(r"wc -c < '$dst.part'"));
    expect(body, contains(r"mv '$dst.part' '$dst'"));
    expect(body, contains(r"rm -f '$dst.part'"));
    // The rename is guarded by the size check in the same command, so a short
    // copy can never leave a truncated file at the real path.
    final verify = body.indexOf('wc -c');
    final rename = body.indexOf(r"mv '$dst.part'");
    expect(rename, greaterThan(verify));
  });

  test('the stock DBC bootloader tools go through dbc_put', () {
    expect(
      source,
      contains(
        r'dbc_put "$INSTALLER_DIR/fwtools/stock-dbc/fw_setenv" /tmp/fw_setenv',
      ),
    );
    expect(
      source,
      contains(
        r'dbc_put "$INSTALLER_DIR/fwtools/stock-dbc/fw_env.config" /tmp/fw_env.config',
      ),
    );
  });

  test('dbc_put is valid POSIX shell', () async {
    final start = source.indexOf('dbc_put() {');
    final end = source.indexOf('\n}\n', start) + 3;
    final directory = await Directory.systemTemp.createTemp('dbc-put-');
    addTearDown(() => directory.delete(recursive: true));
    final script = File('${directory.path}/dbc_put.sh');
    await script.writeAsString(source.substring(start, end));

    final syntax = await Process.run('sh', ['-n', script.path]);
    expect(syntax.exitCode, 0, reason: syntax.stderr.toString());
  });
}
