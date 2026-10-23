import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/ums_board_probe.dart';

void main() {
  Uint8List bootArea(String identifier, int offset) {
    final bytes = Uint8List(UmsBoardProbe.bootAreaBytes);
    bytes.setAll(offset, latin1.encode(identifier));
    return bytes;
  }

  test('identifies the observed DBC signature without a saved environment', () {
    final bytes = bootArea('mx6solo_dbc', 0x5fa4a);
    expect(UmsBoardProbe.identify(bytes), UmsBoard.dbc);
  });

  test('MDB and DBC identifiers need not share an offset', () {
    for (final offset in [0x400, 0x50000, 0xe0000]) {
      expect(
        UmsBoardProbe.identify(bootArea('mx6ul_mdb', offset)),
        UmsBoard.mdb,
      );
      expect(
        UmsBoardProbe.identify(bootArea('mx6solo_dbc', offset)),
        UmsBoard.dbc,
      );
    }
  });

  test('accepts a board identifier embedded in a build path', () {
    expect(
      UmsBoardProbe.identify(
        latin1.encode('/board/hardware/mx6ul_mdb/config\x00'),
      ),
      UmsBoard.mdb,
    );
  });

  test('mixed signatures are conflicting, not whichever appears first', () {
    for (final text in [
      'mx6ul_mdb\x00mx6solo_dbc\x00',
      'mx6solo_dbc\x00mx6ul_mdb\x00',
    ]) {
      expect(UmsBoardProbe.identify(latin1.encode(text)), UmsBoard.conflicting);
    }
  });

  test('blank, truncated and unrelated boot areas stay unknown', () {
    for (final bytes in [
      <int>[],
      Uint8List(UmsBoardProbe.bootAreaBytes),
      List.filled(1024, 0xff),
      latin1.encode('mx6solo_db'),
      latin1.encode('fsl,imx6dl\x00ums 0 mmc 0\x00'),
      latin1.encode('bootcmd=ums 0 mmc 2;\x00'),
    ]) {
      expect(UmsBoardProbe.identify(bytes), UmsBoard.unknown);
    }
  });

  test('identifier must be a complete token', () {
    for (final text in ['not_mx6ul_mdb', 'mx6solo_dbc_backup', 'mx6ul_mdb2']) {
      expect(UmsBoardProbe.identify(latin1.encode(text)), UmsBoard.unknown);
    }
  });

  test('does not inspect signatures outside the bounded boot area', () {
    final bytes = Uint8List(UmsBoardProbe.bootAreaBytes + 32);
    bytes.setAll(UmsBoardProbe.bootAreaBytes + 1, latin1.encode('mx6solo_dbc'));
    expect(UmsBoardProbe.identify(bytes), UmsBoard.unknown);
  });
}
