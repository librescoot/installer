const mdbDataPartitionProbeCommand = r'''awk '
$2 == "/" { root = $1 }
$2 == "/data" { data = $1; type = $3 }
END {
  if (data == "/dev/mmcblk1p4" && data != root && type == "ext4") {
    printf "ready root=%s data=%s type=%s\n", root, data, type
  } else if (data == "") {
    printf "absent root=%s\n", root
  } else {
    printf "wrong root=%s data=%s type=%s\n", root, data, type
  }
}' /proc/mounts''';

enum DataPartitionProbeStatus { ready, absent, wrong }

class DataPartitionProbe {
  const DataPartitionProbe({required this.status, required this.diagnostic});

  final DataPartitionProbeStatus status;
  final String diagnostic;
}

DataPartitionProbe parseDataPartitionProbe(String output) {
  final diagnostic = output.trim();
  final status = switch (diagnostic.split(RegExp(r'\s+')).firstOrNull) {
    'ready' => DataPartitionProbeStatus.ready,
    'absent' => DataPartitionProbeStatus.absent,
    _ => DataPartitionProbeStatus.wrong,
  };
  return DataPartitionProbe(
    status: status,
    diagnostic: diagnostic.isEmpty ? 'empty probe response' : diagnostic,
  );
}

enum DataPartitionWaitResult { ready, cancelled }

class DataPartitionWaitException implements Exception {
  const DataPartitionWaitException({this.lastProbe, this.lastError});

  final DataPartitionProbe? lastProbe;
  final Object? lastError;

  @override
  String toString() {
    final detail =
        lastProbe?.diagnostic ?? lastError?.toString() ?? 'no response';
    return 'MDB /data did not mount as ext4 on /dev/mmcblk1p4. '
        'Last probe: $detail';
  }
}

typedef DataPartitionCommandRunner = Future<String> Function(String command);
typedef DataPartitionDelay = Future<void> Function(Duration duration);

Future<DataPartitionWaitResult> waitForMdbDataPartition({
  required DataPartitionCommandRunner runCommand,
  int maxAttempts = 60,
  Duration interval = const Duration(seconds: 5),
  DataPartitionDelay? delay,
  bool Function()? isCancelled,
}) async {
  if (maxAttempts < 1) {
    throw ArgumentError.value(maxAttempts, 'maxAttempts', 'must be positive');
  }

  final wait = delay ?? (duration) => Future<void>.delayed(duration);
  DataPartitionProbe? lastProbe;
  Object? lastError;

  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    if (isCancelled?.call() ?? false) {
      return DataPartitionWaitResult.cancelled;
    }
    try {
      lastProbe = parseDataPartitionProbe(
        await runCommand(mdbDataPartitionProbeCommand),
      );
      lastError = null;
      if (lastProbe.status == DataPartitionProbeStatus.ready) {
        return DataPartitionWaitResult.ready;
      }
    } catch (error) {
      lastProbe = null;
      lastError = error;
    }

    if (isCancelled?.call() ?? false) {
      return DataPartitionWaitResult.cancelled;
    }
    if (attempt + 1 < maxAttempts) {
      await wait(interval);
    }
  }

  throw DataPartitionWaitException(lastProbe: lastProbe, lastError: lastError);
}
