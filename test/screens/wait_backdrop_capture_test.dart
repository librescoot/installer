import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A wait draws over the screen the user just left, which the phase host
/// remembers as it builds. Whether a build is that screen or a wait has to be
/// read off the widget, not off the phase: the MDB flash phase is an ordinary
/// screen until the user confirms and a wait after, and a phase-based rule
/// listed it as ordinary. Every rebuild during the flash then stored the wait
/// as the backdrop of the next one, nesting the whole card one level deeper
/// per rebuild, hundreds of times a second while the download reported
/// progress, until the frame rate fell to nothing and the layout overflowed
/// the stack.
void main() {
  late String source;

  setUpAll(() {
    source = File('lib/screens/installer_screen.dart').readAsStringSync();
  });

  test('the backdrop is captured by widget type, never by phase', () {
    final captures = RegExp(r'_frozenBackdrop = ').allMatches(source).toList();
    expect(captures, hasLength(1));
    final line = source.substring(
      source.lastIndexOf('\n', captures.single.start) + 1,
      source.indexOf('\n', captures.single.start),
    );
    expect(line.trim(), 'if (content is! WaitScaffold) _frozenBackdrop = content;');
    expect(source, isNot(contains('.isWait')));
  });
}
