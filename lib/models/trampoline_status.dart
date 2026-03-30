enum TrampolineResult { success, error, unknown }

class TrampolineStatus {
  TrampolineStatus({
    required this.result,
    this.message,
    this.errorLog,
  });

  final TrampolineResult result;
  final String? message;
  final String? errorLog;

  factory TrampolineStatus.parse(String content) {
    final lines = content.trim().split('\n');
    if (lines.isEmpty) return TrampolineStatus(result: TrampolineResult.unknown);

    final resultLine = lines.first.trim().toLowerCase();
    if (resultLine == 'success') {
      return TrampolineStatus(
        result: TrampolineResult.success,
        message: lines.length > 1 ? lines.sublist(1).join('\n') : null,
      );
    } else if (resultLine.startsWith('error')) {
      return TrampolineStatus(
        result: TrampolineResult.error,
        message: resultLine,
        errorLog: lines.length > 1 ? lines.sublist(1).join('\n') : null,
      );
    }
    return TrampolineStatus(result: TrampolineResult.unknown, message: content);
  }
}
