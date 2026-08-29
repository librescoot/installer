import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/relaunch_target.dart';

void main() {
  group('InstallAnotherRelaunch', () {
    test('uses the persistent NSIS wrapper on Windows', () {
      final relaunch = InstallAnotherRelaunch.forPlatform(
        isWindows: true,
        resolvedExecutable: r'C:\Temp\nsis\app\librescoot_installer.exe',
        environment: {
          outerWrapperPathEnvironment: r'C:\Users\me\Downloads\installer.exe',
        },
        languageCode: 'en',
      );

      expect(relaunch.executable, r'C:\Users\me\Downloads\installer.exe');
      expect(relaunch.arguments, ['--lang=en']);
    });

    test('falls back to the current executable without a wrapper path', () {
      final relaunch = InstallAnotherRelaunch.forPlatform(
        isWindows: true,
        resolvedExecutable: r'C:\Temp\nsis\app\librescoot_installer.exe',
        environment: const {},
        languageCode: 'de',
      );

      expect(relaunch.executable, r'C:\Temp\nsis\app\librescoot_installer.exe');
      expect(relaunch.arguments, ['--lang=de']);
    });

    test('keeps the current executable on other platforms', () {
      final relaunch = InstallAnotherRelaunch.forPlatform(
        isWindows: false,
        resolvedExecutable: '/opt/librescoot-installer',
        environment: {outerWrapperPathEnvironment: '/ignored/installer.exe'},
        languageCode: 'de',
      );

      expect(relaunch.executable, '/opt/librescoot-installer');
      expect(relaunch.arguments, ['--lang=de']);
    });
  });
}
