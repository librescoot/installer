import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/flash_service.dart';

/// macOS has no ssh-askpass, and the app deliberately does not self-elevate
/// there, so `sudo` runs in a GUI with no terminal: without a helper it fails
/// before it asks anything and the user meets a failed flash having never been
/// offered a password box.
void main() {
  test('the helper is valid shell', () async {
    final dir = await Directory.systemTemp.createTemp('askpass-test-');
    addTearDown(() => dir.delete(recursive: true));
    final script = File('${dir.path}/askpass.sh');
    await script.writeAsString(FlashService.macOsAskpassScript);

    final syntax = await Process.run('sh', ['-n', script.path]);
    expect(syntax.exitCode, 0, reason: syntax.stderr.toString());
  });
}
