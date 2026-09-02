import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/models/keycard_capability.dart';

/// keycard-service keeps answering commands while it has no reader, retrying
/// the chip in the background, so the learning screen came up over a
/// dashboard that was not plugged in. The fault it raises is the only sign.
void main() {
  test('the NFC-unavailable code in the fault set means no reader', () {
    expect(keycardReaderMissing('1\n'), isTrue);
    expect(keycardReaderMissing('3\n1\n'), isTrue);
  });

  test('an empty set, or other codes alone, is a reader', () {
    expect(keycardReaderMissing(''), isFalse);
    expect(keycardReaderMissing('\n'), isFalse);
    expect(keycardReaderMissing('12\n'), isFalse);
  });
}
