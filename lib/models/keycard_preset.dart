/// Keycards known before the reader has seen them: the ones named on the
/// command line, and the ones the connected scooter already had before the
/// install wiped or replaced its data. Both end up as `add:<uid>` commands at
/// the keycard step, so they are normalised the way keycard-service stores
/// them: upper-case hex, no separators, one entry per card.
library;

final RegExp _hexUid = RegExp(r'^[0-9A-F]{8,20}$');

/// Cleans one raw UID. Accepts `04:45:73:c2:7c:67:80`, `0445 73c2 7c6780` and
/// the bare form; returns null for anything that is not a plausible tag UID.
String? normalizeKeycardUid(String raw) {
  final uid = raw
      .trim()
      .replaceAll(RegExp(r'[\s:\-]'), '')
      .toUpperCase();
  return _hexUid.hasMatch(uid) ? uid : null;
}

/// The unique, valid UIDs in [raw], in first-seen order. Invalid entries are
/// dropped rather than failing the lot: one typo on the command line should
/// not cost the other cards.
List<String> normalizeKeycardUids(Iterable<String> raw) {
  final out = <String>[];
  for (final r in raw) {
    final uid = normalizeKeycardUid(r);
    if (uid != null && !out.contains(uid)) out.add(uid);
  }
  return out;
}

/// Splits one argument value: `--keycards=A,B C` names three cards.
List<String> splitKeycardArg(String value) =>
    value.split(RegExp(r'[,;\s]+')).where((s) => s.isNotEmpty).toList();

/// The lines of a keycard-service UID file (`authorized_uids.txt`), one UID
/// per line, blank lines and `#` comments ignored.
List<String> parseKeycardUidFile(String content) => normalizeKeycardUids(
      content
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty && !l.startsWith('#')),
    );

/// What the keycard step should add: the preset first, then the captured
/// cards, minus anything named twice.
List<String> keycardsToAdd({
  required Iterable<String> preset,
  required Iterable<String> captured,
}) =>
    normalizeKeycardUids([...preset, ...captured]);
