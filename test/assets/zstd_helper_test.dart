import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the vendored zstd is present and is an ARM binary', () {
    final file = File('assets/tools/zstd-dbc');
    expect(file.existsSync(), isTrue);
    final head = file.readAsBytesSync().sublist(0, 20);
    expect(head.sublist(0, 4), [0x7f, 0x45, 0x4c, 0x46], reason: 'not an ELF');
    expect(head[4], 1, reason: 'not 32-bit');
    expect(head[18], 0x28, reason: 'not ARM');
  });
}
