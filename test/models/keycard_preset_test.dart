import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/models/keycard_preset.dart';

void main() {
  test('a uid is upper-case hex with separators removed', () {
    expect(normalizeKeycardUid('04:45:73:c2:7c:67:80'), '044573C27C6780');
    expect(normalizeKeycardUid(' 46dcc300 '), '46DCC300');
    expect(normalizeKeycardUid('04 45 73 C2'), '044573C2');
  });

  test('anything that is not a tag uid is dropped, not fatal', () {
    expect(normalizeKeycardUid('hello'), isNull);
    expect(normalizeKeycardUid('123'), isNull);
    expect(normalizeKeycardUids(['46DCC300', 'nope', '46dcc300', '161B4501']),
        ['46DCC300', '161B4501']);
  });

  test('one argument can name several cards', () {
    expect(splitKeycardArg('46DCC300,161B4501 044573C27C6780'),
        ['46DCC300', '161B4501', '044573C27C6780']);
  });

  test('the board file is one uid per line with comments', () {
    expect(
      parseKeycardUidFile('# cards\n46DCC300\n\n161b4501\n044573C27C6780\n'),
      ['46DCC300', '161B4501', '044573C27C6780'],
    );
  });

  test('preset comes first, captured after, nothing twice', () {
    expect(
      keycardsToAdd(
        preset: ['AABBCCDD'],
        captured: ['46DCC300', 'aabbccdd'],
      ),
      ['AABBCCDD', '46DCC300'],
    );
  });
}
