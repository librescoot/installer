import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/models/finish_handover.dart';

/// The laptop-side finish is for the runs the device did not close out
/// itself. Running it when the cable is on the dashboard cannot work and
/// leaves the user watching a wait that never lands.
void main() {
  FinishHandover call({
    bool dryRun = false,
    bool linkUp = true,
    bool deviceArmed = true,
    bool? deviceReported = false,
  }) =>
      finishHandover(
        dryRun: dryRun,
        linkUp: linkUp,
        deviceArmed: deviceArmed,
        deviceReported: deviceReported,
      );

  test('an armed run that reported back needs nothing from the laptop', () {
    expect(call(deviceReported: true), FinishHandover.none);
  });

  test('an armed run that failed still needs the laptop finish', () {
    expect(call(deviceReported: false), FinishHandover.run);
  });

  test('no answer means no link, and the handover needs one', () {
    // The cable is on the dashboard: the client may still believe it is
    // connected, but nothing sent over that session arrives.
    expect(call(deviceReported: null), FinishHandover.none);
    expect(call(deviceReported: null, deviceArmed: false), FinishHandover.none);
  });

  test('a run with no trampoline behind it is the laptop\'s to finish', () {
    expect(call(deviceArmed: false, deviceReported: false),
        FinishHandover.run);
  });

  test('a dry run and a dead link do nothing', () {
    expect(call(dryRun: true), FinishHandover.none);
    expect(call(linkUp: false), FinishHandover.none);
  });
}
