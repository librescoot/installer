import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/host_architecture.dart';

void main() {
  group('an emulated x64 build is told apart from a native one', () {
    test('x64 process on an ARM64 kernel is the emulated case', () {
      expect(
        interpretHostArchitecture(
          processMachine: WindowsMachine.amd64,
          nativeMachine: WindowsMachine.arm64,
        ),
        HostArchVerdict.x64OnArm64,
      );
    });

    test('unknown as the process machine means "not emulated"', () {
      // IsWow64Process2 reports IMAGE_FILE_MACHINE_UNKNOWN when nothing is
      // emulated, so reading it as a machine of its own would call every
      // native build a 32-bit one.
      expect(
        interpretHostArchitecture(
          processMachine: WindowsMachine.unknown,
          nativeMachine: WindowsMachine.amd64,
        ),
        HostArchVerdict.nativeX64,
      );
      expect(
        interpretHostArchitecture(
          processMachine: WindowsMachine.unknown,
          nativeMachine: WindowsMachine.arm64,
        ),
        HostArchVerdict.nativeArm64,
      );
    });

    test('a 32-bit build on either kernel is still a 32-bit build', () {
      for (final native in [WindowsMachine.amd64, WindowsMachine.arm64]) {
        expect(
          interpretHostArchitecture(
            processMachine: WindowsMachine.i386,
            nativeMachine: native,
          ),
          HostArchVerdict.process32Bit,
        );
      }
    });

    test('an unrecognised kernel is unknown, not a warning', () {
      expect(
        interpretHostArchitecture(
          processMachine: WindowsMachine.i386,
          nativeMachine: WindowsMachine.i386,
        ),
        HostArchVerdict.unknown,
      );
      expect(
        interpretHostArchitecture(
          processMachine: WindowsMachine.arm,
          nativeMachine: 0xFFFF,
        ),
        HostArchVerdict.unknown,
      );
    });
  });

  group('the probe itself', () {
    test('off Windows it answers notWindows without touching kernel32', () {
      resetHostArchitectureForTest();
      expect(
        detectHostArchitecture(),
        Platform.isWindows
            ? isNot(HostArchVerdict.notWindows)
            : HostArchVerdict.notWindows,
      );
    });

    test('the answer is cached, because the machine cannot change', () {
      resetHostArchitectureForTest();
      final first = detectHostArchitecture();
      expect(detectHostArchitecture(), first);
    });
  });
}
