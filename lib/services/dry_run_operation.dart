import '../models/substep.dart';
import 'critical_operation_coordinator.dart';
import 'trampoline_service.dart' show SubstepLabels;

typedef DryRunDelay = Future<void> Function();

class DryRunReconnectOperation {
  const DryRunReconnectOperation();

  Future<void> execute({
    required DryRunDelay delay,
    required bool Function() owns,
    required void Function() onOwned,
  }) async {
    await delay();
    if (owns()) onOwned();
  }
}

class DryRunUploadOperation {
  const DryRunUploadOperation();

  Future<void> execute({
    required CriticalOperationCoordinator coordinator,
    required DryRunDelay delay,
    required bool Function() owns,
    required void Function() onOwned,
  }) async {
    final lease = coordinator.acquire();
    try {
      await delay();
      if (owns()) onOwned();
    } finally {
      lease.release();
    }
  }
}

/// A file the dry run pretends to stage on the MDB, with the size it reports.
class DryRunFile {
  const DryRunFile(this.name, this.bytes);

  final String name;
  final int bytes;
}

/// Walks the substeps a real dashboard staging run reports: the existence
/// check, one upload per file with a byte count and time remaining, then the
/// tools and the script. Time is shared out by file size, so the dry run shows
/// the same list moving at plausible relative speeds instead of a bare wait.
///
/// Stops as soon as [owns] turns false, leaving the last reported state.
Future<void> simulateDryRunUpload({
  required List<DryRunFile> files,
  required bool stagesImage,
  required SubstepLabels labels,
  required void Function(List<Substep> steps) onSubsteps,
  required void Function(String status, double progress) onProgress,
  required bool Function() owns,
  Duration total = const Duration(seconds: 90),
  Duration tick = const Duration(milliseconds: 500),
  Future<void> Function(Duration) sleep = _sleep,
}) async {
  final steps = <Substep>[
    Substep(id: 'check', label: labels.checkExisting),
    for (final f in files)
      Substep(id: 'up:${f.name}', label: labels.uploadFile(f.name)),
    if (stagesImage) Substep(id: 'flasher', label: labels.uploadFlasher),
    if (stagesImage) Substep(id: 'fwtools', label: labels.uploadFwTools),
    Substep(id: 'script', label: labels.uploadScript),
  ];
  void set(String id, SubstepState state, {String? detail}) {
    final i = steps.indexWhere((s) => s.id == id);
    steps[i] = steps[i].copyWith(state: state, detail: detail);
    onSubsteps(List.unmodifiable(steps));
  }

  final totalBytes = files.fold<int>(0, (sum, f) => sum + f.bytes);
  final ticks = (total.inMilliseconds / tick.inMilliseconds).floor();
  // A small fixed share for the check and the tools; the rest follows bytes.
  final fixedTicks = (ticks * 0.04).ceil();
  final uploadTicks = ticks - fixedTicks * (stagesImage ? 4 : 2);

  Future<bool> hold(int count) async {
    for (var i = 0; i < count; i++) {
      await sleep(tick);
      if (!owns()) return false;
    }
    return true;
  }

  onSubsteps(List.unmodifiable(steps));
  onProgress(labels.starting, 0);
  set('check', SubstepState.active);
  onProgress(labels.checkExisting, 0);
  if (!await hold(fixedTicks)) return;
  set('check', SubstepState.done);

  var sent = 0;
  var elapsedTicks = 0;
  for (final f in files) {
    final id = 'up:${f.name}';
    set(id, SubstepState.active);
    final share = totalBytes == 0
        ? 1
        : (uploadTicks * f.bytes / totalBytes).round().clamp(1, uploadTicks);
    for (var t = 1; t <= share; t++) {
      if (!await hold(1)) return;
      elapsedTicks++;
      final fileSent = f.bytes * t ~/ share;
      final overall = totalBytes == 0 ? 1.0 : (sent + fileSent) / totalBytes;
      final left = (uploadTicks - elapsedTicks) * tick.inMilliseconds ~/ 1000;
      final detail =
          '${fileSent ~/ (1024 * 1024)} / ${f.bytes ~/ (1024 * 1024)} MB, '
          '${labels.remaining(left ~/ 60, left % 60)}';
      set(id, SubstepState.active, detail: detail);
      onProgress('${labels.uploadFile(f.name)} - $detail', overall * 0.95);
    }
    sent += f.bytes;
    set(id, SubstepState.done);
  }

  for (final id in [
    if (stagesImage) 'flasher',
    if (stagesImage) 'fwtools',
    'script',
  ]) {
    set(id, SubstepState.active);
    if (!await hold(fixedTicks)) return;
    set(id, SubstepState.done);
  }
  onProgress(labels.complete, 1);
}

Future<void> _sleep(Duration d) => Future<void>.delayed(d);
