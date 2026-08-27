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

  test('no answer means no link, and what that costs depends on the run', () {
    // Armed: the cable is on the dashboard, the client may still believe it is
    // connected, and the device closes itself out. Nothing owed.
    expect(call(deviceReported: null), FinishHandover.none);

    // Not armed: the link never moved, so this is a question that could not be
    // put rather than a session that was expected to be gone. The finish is
    // the whole install on this route, and calling it "nothing to do" left the
    // owner reassembling a scooter with a staged artifact and no phase queued
    // to install it.
    expect(call(deviceReported: null, deviceArmed: false),
        FinishHandover.blocked);
  });

  test('a run with no trampoline behind it is the laptop\'s to finish', () {
    expect(call(deviceArmed: false, deviceReported: false),
        FinishHandover.run);
  });

  test('a dry run owes nothing: nothing was staged', () {
    expect(call(dryRun: true), FinishHandover.none);
    expect(call(dryRun: true, deviceArmed: false), FinishHandover.none);
  });

  test('a dead link is finished when armed and blocked when not', () {
    expect(call(linkUp: false), FinishHandover.none);
    expect(call(linkUp: false, deviceArmed: false), FinishHandover.blocked);
  });
}
