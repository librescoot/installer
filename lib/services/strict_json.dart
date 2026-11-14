import 'dart:convert';

/// Decode a bounded manifest while rejecting duplicate object keys.
dynamic decodeStrictJson(String source) {
  if (source.length > 16 * 1024 * 1024) {
    throw const FormatException('Manifest too large');
  }
  final scanner = _JsonScanner(source);
  scanner.value(0);
  scanner.space();
  if (scanner.index != source.length) {
    throw const FormatException('Trailing JSON content');
  }
  return jsonDecode(source);
}

class _JsonScanner {
  _JsonScanner(this.source);

  final String source;
  int index = 0;

  void space() {
    while (index < source.length && ' \t\r\n'.contains(source[index])) {
      index++;
    }
  }

  void expect(String character) {
    space();
    if (index >= source.length || source[index] != character) {
      throw FormatException('Expected $character');
    }
    index++;
  }

  String string() {
    space();
    if (index >= source.length || source[index] != '"') {
      throw const FormatException('Expected string');
    }
    final start = index++;
    while (index < source.length) {
      final code = source.codeUnitAt(index++);
      if (code == 0x5c) {
        if (index >= source.length) break;
        index++;
      } else if (code == 0x22) {
        return jsonDecode(source.substring(start, index)) as String;
      }
    }
    throw const FormatException('Unterminated string');
  }

  void value(int depth) {
    if (depth > 100) throw const FormatException('JSON nesting too deep');
    space();
    if (index >= source.length) throw const FormatException('Missing value');
    switch (source[index]) {
      case '{':
        index++;
        space();
        if (index < source.length && source[index] == '}') {
          index++;
          return;
        }
        final keys = <String>{};
        while (true) {
          final key = string();
          if (!keys.add(key)) throw FormatException('Duplicate key: $key');
          expect(':');
          value(depth + 1);
          space();
          if (index < source.length && source[index] == '}') {
            index++;
            return;
          }
          expect(',');
        }
      case '[':
        index++;
        space();
        if (index < source.length && source[index] == ']') {
          index++;
          return;
        }
        while (true) {
          value(depth + 1);
          space();
          if (index < source.length && source[index] == ']') {
            index++;
            return;
          }
          expect(',');
        }
      case '"':
        string();
        return;
      default:
        final start = index;
        while (index < source.length && !',]} \t\r\n'.contains(source[index])) {
          index++;
        }
        if (start == index) throw const FormatException('Invalid JSON value');
    }
  }
}
