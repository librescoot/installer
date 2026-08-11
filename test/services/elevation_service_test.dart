import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/elevation_service.dart';

void main() {
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
      expect(
        ElevationService.quoteWindowsArg(r'say "hi"'),
        r'"say \"hi\""',
      );
      expect(
        ElevationService.quoteWindowsArg(r'a b\"c'),
        r'"a b\\\"c"',
      );
    });
  });
}
