import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/network_service.dart';

/// Windows creates the adapter before its connection object, so for the first
/// seconds after the board re-enumerates NetConnectionID is empty while Name is
/// already populated. Returning an interface named '' sent netsh a name it
/// could not match, which failed with "The filename, directory name, or volume
/// label syntax is incorrect" and cost a minute of the post-reboot reconnect.
void main() {
  group('parseWindowsAdapter', () {
    test('a fully created adapter is usable', () {
      final iface = NetworkService.parseWindowsAdapter(
        'USB Ethernet/RNDIS Gadget\tEthernet 9\tTrue\n',
      );
      expect(iface, isNotNull);
      expect(iface!.name, 'Ethernet 9');
      expect(iface.displayName, 'USB Ethernet/RNDIS Gadget');
      expect(iface.isUp, isTrue);
    });

    test('live adapter index survives a connection alias change', () {
      final iface = NetworkService.parseWindowsAdapter(
        'USB gadget\tEthernet 12\tTrue\t42\tUSB\\VID_0525&PID_A4A2\n',
      );
      expect(iface!.index, 42);
      expect(iface.name, 'Ethernet 12');
    });

    test('malformed indices and ambiguous rows are rejected', () {
      for (final row in [
        'USB\tEthernet\tTrue\t0',
        'USB\tEthernet\tTrue\tbad',
        'USB\tEthernet\tTrue\t42\nUSB\tEthernet 2\tTrue\t43',
      ]) {
        expect(NetworkService.parseWindowsAdapter(row), isNull);
      }
    });

    test('adapter query uses the live stack and refuses multiple gadgets', () {
      expect(NetworkService.windowsAdapterQuery, contains('Get-NetAdapter'));
      expect(
        NetworkService.windowsAdapterQuery,
        isNot(contains('Win32_NetworkAdapter')),
      );
      expect(
        NetworkService.windowsAdapterQuery,
        contains("Status -ne 'Not Present'"),
      );
      expect(
        NetworkService.windowsAdapterQuery,
        contains(r'$devices.Count -ne 1'),
      );
    });

    test('an adapter with no connection name yet is not ready', () {
      expect(
        NetworkService.parseWindowsAdapter(
          'USB Ethernet/RNDIS Gadget\t\tFalse\n',
        ),
        isNull,
      );
    });

    test('a whitespace-only connection name is not ready either', () {
      expect(
        NetworkService.parseWindowsAdapter(
          'USB Ethernet/RNDIS Gadget\t   \t\n',
        ),
        isNull,
      );
    });

    test('a row with no connection column at all is not ready', () {
      expect(
        NetworkService.parseWindowsAdapter('USB Ethernet/RNDIS Gadget\n'),
        isNull,
      );
    });

    test('no adapter at all is not ready', () {
      for (final out in ['', '   ', '\n\n']) {
        expect(NetworkService.parseWindowsAdapter(out), isNull, reason: out);
      }
    });

    test('a disabled adapter that has a name is still usable', () {
      // NetEnabled false is a link that is down, not an interface that cannot
      // be addressed. netsh configures it and the carrier follows.
      final iface = NetworkService.parseWindowsAdapter(
        'USB Ethernet/RNDIS Gadget\tEthernet 9\tFalse\n',
      );
      expect(iface, isNotNull);
      expect(iface!.name, 'Ethernet 9');
      expect(iface.isUp, isFalse);
    });
  });
}
