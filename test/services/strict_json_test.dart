import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/strict_json.dart';

void main() {
  test('accepts ordinary nested JSON with escaped keys', () {
    expect(decodeStrictJson(r'{"a":[{"b":"x\"y"}],"n":-1.25e2}'), isA<Map>());
  });

  test('rejects duplicate keys, including escaped equivalents', () {
    for (final source in [
      r'{"a":1,"a":2}',
      r'{"ota":{"schema":1,"schema":2}}',
      r'{"a":1,"\u0061":2}',
      r'{"a":1} {"b":2}',
    ]) {
      expect(() => decodeStrictJson(source), throwsFormatException);
    }
  });
}
