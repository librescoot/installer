import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/models/install_plan.dart';

/// Keeping /data across an install is only safe while the services that will
/// read it are at least as new as the ones that wrote it. Going backwards, or
/// sideways into another channel, is what the plan screen has to warn about.
void main() {
  VersionDirection dir(String? a, String? b) =>
      InstallPlan.versionDirection(a, b);

  test('a newer build of the same channel is an upgrade', () {
    expect(dir('nightly-20260801t020747', 'nightly-20260822t020747'),
        VersionDirection.newer);
    expect(dir('1.2.0', '1.2.1'), VersionDirection.newer);
    expect(dir('1.2.1', '2.0.0'), VersionDirection.newer);
  });

  test('an older build of the same channel is a downgrade', () {
    expect(dir('nightly-20260822t020747', 'nightly-20260801t020747'),
        VersionDirection.older);
    expect(dir('1.2.1', '1.2.0'), VersionDirection.older);
    expect(dir('2.0.0', '1.9.9'), VersionDirection.older);
  });

  test('the same version either way is same', () {
    expect(dir('1.2.1', '1.2.1'), VersionDirection.same);
    expect(dir('v1.2.1', '1.2.1'), VersionDirection.same);
    expect(dir('nightly-20260822t020747', 'NIGHTLY-20260822T020747'),
        VersionDirection.same);
  });

  test('crossing channels is flagged as its own case, not as an upgrade', () {
    // This is the one the user asks for by name: a scooter on nightly being
    // put back onto stable. Neither version is straightforwardly ahead, and
    // the service set changes either way.
    expect(dir('nightly-20260822t020747', '1.2.1'),
        VersionDirection.otherChannel);
    expect(dir('1.2.1', 'nightly-20260822t020747'),
        VersionDirection.otherChannel);
    expect(dir('testing-20260812t141035', 'nightly-20260822t020747'),
        VersionDirection.otherChannel);
  });

  test('an unreadable version is unknown, never assumed safe', () {
    for (final pair in [
      [null, '1.2.1'],
      ['1.2.1', null],
      ['', '1.2.1'],
      ['garbage', '1.2.1'],
      ['1.2.1', 'garbage'],
    ]) {
      expect(dir(pair[0], pair[1]), VersionDirection.unknown,
          reason: 'pair: $pair');
    }
  });

  test('channelOf reads the channel off the version string', () {
    expect(InstallPlan.channelOf('nightly-20260822t020747'), 'nightly');
    expect(InstallPlan.channelOf('testing-20260812t141035'), 'testing');
    expect(InstallPlan.channelOf('v1.2.1'), 'stable');
    expect(InstallPlan.channelOf('1.2'), 'stable');
    expect(InstallPlan.channelOf('garbage'), isNull);
    expect(InstallPlan.channelOf(null), isNull);
  });
}
