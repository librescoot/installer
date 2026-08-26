import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/network_service.dart';

/// `networksetup -setmanual` addresses a network *service*. The hardware port
/// is a different name that only usually matches it, and where it does not,
/// the call fails and the run falls through to an ifconfig that needs root.
void main() {
  const listing = '''
An asterisk (*) denotes that a network service is disabled.
(1) Wi-Fi
(Hardware Port: Wi-Fi, Device: en0)

(2) Scooter cable
(Hardware Port: AX88179A, Device: en7)

(*) Thunderbolt Bridge
(Hardware Port: Thunderbolt Bridge, Device: bridge0)

''';

  test('reads the service name, not the hardware port', () {
    expect(NetworkService.parseServiceOrder(listing, 'en7'), 'Scooter cable');
  });

  test('a disabled service still names something -setmanual accepts', () {
    expect(
      NetworkService.parseServiceOrder(listing, 'bridge0'),
      'Thunderbolt Bridge',
    );
  });

  test('an interface with no service of its own resolves to nothing', () {
    // en5 exists on the machine but macOS has published no service for it,
    // which is the ordinary state for a gadget the host has never seen.
    expect(NetworkService.parseServiceOrder(listing, 'en5'), isNull);
  });

  test('a device name is not matched by one it is a prefix of', () {
    // "Device: en0)" must not answer for a lookup of en, and en7 must not be
    // answered by a listing that only has en70.
    expect(NetworkService.parseServiceOrder(listing, 'en'), isNull);
  });
}
