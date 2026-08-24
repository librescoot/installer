import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/screens/installer_screen.dart';

/// The last screen tells the user what to do with the cable, and there is only
/// one USB port on the board to do it with. Getting this backwards sends
/// someone looking for screws on a plug that is not in the socket.
void main() {
  test('a board the laptop can see has the laptop cable in it', () {
    // Even after a device-run finish: plugging the laptop back in to read a
    // log means the dashboard cable came out again.
    expect(
      dashboardCableIsBack(laptopSeesBoard: true, deviceFinishArmed: true),
      isFalse,
    );
    expect(
      dashboardCableIsBack(laptopSeesBoard: true, deviceFinishArmed: false),
      isFalse,
    );
  });

  test('no link plus an armed device finish means the swap happened', () {
    expect(
      dashboardCableIsBack(laptopSeesBoard: false, deviceFinishArmed: true),
      isTrue,
    );
  });

  test('no link on its own proves nothing', () {
    // An attended run that simply lost the link still has the laptop cable
    // hanging out of the footwell.
    expect(
      dashboardCableIsBack(laptopSeesBoard: false, deviceFinishArmed: false),
      isFalse,
    );
  });
}
