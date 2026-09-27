import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/elevation_service.dart';

void main() {
  test(
    'portable elevation relaunches the wrapper, not its temporary child',
    () {
      final target = ElevationService.windowsRelaunchTarget(
        executable: r'C:\Temp\app\librescoot_installer.exe',
        executableArgs: const ['--flutter-arg'],
        extraArgs: const [
          '--auto-start',
          r'--osm-tiles=C:\My Maps\tiles.mbtiles',
        ],
        environment: const {
          'LIBRESCOOT_OUTER_WRAPPER_PATH': r'C:\Downloads\installer.exe',
        },
      );
      expect(target.$1, r'C:\Downloads\installer.exe');
      expect(target.$2, [
        '--auto-start',
        r'--osm-tiles=C:\My Maps\tiles.mbtiles',
      ]);
    },
  );

  test('standalone elevation relaunches the current executable', () {
    final target = ElevationService.windowsRelaunchTarget(
      executable: r'C:\app\librescoot_installer.exe',
      executableArgs: const ['--flutter-arg'],
      extraArgs: const ['--auto-start'],
      environment: const {},
    );
    expect(target.$1, r'C:\app\librescoot_installer.exe');
    expect(target.$2, ['--flutter-arg', '--auto-start']);
  });

  group('quoteWindowsArg', () {
    test('leaves arguments without spaces untouched', () {
      expect(ElevationService.quoteWindowsArg('--auto-start'), '--auto-start');
      expect(
        ElevationService.quoteWindowsArg(r'--log-file=C:\Logs\run.log'),
        r'--log-file=C:\Logs\run.log',
      );
    });

    test('wraps an argument holding a space', () {
      expect(
        ElevationService.quoteWindowsArg(
          r'--log-file=C:\Users\rider\Documents\Librescoot Installer\run.log',
        ),
        r'"--log-file=C:\Users\rider\Documents\Librescoot Installer\run.log"',
      );
    });

    test('doubles a trailing backslash run so it cannot escape the quote', () {
      expect(
        ElevationService.quoteWindowsArg(r'C:\a b\dir\'),
        r'"C:\a b\dir\\"',
      );
    });

    test('escapes embedded quotes and the backslashes in front of them', () {
      expect(ElevationService.quoteWindowsArg(r'say "hi"'), r'"say \"hi\""');
      expect(ElevationService.quoteWindowsArg(r'a b\"c'), r'"a b\\\"c"');
    });
  });
}
