/// Free bytes on the filesystem holding the queried path, from `df -kP <path>`.
/// The POSIX `-P` form guarantees one line per filesystem, so the second line
/// is the answer and its fourth field is Available in 1024-byte blocks.
int? parseDfFreeBytes(String dfOutput) {
  final lines = dfOutput
      .trim()
      .split('\n')
      .where((l) => l.trim().isNotEmpty)
      .toList();
  if (lines.length < 2) return null;
  final fields = lines[1].trim().split(RegExp(r'\s+'));
  if (fields.length < 4) return null;
  final blocks = int.tryParse(fields[3]);
  return blocks == null ? null : blocks * 1024;
}

/// Parse /etc/os-release into a map, dropping comments and surrounding quotes.
Map<String, String> parseOsRelease(String content) {
  final out = <String, String>{};
  for (final raw in content.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final eq = line.indexOf('=');
    if (eq <= 0) continue;
    final key = line.substring(0, eq).trim();
    var value = line.substring(eq + 1).trim();
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")))) {
      value = value.substring(1, value.length - 1);
    }
    out[key] = value;
  }
  return out;
}
