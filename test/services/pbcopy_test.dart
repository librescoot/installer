import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/log_service.dart';

/// pbcopy reads its input in the current locale and assumes Mac OS Roman when
/// LC_CTYPE says nothing, which is what a GUI app's environment says. The log
/// is UTF-8, so a copy made without the locale turns every umlaut into its Mac
/// OS Roman reading on the way to the clipboard.
void main() {
  test('the clipboard command says what encoding it is sending', () {
    final (exe, args, env) = LogService.pbcopyCommand('501');

    expect(exe, 'launchctl');
    expect(args, ['asuser', '501', 'pbcopy']);
    expect(env['LC_CTYPE'], 'UTF-8');
  });
}
