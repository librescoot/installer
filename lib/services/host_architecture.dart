import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

/// `IMAGE_FILE_MACHINE_*` values, as the Windows loader reports them.
///
/// A process cannot tell which machine it is emulated on from its own widths;
/// `IsWow64Process2` is the API that answers it.
class WindowsMachine {
  const WindowsMachine._();

  static const int unknown = 0x0000;
  static const int i386 = 0x014C;
  static const int arm = 0x01C4;
  static const int amd64 = 0x8664;
  static const int arm64 = 0xAA64;
}

/// What this build is running on, and under what emulation.
enum HostArchVerdict {
  /// x64 build on an x64 kernel: the ordinary case.
  nativeX64,

  /// x64 build under Windows' ARM64 emulation: it runs, but slower, and the
  /// bundled RNDIS package carries no ARM64 section.
  x64OnArm64,

  /// ARM64 build on an ARM64 kernel. Not a build we ship today.
  nativeArm64,

  /// A 32-bit build, whatever the kernel. Not a build we ship either.
  process32Bit,

  notWindows,

  /// The query could not answer. Not evidence of emulation, so no warning.
  unknown,
}

/// Verdict for a process/native machine pair.
///
/// `IsWow64Process2` reports `unknown` as the process machine when nothing is
/// emulated, so that value means "same as native", not a machine of its own.
@visibleForTesting
HostArchVerdict interpretHostArchitecture({
  required int processMachine,
  required int nativeMachine,
}) {
  final process = processMachine == WindowsMachine.unknown
      ? nativeMachine
      : processMachine;
  if (nativeMachine == WindowsMachine.arm64) {
    return switch (process) {
      WindowsMachine.arm64 => HostArchVerdict.nativeArm64,
      WindowsMachine.amd64 => HostArchVerdict.x64OnArm64,
      _ => HostArchVerdict.process32Bit,
    };
  }
  if (nativeMachine == WindowsMachine.amd64) {
    return process == WindowsMachine.amd64
        ? HostArchVerdict.nativeX64
        : HostArchVerdict.process32Bit;
  }
  return HostArchVerdict.unknown;
}

HostArchVerdict? _cachedVerdict;

/// What this build is running on. Probed once; it cannot change at runtime.
HostArchVerdict detectHostArchitecture() {
  return _cachedVerdict ??= _probeHostArchitecture();
}

/// Drop the cached verdict. For tests; the machine does not change.
@visibleForTesting
void resetHostArchitectureForTest() => _cachedVerdict = null;

HostArchVerdict _probeHostArchitecture() {
  if (!Platform.isWindows) return HostArchVerdict.notWindows;

  final processMachine = calloc<Uint16>();
  final nativeMachine = calloc<Uint16>();
  try {
    final isWow64Process2 = DynamicLibrary.open('kernel32.dll')
        .lookupFunction<
          Int32 Function(IntPtr, Pointer<Uint16>, Pointer<Uint16>),
          int Function(int, Pointer<Uint16>, Pointer<Uint16>)
        >('IsWow64Process2');
    // GetCurrentProcess() is the pseudo-handle (HANDLE)-1.
    if (isWow64Process2(-1, processMachine, nativeMachine) == 0) {
      debugPrint('Host architecture: IsWow64Process2 failed');
      return HostArchVerdict.unknown;
    }
    final verdict = interpretHostArchitecture(
      processMachine: processMachine.value,
      nativeMachine: nativeMachine.value,
    );
    debugPrint(
      'Host architecture: native=0x${nativeMachine.value.toRadixString(16)}, '
      'process=0x${processMachine.value.toRadixString(16)} '
      '(${verdict.name})',
    );
    return verdict;
  } catch (e) {
    // No IsWow64Process2 (pre-1709), or a kernel32 without it.
    debugPrint('Host architecture: could not probe ($e)');
    return HostArchVerdict.unknown;
  } finally {
    calloc.free(processMachine);
    calloc.free(nativeMachine);
  }
}
