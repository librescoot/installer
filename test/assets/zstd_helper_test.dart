import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Routing tiles ship as .tar.zst and are unpacked on the dashboard. zstd only
/// entered the dashboard image on 2026-08-09, and an upgrade never writes the
/// stage-0 image that carries one, so the board keeps whatever its own
/// firmware shipped. On stable v1.2.1 that is nothing, which is why routing
/// tiles failed on every upgrade from stable.
void main() {
  late String template;

  setUpAll(() {
    template = File('assets/trampoline.sh.template').readAsStringSync();
  });

  test('the vendored zstd is present and is an ARM binary', () {
    final f = File('assets/tools/zstd-dbc');
    expect(f.existsSync(), isTrue, reason: 'the helper is not vendored');
    // ELF, 32-bit, little endian, ARM (e_machine 0x28) at offset 18.
    final head = f.readAsBytesSync().sublist(0, 20);
    expect(head.sublist(0, 4), [0x7f, 0x45, 0x4c, 0x46], reason: 'not an ELF');
    expect(head[4], 1, reason: 'not 32-bit');
    expect(head[18], 0x28, reason: 'not ARM');
  });

  test('the dashboard is asked before anything is sent', () {
    // A board with its own zstd should not be sent one, and should not have a
    // failed push count against it.
    final probe = template.indexOf(r'zstd --version >/dev/null 2>&1');
    final push = template.indexOf('"zstd helper"');
    expect(probe, isNot(-1));
    expect(push, greaterThan(probe));
  });

  test('the sent binary is verified by running it, not by arriving', () {
    // It needs glibc 2.38 and exists for older firmware, so presence on the
    // board and usability on the board are different questions.
    expect(template, contains('/data/installer/zstd-dbc --version'));
    final verify = template.indexOf('/data/installer/zstd-dbc --version');
    final use = template.indexOf(r'$ZSTD_BIN -d -f -o');
    expect(use, greaterThan(verify));
  });

  test('the unpack runs whichever zstd was settled on', () {
    // Not a hardcoded `zstd`, which is what made this fail silently on a board
    // that did not have one.
    expect(template, contains(r'dbc_ssh "$ZSTD_BIN -d -f -o'));
    expect(template, isNot(contains('dbc_ssh "zstd -d -f -o')));
  });

  test('a board with no usable zstd says so rather than failing quietly', () {
    expect(template, contains('no usable zstd on the dashboard'));
  });
}
