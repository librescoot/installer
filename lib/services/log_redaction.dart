import '../models/keycard_preset.dart';

final _cardContext = RegExp(
  r'keycards?|\buids?\b|(?:card|master)-(?:learned|duplicate)|'
  r'already-authorized|(?:add|remove|set-master):|(?:authorized|master)_uids',
  caseSensitive: false,
);
final _hexToken = RegExp(
  r'(?<![a-z0-9])[0-9a-f]{8,64}(?![a-z0-9])',
  caseSensitive: false,
);
final _formattedUid = RegExp(
  r'(?<![a-z0-9])(?:[0-9a-f]{2})+(?:[ :\-]+(?:[0-9a-f]{2})+)+(?![a-z0-9])',
  caseSensitive: false,
);
final _byteIdentifier = RegExp(
  r'(?<![a-z0-9])(?:[0-9a-f]{2}[:_\-]){3,9}[0-9a-f]{2}(?![a-z0-9])',
  caseSensitive: false,
);
final _bluetoothContext = RegExp(
  r'\bble\b|bluetooth|mac[- ]?address|bthle|\bdev_',
  caseSensitive: false,
);
final _compactMac = RegExp(
  r'(?<![a-z0-9])[0-9a-f]{12}(?![a-z0-9])',
  caseSensitive: false,
);

/// Redacts log copies only; operational identifiers must remain unchanged.
String redactLogMessage(String message) =>
    message.split('\n').map(_redactLogLine).join('\n');

String _redactLogLine(String message) {
  var redacted = message;
  if (_cardContext.hasMatch(message)) {
    redacted = redacted.replaceAllMapped(_formattedUid, (match) {
      return normalizeKeycardUid(match[0]!) == null
          ? match[0]!
          : '[keycard UID]';
    });
    redacted = redacted.replaceAll(_hexToken, '[keycard UID]');
  }
  redacted = redacted.replaceAllMapped(_byteIdentifier, (match) {
    final bytes = match[0]!.replaceAll(RegExp(r'[:_\-]'), '');
    return bytes.length == 12 ? '[Bluetooth MAC]' : '[keycard UID]';
  });
  if (_bluetoothContext.hasMatch(message)) {
    redacted = redacted.replaceAll(_compactMac, '[Bluetooth MAC]');
  }
  // UID files and streamed command output can contain bare, unlabelled UIDs.
  return normalizeKeycardUid(redacted) == null ? redacted : '[keycard UID]';
}
