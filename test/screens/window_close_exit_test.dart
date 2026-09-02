import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Closing the window ends the process after cleanup, the way the finish
/// screen does. Handing the close to the window manager instead let the
/// runner tear the engine down from its destructor chain, which on Windows
/// crashed in flutter_windows.dll on every close.
void main() {
  test('the window close ends the process rather than destroying the window',
      () {
    final source = File('lib/screens/installer_screen.dart').readAsStringSync();
    final start = source.indexOf('Future<void> _handleWindowClose()');
    final end = source.indexOf('\n  Future<void> _cleanupBeforeClose()', start);
    final handler = source.substring(start, end);
    expect(handler, contains('closeWindow: _exitProcess'));
    expect(source, isNot(contains('windowManager.destroy')));
  });
}
