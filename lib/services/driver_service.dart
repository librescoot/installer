import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

/// Result of a driver installation attempt.
class DriverInstallResult {
  final bool success;
  final String? error;
  final bool alreadyInstalled;

  /// Windows could not swap the driver on a running device and wants a
  /// reboot to finish. The install did work; it just is not live yet.
  final bool rebootRequired;

  /// State of the device when we stopped trying. Carries the competing
  /// package on failure so the UI can name it.
  final DriverDiagnosis? diagnosis;

  const DriverInstallResult({
    required this.success,
    this.error,
    this.alreadyInstalled = false,
    this.rebootRequired = false,
    this.diagnosis,
  });

  factory DriverInstallResult.alreadyInstalled([DriverDiagnosis? d]) =>
      DriverInstallResult(
        success: true,
        alreadyInstalled: true,
        diagnosis: d,
      );

  factory DriverInstallResult.installed([DriverDiagnosis? d]) =>
      DriverInstallResult(success: true, diagnosis: d);

  factory DriverInstallResult.needsReboot([DriverDiagnosis? d]) =>
      DriverInstallResult(
        success: true,
        rebootRequired: true,
        diagnosis: d,
      );

  factory DriverInstallResult.failed(String error, [DriverDiagnosis? d]) =>
      DriverInstallResult(success: false, error: error, diagnosis: d);
}

/// Current binding state for the Librescoot ethernet device.
enum DriverBinding {
  /// Bound to a Net-class driver and running.
  correct,

  /// Bound to a non-Net driver (usbser/Ports, modem, ...) that claimed the
  /// device before our INF could take effect.
  wrongDriver,

  /// Enumerated, but no driver has been installed for it yet.
  noDriver,

  /// Bound, but Windows could not start it. A rejected signature looks
  /// exactly like this, and the device will never carry a packet, so this
  /// must not count as correct.
  deviceError,

  /// Not currently present.
  notPresent,

  /// The probe produced no usable answer, e.g. PowerShell is under
  /// Constrained Language Mode or blocked by policy. Kept distinct from
  /// notPresent so a failed query is never reported as a successful install.
  unknown,
}

/// Snapshot of the device's driver binding, used to decide whether a forced
/// rebind is needed during install.
class DriverDiagnosis {
  final DriverBinding state;
  final String? instanceId;
  final String? currentClass;
  final String? currentService;

  /// Windows CM_PROB_* code; 0 when the device is running.
  final int problemCode;

  /// INF bound to the device, e.g. `oem76.inf`.
  final String? boundInf;

  /// Ranking of every driver competing for the device. Populated only when
  /// the caller asked for it, since it costs another process spawn.
  final DeviceDriverReport? report;

  const DriverDiagnosis(
    this.state, {
    this.instanceId,
    this.currentClass,
    this.currentService,
    this.problemCode = 0,
    this.boundInf,
    this.report,
  });

  /// Whether the binding is usable for talking to the board.
  bool get isUsable => state == DriverBinding.correct;

  /// Another program forced a worse-ranked driver onto the device.
  bool get isHijacked => report?.isHijacked ?? false;

  /// The package that claimed the device, when one did.
  DriverCandidate? get hijacker => isHijacked ? report!.incumbent : null;

  DriverDiagnosis withReport(DeviceDriverReport? value) => DriverDiagnosis(
        state,
        instanceId: instanceId,
        currentClass: currentClass,
        currentService: currentService,
        problemCode: problemCode,
        boundInf: boundInf,
        report: value,
      );

  @override
  String toString() => 'DriverDiagnosis(${state.name}, class=$currentClass, '
      'service=$currentService, problem=$problemCode, inf=$boundInf, '
      'id=$instanceId)';
}

/// Captured output of a logged subprocess invocation.
class _RunResult {
  final int exitCode;
  final String stdout;
  final String stderr;

  _RunResult(this.exitCode, this.stdout, this.stderr);

  bool get ok => exitCode == 0;

  String get combined {
    final s = stderr.trim();
    final o = stdout.trim();
    if (s.isNotEmpty && o.isNotEmpty) return '$o\n$s';
    return s.isNotEmpty ? s : o;
  }
}

/// Outcome of a forced INF -> hardware-ID install via newdev.dll.
class _ForceInstallOutcome {
  final bool ok;
  final bool rebootRequired;
  final String detail;

  _ForceInstallOutcome(this.ok, this.rebootRequired, this.detail);
}

/// One driver package Windows considers a candidate for the device, as
/// reported by `pnputil /enum-devices ... /drivers /format xml`.
class DriverCandidate {
  final String infName;
  final String? originalName;
  final String? provider;
  final String? className;
  final String? driverVersion;
  final String? signer;
  final String? matchingDeviceId;

  /// Windows' driver rank. Lower is better. The low bits carry the index of
  /// the matching ID within the device's own ID list, and bit 0x2000 marks a
  /// match against a *compatible* ID rather than a hardware ID.
  final int rank;

  const DriverCandidate({
    required this.infName,
    required this.rank,
    this.originalName,
    this.provider,
    this.className,
    this.driverVersion,
    this.signer,
    this.matchingDeviceId,
  });

  /// Whether this package matched a compatible ID. A compatible-ID match can
  /// never outrank a hardware-ID match no matter how new its DriverVer is,
  /// because DriverVer only breaks ties within one rank.
  bool get isCompatMatch => (rank & 0x2000) != 0;

  /// Position of the matching ID in the device's hardware/compatible ID list.
  int get matchIndex => rank & 0xFFF;

  @override
  String toString() => 'DriverCandidate($infName, rank=0x'
      '${rank.toRadixString(16).padLeft(8, '0').toUpperCase()}, '
      'id=$matchingDeviceId)';
}

/// What Windows thinks about the device and every driver competing for it.
///
/// Built only from locale-independent data: the bound INF name, and integer
/// ranks. pnputil's `Driver Status` text ("Best Ranked / Installed") comes
/// from pnputil.exe.mui and is translated, so nothing here reads it.
class DeviceDriverReport {
  final String? instanceId;
  final String? description;

  /// Device setup class, e.g. `Net` when correctly bound, `Ports` when a
  /// serial driver has claimed it.
  final String? className;

  /// INF currently bound to the device, e.g. `oem76.inf`.
  final String? boundInf;

  final List<DriverCandidate> candidates;

  const DeviceDriverReport({
    required this.candidates,
    this.instanceId,
    this.description,
    this.className,
    this.boundInf,
  });

  /// The candidate that is actually bound right now.
  DriverCandidate? get incumbent {
    if (boundInf == null) return null;
    final target = boundInf!.toLowerCase();
    for (final c in candidates) {
      if (c.infName.toLowerCase() == target) return c;
    }
    return null;
  }

  /// The candidate Windows would pick if it ranked the device fresh.
  DriverCandidate? get bestRanked {
    if (candidates.isEmpty) return null;
    var best = candidates.first;
    for (final c in candidates) {
      if (c.rank < best.rank) best = c;
    }
    return best;
  }

  /// Something bound a worse-ranked driver than the one that should have won.
  /// Windows only does that when an installer forces it, so this is the
  /// signature of another program having claimed the device on purpose.
  bool get isHijacked {
    final held = incumbent;
    final best = bestRanked;
    if (held == null || best == null) return false;
    return held.rank > best.rank;
  }
}

typedef AutoPlayProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments,
);

class AutoPlayServiceLease {
  AutoPlayServiceLease({
    bool? isWindows,
    AutoPlayProcessRunner? runProcess,
  })  : _isWindows = isWindows ?? Platform.isWindows,
        _runProcess = runProcess ?? _defaultRunProcess;

  final bool _isWindows;
  final AutoPlayProcessRunner _runProcess;
  Future<void> _operations = Future<void>.value();
  bool _stateCaptured = false;
  bool _stoppedByInstaller = false;

  Future<void> suppress() => _enqueue(() async {
        if (!_isWindows || _stateCaptured) return;
        try {
          final status = await _runProcess(
            'powershell.exe',
            const [
              '-NoProfile',
              '-NonInteractive',
              '-Command',
              r'[int](Get-Service -Name "ShellHWDetection").Status',
            ],
          );
          if (status.exitCode != 0) return;
          final state = int.tryParse(status.stdout.toString().trim());
          if (state == null) return;
          _stateCaptured = true;
          if (state != 4) return;

          debugPrint('Driver: stopping ShellHWDetection service');
          final stopped = await _runProcess(
            'net',
            const ['stop', 'ShellHWDetection'],
          );
          _stoppedByInstaller = stopped.exitCode == 0;
        } catch (error) {
          debugPrint('Driver: failed to suppress AutoPlay: $error');
        }
      });

  Future<void> restore() => _enqueue(() async {
        if (!_isWindows || !_stateCaptured) return;
        if (_stoppedByInstaller) {
          try {
            debugPrint('Driver: starting ShellHWDetection service');
            final started = await _runProcess(
              'net',
              const ['start', 'ShellHWDetection'],
            );
            if (started.exitCode != 0) return;
          } catch (error) {
            debugPrint('Driver: failed to restore AutoPlay: $error');
            return;
          }
        }
        _stoppedByInstaller = false;
        _stateCaptured = false;
      });

  Future<void> _enqueue(Future<void> Function() operation) {
    final result = _operations.then((_) => operation());
    _operations = result.catchError((_) {});
    return result;
  }

  static const Duration _netCommandTimeout = Duration(seconds: 10);

  static Future<ProcessResult> _defaultRunProcess(
    String executable,
    List<String> arguments,
  ) async {
    Process? proc;
    try {
      proc = await Process.start(executable, arguments);
      final out = proc.stdout.transform(systemEncoding.decoder).join();
      final err = proc.stderr.transform(systemEncoding.decoder).join();
      final code = await proc.exitCode.timeout(_netCommandTimeout);
      return ProcessResult(proc.pid, code, await out, await err);
    } on TimeoutException {
      debugPrint('AutoPlay: $executable ${arguments.join(' ')} timed out');
      proc?.kill();
      return ProcessResult(proc?.pid ?? 0, -1, '', 'timed out');
    }
  }
}

/// Service for managing Windows RNDIS driver installation.
///
/// On Windows, the Librescoot MDB uses USB RNDIS (Ethernet over USB).
/// This service checks if the driver is installed and installs it if needed.
class DriverService {
  static const String _driverInfAsset = 'assets/drivers/RNDIS.inf';
  static const String _driverCatAsset = 'assets/drivers/rndis.cat';
  static const String _driverInfName = 'RNDIS.inf';
  static const String _driverCatName = 'rndis.cat';

  /// Hardware ID of the Librescoot ethernet device. Used for both PnP
  /// enumeration matching and as the target of forced INF installs.
  static const String _hardwareId = r'USB\VID_0525&PID_A4A2';
  static final AutoPlayServiceLease _autoPlay = AutoPlayServiceLease();

  /// Parse `pnputil /enum-devices /deviceid <id> /drivers /format xml`.
  ///
  /// Returns null when the output does not describe a device, so an empty or
  /// failed query can never be mistaken for a healthy one.
  @visibleForTesting
  static DeviceDriverReport? parseEnumDevicesXml(String xml) {
    final device = RegExp(
      r'<Device\s+InstanceId="([^"]*)"\s*>([\s\S]*?)</Device>',
    ).firstMatch(xml);
    if (device == null) return null;

    final instanceId = _decodeXmlEntities(device.group(1) ?? '');
    final body = device.group(2) ?? '';

    // Split at <MatchingDrivers> before reading anything. The candidate blocks
    // reuse the DriverName and ClassName element names, so a search over the
    // whole body would report a candidate's values as the device's.
    final split = body.indexOf('<MatchingDrivers>');
    final head = split >= 0 ? body.substring(0, split) : body;
    final tail = split >= 0 ? body.substring(split) : '';

    final candidates = <DriverCandidate>[];
    for (final block in RegExp(
      r'<DriverName\s+DriverName="([^"]*)"\s*>([\s\S]*?)</DriverName>',
    ).allMatches(tail)) {
      final infName = _decodeXmlEntities(block.group(1) ?? '');
      final fields = block.group(2) ?? '';
      final rank = int.tryParse(_xmlTag(fields, 'Rank') ?? '', radix: 16);
      if (infName.isEmpty || rank == null) continue;
      candidates.add(DriverCandidate(
        infName: infName,
        rank: rank,
        originalName: _xmlTag(fields, 'OriginalName'),
        provider: _xmlTag(fields, 'ProviderName'),
        className: _xmlTag(fields, 'ClassName'),
        driverVersion: _xmlTag(fields, 'DriverVersion'),
        signer: _xmlTag(fields, 'SignerName'),
        matchingDeviceId: _xmlTag(fields, 'MatchingDeviceId'),
      ));
    }

    return DeviceDriverReport(
      instanceId: instanceId.isEmpty ? null : instanceId,
      description: _xmlTag(head, 'DeviceDescription'),
      className: _xmlTag(head, 'ClassName'),
      boundInf: _xmlTag(head, 'DriverName'),
      candidates: candidates,
    );
  }

  /// Text of the first `<name>...</name>` element, entity-decoded. Null when
  /// the element is absent or empty.
  static String? _xmlTag(String source, String name) {
    final m = RegExp('<$name>([^<]*)</$name>').firstMatch(source);
    if (m == null) return null;
    final value = _decodeXmlEntities(m.group(1) ?? '').trim();
    return value.isEmpty ? null : value;
  }

  /// `&amp;` is decoded last so an encoded entity such as `&amp;lt;` does not
  /// get decoded twice.
  static String _decodeXmlEntities(String s) => s
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&amp;', '&');

  /// Marker the probe emits when the device is absent. PowerShell under
  /// Constrained Language Mode or AppLocker can exit 0 having produced
  /// nothing, and reading silence as "no device" reports a hijacked device
  /// as absent and the install as successful.
  static const String _absent = 'ABSENT';
  static const String _present = 'PRESENT';

  /// Diagnose the current driver binding for the Librescoot ethernet device.
  ///
  /// Reads class, service, CM_PROB_* code and bound INF in one probe. Pass
  /// [withRanking] to additionally ask pnputil which drivers compete for the
  /// device; that costs a second process, so the convergence poll leaves it
  /// off and only the decision points ask for it.
  static Future<DriverDiagnosis> diagnoseBinding({
    bool withRanking = false,
  }) async {
    if (!Platform.isWindows) {
      return const DriverDiagnosis(DriverBinding.correct);
    }

    const script = r"""
$ErrorActionPreference = 'Continue'
$d = Get-PnpDevice -PresentOnly | Where-Object { $_.InstanceId -like "*VID_0525&PID_A4A2*" } | Select-Object -First 1
if (-not $d) { Write-Output 'ABSENT'; exit 0 }
$svc = (Get-PnpDeviceProperty -InstanceId $d.InstanceId -KeyName 'DEVPKEY_Device_Service' -ErrorAction SilentlyContinue).Data
$pc  = (Get-PnpDeviceProperty -InstanceId $d.InstanceId -KeyName 'DEVPKEY_Device_ProblemCode' -ErrorAction SilentlyContinue).Data
$inf = (Get-PnpDeviceProperty -InstanceId $d.InstanceId -KeyName 'DEVPKEY_Device_DriverInfPath' -ErrorAction SilentlyContinue).Data
Write-Output "PRESENT`t$($d.InstanceId)`t$($d.Class)`t$svc`t$pc`t$inf"
""";

    final r = await _runLogged(
      'probe',
      'powershell',
      const ['-NoProfile', '-NonInteractive', '-Command', script],
      timeout: const Duration(seconds: 30),
    );

    var diagnosis = parseBindingProbe(r.exitCode, r.stdout);
    if (withRanking && diagnosis.state != DriverBinding.notPresent) {
      diagnosis = diagnosis.withReport(await fetchDriverReport());
    }
    return diagnosis;
  }

  /// Classify one probe result. Pure so the state machine can be tested
  /// without a Windows box.
  @visibleForTesting
  static DriverDiagnosis parseBindingProbe(int exitCode, String stdout) {
    if (exitCode != 0) return const DriverDiagnosis(DriverBinding.unknown);

    final line = stdout.trim();
    if (line == _absent) return const DriverDiagnosis(DriverBinding.notPresent);
    if (!line.startsWith('$_present\t')) {
      return const DriverDiagnosis(DriverBinding.unknown);
    }

    final parts = line.substring(_present.length + 1).split('\t');
    String at(int i) => i < parts.length ? parts[i].trim() : '';
    final instanceId = at(0);
    final cls = at(1).toLowerCase();
    final svc = at(2).toLowerCase();
    final problem = int.tryParse(at(3)) ?? 0;
    final inf = at(4);

    // CM_PROB_NOT_CONFIGURED and CM_PROB_FAILED_INSTALL both mean "no driver
    // yet", which is the easy case, not a broken one.
    const noDriverProblems = {1, 28};

    final DriverBinding state;
    if (cls.isEmpty ||
        cls == 'usbdevice' ||
        svc.isEmpty ||
        noDriverProblems.contains(problem)) {
      state = DriverBinding.noDriver;
    } else if (problem != 0) {
      state = DriverBinding.deviceError;
    } else if (cls == 'net') {
      // Any Net-class binding moves packets. Ours installs service USB_RNDIS
      // and Windows' in-box RNDIS6 installs usbrndis6, so testing the service
      // name would mean enumerating every driver that could legitimately win.
      state = DriverBinding.correct;
    } else {
      state = DriverBinding.wrongDriver;
    }

    return DriverDiagnosis(
      state,
      instanceId: instanceId.isEmpty ? null : instanceId,
      currentClass: cls.isEmpty ? null : cls,
      currentService: svc.isEmpty ? null : svc,
      problemCode: problem,
      boundInf: inf.isEmpty ? null : inf,
    );
  }

  /// Ask pnputil which drivers match the device and how Windows ranks them.
  /// Returns null when the query fails, which is treated as "no information"
  /// rather than "nothing is competing".
  static Future<DeviceDriverReport?> fetchDriverReport() async {
    if (!Platform.isWindows) return null;
    // /deviceid takes the hardware ID directly, so no instance path lookup is
    // needed, and the whole query works without elevation.
    final r = await _runLogged(
      'enum-devices',
      'pnputil',
      ['/enum-devices', '/deviceid', _hardwareId, '/drivers', '/format', 'xml'],
      timeout: const Duration(seconds: 30),
    );
    if (!r.ok) return null;
    return parseEnumDevicesXml(r.stdout);
  }

  /// Install the Librescoot RNDIS driver from bundled assets.
  ///
  /// Stages `RNDIS.inf` via `pnputil /add-driver /install` and, if a wrong
  /// driver (usbser, modem, …) had already claimed the device, forces a
  /// rebind by calling `newdev.dll!UpdateDriverForPlugAndPlayDevicesW` with
  /// `INSTALLFLAG_FORCE` against the hardware ID. Falls back to the legacy
  /// remove+scan rebind if the force install does not converge.
  static Future<DriverInstallResult> installDriver() async {
    if (!Platform.isWindows) {
      return DriverInstallResult.alreadyInstalled();
    }

    final pre = await diagnoseBinding(withRanking: true);
    debugPrint('Driver: pre-install diagnosis: $pre');

    if (pre.state == DriverBinding.correct) {
      return DriverInstallResult.alreadyInstalled(pre);
    }

    // A probe that could not answer is not a device that is fine. Reporting
    // success here let a hijacked device sail on into an unexplained SSH
    // timeout with no diagnosis anywhere.
    if (pre.state == DriverBinding.unknown) {
      return DriverInstallResult.failed(
        'Could not determine the driver binding for $_hardwareId. '
        'PowerShell may be restricted by policy on this machine.',
        pre,
      );
    }

    String? infPath;
    try {
      infPath = await _extractDriverFiles();
      debugPrint('Driver: extracted INF to $infPath');

      final add = await _runLogged(
        'pnputil-add',
        'pnputil',
        ['/add-driver', infPath, '/install'],
        runInShell: true,
        timeout: const Duration(seconds: 120),
      );
      if (!add.ok) {
        return DriverInstallResult.failed(
          'pnputil /add-driver failed (exit ${add.exitCode}): ${add.combined}',
          pre,
        );
      }

      // Nothing to rebind: the INF is staged and Windows will bind it when
      // the board is plugged in.
      if (pre.state == DriverBinding.notPresent) {
        debugPrint('Driver: device not present: INF staged for plug-in');
        return DriverInstallResult.installed(pre);
      }

      // /add-driver /install rebinds a matching device to the best-ranked
      // package, and ours outranks every compatible-ID claimer. That settles
      // the common case in well under a second, so check before reaching for
      // the forced install.
      var post = await _waitForCorrectBinding(const Duration(seconds: 10));
      if (post.state == DriverBinding.correct) {
        debugPrint('Driver: staging alone rebound the device');
        return DriverInstallResult.installed(post);
      }

      // Still wrong, so something forced a worse-ranked driver on. Force ours
      // back: this bypasses ranking entirely, which is the only way past an
      // incumbent that outranks us.
      var forced = await _forceInstallByHardwareId(infPath);
      debugPrint('Driver: force-install ok=${forced.ok} '
          'reboot=${forced.rebootRequired} detail=${forced.detail}');

      post = await _waitForCorrectBinding(_rebindBudget);
      if (post.state == DriverBinding.correct) {
        return DriverInstallResult.installed(post);
      }

      // Windows could not swap the driver under a running device. That is a
      // finished install waiting on a restart, not a failure.
      if (forced.rebootRequired) {
        return DriverInstallResult.needsReboot(post);
      }

      if (forced.ok) {
        // The call worked but the binding did not settle. Repeat it once
        // before doing anything destructive.
        forced = await _forceInstallByHardwareId(infPath);
        post = await _waitForCorrectBinding(_rebindBudget);
        if (post.state == DriverBinding.correct) {
          return DriverInstallResult.installed(post);
        }
        if (forced.rebootRequired) {
          return DriverInstallResult.needsReboot(post);
        }
      } else if (pre.instanceId != null) {
        // The forced install could not run at all, e.g. Add-Type is blocked
        // by Constrained Language Mode. Remove and re-scan so Windows ranks
        // the device again. Only worth doing here: ranking is what put the
        // wrong driver on, so it is a last resort, not a retry.
        debugPrint('Driver: force-install unavailable, '
            'falling back to remove+scan on ${pre.instanceId}');
        await _forceRebind(pre.instanceId!);
        post = await _waitForCorrectBinding(_rebindBudget);
        if (post.state == DriverBinding.correct) {
          return DriverInstallResult.installed(post);
        }
      }

      // Unplugged mid-install. Nothing is wrong with the driver.
      if (post.state == DriverBinding.notPresent) {
        return DriverInstallResult.installed(post);
      }

      final finalState = await diagnoseBinding(withRanking: true);
      return DriverInstallResult.failed(
        _describeFailure(finalState),
        finalState,
      );
    } catch (e) {
      return DriverInstallResult.failed('Failed to install driver: $e');
    } finally {
      if (infPath != null) {
        try {
          await Directory(path.dirname(infPath)).delete(recursive: true);
        } catch (_) {
          // Ignore cleanup errors
        }
      }
    }
  }

  /// How long to wait for a rebind to settle. A forced install took ~3.2s to
  /// return and the binding flipped ~1.8s later on a healthy machine, and a
  /// device restart or a driver search stretches that well past ten seconds.
  static const Duration _rebindBudget = Duration(seconds: 45);

  /// Short name for whatever is holding the device, for the sentence on the
  /// recovery screen.
  static String describeHolder(DriverDiagnosis d) {
    final held = d.report?.incumbent;
    if (held != null) {
      final provider = held.provider;
      if (provider != null && provider.isNotEmpty) {
        return '$provider (${held.infName})';
      }
      return held.infName;
    }
    return d.boundInf ?? d.currentService ?? 'another driver';
  }

  /// Copy-pasteable diagnostic block for a bug report or a forum post.
  ///
  /// Deliberately not translated: it is meant to be pasted verbatim, and the
  /// person reading it may not share the reporter's language.
  static String describeForSupport(DriverDiagnosis d) {
    final b = StringBuffer();
    b.writeln('Device:  ${d.instanceId ?? _hardwareId}');
    final problem =
        d.problemCode != 0 ? ' (problem code ${d.problemCode})' : '';
    b.writeln('State:   ${d.state.name}$problem');
    b.writeln('Class:   ${d.currentClass ?? '?'}');
    b.writeln('Service: ${d.currentService ?? '?'}');

    final held = d.report?.incumbent;
    if (held != null) {
      b.writeln('Bound:   ${_describeCandidate(held)}');
    } else if (d.boundInf != null) {
      b.writeln('Bound:   ${d.boundInf}');
    }

    final best = d.report?.bestRanked;
    if (best != null && best.infName != held?.infName) {
      b.writeln('Best:    ${_describeCandidate(best)}');
    }

    b.write('Check:   pnputil /enum-devices /deviceid "$_hardwareId" /drivers');
    return b.toString();
  }

  static String _describeCandidate(DriverCandidate c) {
    final parts = <String>[c.infName];
    if (c.provider != null) parts.add('(${c.provider})');
    if (c.driverVersion != null) parts.add(c.driverVersion!);
    parts.add('rank ${_hex(c.rank)}');
    if (c.matchingDeviceId != null) parts.add('via ${c.matchingDeviceId}');
    return parts.join(' ');
  }

  static String _hex(int v) =>
      '0x${v.toRadixString(16).padLeft(8, '0').toUpperCase()}';

  /// One line saying what is holding the device, for logs and for the screen
  /// the user ends up on.
  static String _describeFailure(DriverDiagnosis d) {
    final thief = d.hijacker;
    if (thief != null) {
      return 'Another driver has claimed the device: ${thief.infName}'
          '${thief.provider != null ? ' from ${thief.provider}' : ''} '
          '(class ${thief.className ?? '?'}). It is ranked below our driver, '
          'so it was installed deliberately by other software.';
    }
    if (d.state == DriverBinding.deviceError) {
      return 'The driver is bound but Windows could not start it '
          '(problem code ${d.problemCode}).';
    }
    return 'Driver staged but the binding is still ${d.state.name} '
        '(class=${d.currentClass}, service=${d.currentService}, '
        'inf=${d.boundInf}).';
  }

  /// Force the staged INF onto the Librescoot hardware ID via
  /// `newdev.dll!UpdateDriverForPlugAndPlayDevicesW` with `INSTALLFLAG_FORCE`
  /// (= 0x1). This is the documented "rebind regardless of current driver"
  /// API: equivalent to `devcon update`: and bypasses driver ranking.
  ///
  /// Caller must have already staged the INF via `pnputil /add-driver
  /// /install`. Requires admin (which the caller already has).
  static Future<_ForceInstallOutcome> _forceInstallByHardwareId(
    String infPath,
  ) async {
    // Pass paths/IDs through the environment so PowerShell never sees
    // backslashes or ampersands as syntax. The script reads them via
    // `$env:LIBRESCOOT_INF` / `$env:LIBRESCOOT_HWID`.
    const script = r'''
$ErrorActionPreference = 'Continue'
$inf  = $env:LIBRESCOOT_INF
$hwid = $env:LIBRESCOOT_HWID
if (-not $inf -or -not $hwid) {
    Write-Output "FAILED missing-env inf=$inf hwid=$hwid"
    exit 2
}
$src = @"
using System;
using System.Runtime.InteropServices;
public class NewDev {
    [DllImport("newdev.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    public static extern bool UpdateDriverForPlugAndPlayDevices(
        IntPtr hwndParent, string HardwareId, string FullInfPath,
        uint InstallFlags, out bool bRebootRequired);
}
"@
try {
    Add-Type -TypeDefinition $src -ErrorAction Stop
} catch {
    Write-Output "FAILED add-type $($_.Exception.Message)"
    exit 2
}
$reboot = $false
$ok = [NewDev]::UpdateDriverForPlugAndPlayDevices(
    [IntPtr]::Zero, $hwid, $inf, 1, [ref]$reboot
)
if ($ok) {
    Write-Output "OK reboot=$reboot"
    exit 0
} else {
    $gle = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
    $msg = (New-Object System.ComponentModel.Win32Exception $gle).Message
    Write-Output "FAILED gle=$gle msg=$msg"
    exit 1
}
''';

    final r = await _runLogged(
      'force-install',
      'powershell',
      ['-NoProfile', '-NonInteractive', '-Command', script],
      runInShell: false,
      environment: {
        'LIBRESCOOT_INF': infPath,
        'LIBRESCOOT_HWID': _hardwareId,
      },
    );
    final detail = r.combined.trim();
    final reboot = detail.contains('reboot=True');
    return _ForceInstallOutcome(
      r.ok,
      reboot,
      detail.isEmpty ? '(no output)' : detail,
    );
  }

  /// Remove the device node and trigger re-enumeration so the most-specific
  /// staged INF (ours) wins driver ranking. Falls back to a disable/enable
  /// cycle on Windows builds where `/remove-device` isn't available. Used as
  /// a last-ditch fallback when [_forceInstallByHardwareId] fails to converge.
  static Future<bool> _forceRebind(String instanceId) async {
    // /remove-device exists on Win10 2004+. Pass the InstanceId as a single
    // argv element with runInShell: false so cmd.exe never sees the embedded
    // '&' characters.
    final remove = await _runLogged(
      'pnputil-remove',
      'pnputil',
      ['/remove-device', instanceId],
      runInShell: false,
    );

    if (!remove.ok) {
      debugPrint(
        'Driver: pnputil /remove-device failed: '
        'falling back to disable/enable cycle',
      );
      // Fallback for older builds: bounce the device.
      await _runLogged(
        'disable-enable',
        'powershell',
        [
          '-NoProfile',
          '-Command',
          'Disable-PnpDevice -InstanceId "$instanceId" -Confirm:\$false; '
              'Start-Sleep -Milliseconds 500; '
              'Enable-PnpDevice  -InstanceId "$instanceId" -Confirm:\$false',
        ],
        runInShell: false,
      );
    }

    final scan = await _runLogged(
      'pnputil-scan',
      'pnputil',
      ['/scan-devices'],
      runInShell: true,
    );
    return scan.ok;
  }

  /// Poll [diagnoseBinding] until the binding is correct or [timeout]
  /// elapses, returning the most recent diagnosis either way.
  ///
  /// Each tick spawns a powershell.exe, which costs a second or two on its
  /// own, so the effective gap between samples is longer than [interval].
  static Future<DriverDiagnosis> _waitForCorrectBinding(
    Duration timeout, {
    Duration interval = const Duration(seconds: 2),
  }) async {
    final deadline = DateTime.now().add(timeout);
    DriverDiagnosis last = await diagnoseBinding();
    while (DateTime.now().isBefore(deadline)) {
      if (last.state == DriverBinding.correct) return last;
      await Future.delayed(interval);
      last = await diagnoseBinding();
    }
    return last;
  }

  /// Stop the ShellHWDetection service to prevent "format this disk" popups
  /// when the device enters USB Mass Storage mode.
  static Future<void> suppressAutoPlay() async {
    await _autoPlay.suppress();
  }

  /// Restore the ShellHWDetection state captured before UMS mode.
  static Future<void> restoreAutoPlay() async {
    await _autoPlay.restore();
  }

  /// Run a subprocess and pipe its stdout/stderr line-by-line into
  /// `debugPrint` under a labelled prefix so field logs make it obvious
  /// what each command did. Returns a [_RunResult] for callers that need to
  /// branch on the outcome.
  static Future<_RunResult> _runLogged(
    String label,
    String executable,
    List<String> args, {
    bool runInShell = false,
    Map<String, String>? environment,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    debugPrint('Driver[$label]: $executable ${args.join(' ')}');
    Process? proc;
    try {
      proc = await Process.start(
        executable,
        args,
        runInShell: runInShell,
        environment: environment,
      );
      // Drain both pipes before awaiting exit. A process that fills its stdout
      // buffer blocks forever if nobody is reading, which would turn the
      // timeout below into the normal path instead of the exceptional one.
      final outFuture = proc.stdout.transform(systemEncoding.decoder).join();
      final errFuture = proc.stderr.transform(systemEncoding.decoder).join();
      final exitCode = await proc.exitCode.timeout(timeout);
      final out = await outFuture;
      final err = await errFuture;
      debugPrint('Driver[$label]: exit=$exitCode');
      _logLines('Driver[$label]: stdout', out);
      _logLines('Driver[$label]: stderr', err);
      return _RunResult(exitCode, out, err);
    } on TimeoutException {
      // pnputil and newdev block indefinitely behind a "Windows Security:
      // install this device software?" prompt, and that prompt opens behind
      // the fullscreen installer where nobody can click it. Killing the child
      // turns a permanent hang into a reported failure.
      // Through the shell, the child is cmd.exe and the thing actually stuck
      // is pnputil underneath it. Killing the parent leaves that one hung on
      // the prompt, so take the whole tree.
      if (proc != null) {
        if (Platform.isWindows) {
          await Process.run('taskkill', ['/PID', '${proc.pid}', '/T', '/F']);
        } else {
          proc.kill(ProcessSignal.sigkill);
        }
      }
      final message = 'timed out after ${timeout.inSeconds}s';
      debugPrint('Driver[$label]: $message');
      return _RunResult(-1, '', message);
    } catch (e) {
      debugPrint('Driver[$label]: exception: $e');
      return _RunResult(-1, '', e.toString());
    }
  }

  static void _logLines(String prefix, String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return;
    for (final line in trimmed.split(RegExp(r'\r?\n'))) {
      final l = line.trimRight();
      if (l.isNotEmpty) debugPrint('$prefix: $l');
    }
  }

  /// Extract the driver INF and CAT from assets to a temp directory.
  static Future<String> _extractDriverFiles() async {
    // Create temp directory
    final tempDir = await Directory.systemTemp.createTemp('librescoot_driver_');

    // Extract INF
    final infContent = await rootBundle.loadString(_driverInfAsset);
    final infPath = path.join(tempDir.path, _driverInfName);
    await File(infPath).writeAsString(infContent);

    // Extract CAT (binary file)
    final catData = await rootBundle.load(_driverCatAsset);
    final catPath = path.join(tempDir.path, _driverCatName);
    await File(catPath).writeAsBytes(catData.buffer.asUint8List());

    return infPath;
  }
}
