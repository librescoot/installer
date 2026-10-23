import 'dart:convert';

/// Identity of the bootloader on disk, not necessarily of the physical board.
enum UmsBoard { unknown, mdb, dbc, conflicting }

class UmsBoardProbe {
  static const int bootAreaBytes = 1024 * 1024;

  static UmsBoard identify(List<int> bytes) {
    final text = latin1.decode(
      bytes.length > bootAreaBytes ? bytes.sublist(0, bootAreaBytes) : bytes,
    );
    final mdb = _hasIdentifier(text, 'mx6ul_mdb');
    final dbc = _hasIdentifier(text, 'mx6solo_dbc');
    if (mdb && dbc) return UmsBoard.conflicting;
    if (mdb) return UmsBoard.mdb;
    if (dbc) return UmsBoard.dbc;
    return UmsBoard.unknown;
  }

  static bool _hasIdentifier(String text, String identifier) =>
      RegExp('(^|[^A-Za-z0-9_])$identifier(\$|[^A-Za-z0-9_])').hasMatch(text);
}
