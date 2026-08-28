import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/models/keycard_master.dart';

/// The command this gates replaces the board's master list with a sentinel and
/// persists it. An upgrade keeps /data, so sending it to a board that had a
/// master erased the owner's card and then reported none. That is a real user
/// report, not a hypothetical.
void main() {
  test('a board with no master gets it, since that is the armed one', () {
    // keycard-service arms auto-master-learning at startup only when it has
    // no master, so this is the only board where the command does anything.
    expect(shouldDisengageMasterLearning(0), isTrue);
  });

  test('a board with a master is left alone', () {
    expect(shouldDisengageMasterLearning(1), isFalse);
    expect(shouldDisengageMasterLearning(3), isFalse);
  });

  test('a count nobody could read is not a board with no cards', () {
    // The count is published by keycard-service at its own startup, moments
    // before this asks, so racing it is the likely way to read nothing. Taking
    // that as zero is how the card got erased in the first place.
    expect(shouldDisengageMasterLearning(null), isFalse);
  });

  test('the sentinel alone still reads as zero and is rewritten', () {
    // GetMasterCount excludes NONE, so a board carrying only the sentinel
    // reports zero. Rewriting it there costs nothing and keeps the guard from
    // depending on how the sentinel is spelled.
    expect(shouldDisengageMasterLearning(0), isTrue);
  });
}
