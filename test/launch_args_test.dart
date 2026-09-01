import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/main.dart';

void main() {
  test('keycards come from --keycard, repeated, and --keycards, listed', () {
    final args = LaunchArgs.fromArgs([
      '--keycard=46dcc300',
      '--keycards=161B4501,04:45:73:C2:7C:67:80',
      '--keycard=46DCC300',
    ]);
    expect(args.keycards, ['46DCC300', '161B4501', '044573C27C6780']);
  });

  test('the elevated relaunch carries the keycards along', () {
    final args = LaunchArgs.fromArgs(['--keycards=46DCC300,161B4501']);
    final relaunch = args.relaunchArgs(
      channelName: 'testing',
      regionSlug: null,
      wantsOfflineMaps: true,
    );
    expect(relaunch, contains('--keycards=46DCC300,161B4501'));
  });
}
