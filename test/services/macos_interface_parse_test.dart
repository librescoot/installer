import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/network_service.dart';

/// A Mac that already has a network: loopback with 127.0.0.1, Wi-Fi with a
/// lease, a Thunderbolt bridge that is up but idle, one built-in port that is
/// down, and en5, the freshly attached gadget with no address yet.
const busyMac = '''
lo0: flags=8049<UP,LOOPBACK,RUNNING,MULTICAST> mtu 16384
\toptions=1203<RXCSUM,TXCSUM,TXSTATUS,SW_TIMESTAMP>
\tinet 127.0.0.1 netmask 0xff000000
\tinet6 ::1 prefixlen 128
\tnd6 options=201<PERFORMNUD,DAD>
en0: flags=8863<UP,BROADCAST,SMART,RUNNING,SIMPLEX,MULTICAST> mtu 1500
\toptions=400<CHANNEL_IO>
\tether a4:83:e7:11:22:33
\tinet6 fe80::14b2:9f1a:2c3d:4e5f%en0 prefixlen 64 secured scopeid 0xc
\tinet 192.168.1.42 netmask 0xffffff00 broadcast 192.168.1.255
\tnd6 options=201<PERFORMNUD,DAD>
\tmedia: autoselect
\tstatus: active
en6: flags=8863<UP,BROADCAST,SMART,RUNNING,SIMPLEX,MULTICAST> mtu 1500
\toptions=460<TSO4,TSO6,CHANNEL_IO>
\tether 36:1f:88:aa:bb:cc
\tmedia: autoselect <full-duplex>
\tstatus: inactive
bridge0: flags=8863<UP,BROADCAST,SMART,RUNNING,SIMPLEX,MULTICAST> mtu 1500
\toptions=63<RXCSUM,TXCSUM,TSO4,TSO6>
\tether 36:1f:88:aa:bb:cd
\tConfiguration:
\t\tid 0:0:0:0:0:0 priority 0 hellotime 0 fwddelay 0
\tmedia: autoselect
\tstatus: active
en5: flags=8863<UP,BROADCAST,SMART,RUNNING,SIMPLEX,MULTICAST> mtu 1500
\toptions=400<CHANNEL_IO>
\tether 8e:44:12:00:11:22
\tinet6 fe80::8c44:12ff:fe00:1122%en5 prefixlen 64 scopeid 0x9
\tnd6 options=201<PERFORMNUD,DAD>
\tmedia: autoselect
\tstatus: active
''';

/// Same machine, further into a docked life: two unconfigured candidates, one
/// of them in double digits.
const doubleDigitMac = '''
lo0: flags=8049<UP,LOOPBACK,RUNNING,MULTICAST> mtu 16384
\tinet 127.0.0.1 netmask 0xff000000
en2: flags=8863<UP,BROADCAST,SMART,RUNNING,SIMPLEX,MULTICAST> mtu 1500
\tether 8e:44:12:00:11:33
\tmedia: autoselect
\tstatus: active
en10: flags=8863<UP,BROADCAST,SMART,RUNNING,SIMPLEX,MULTICAST> mtu 1500
\tether 8e:44:12:00:11:44
\tmedia: autoselect
\tstatus: active
''';

void main() {
  group('ifconfig -a parsing', () {
    test('a loopback address elsewhere does not disqualify a candidate', () {
      // The whole point: lo0 carries 127.0.0.1 on every Mac, and the previous
      // version tested for `inet ` across the entire dump.
      expect(
        NetworkService.unconfiguredActiveInterfaces(busyMac),
        contains('en5'),
      );
    });

    test('an interface with its own IPv4 is excluded', () {
      expect(
        NetworkService.unconfiguredActiveInterfaces(busyMac),
        isNot(contains('en0')),
      );
    });

    test('an inactive interface is excluded', () {
      expect(
        NetworkService.unconfiguredActiveInterfaces(busyMac),
        isNot(contains('en6')),
      );
    });

    test('an inet6 link-local address is not an IPv4 address', () {
      // en5 has fe80:: and nothing else; it must still qualify.
      const onlyLinkLocal = '''
en5: flags=8863<UP,BROADCAST,SMART,RUNNING,SIMPLEX,MULTICAST> mtu 1500
\tinet6 fe80::8c44:12ff:fe00:1122%en5 prefixlen 64 scopeid 0x9
\tstatus: active
''';
      expect(NetworkService.unconfiguredActiveInterfaces(onlyLinkLocal), [
        'en5',
      ]);
    });

    test('the last block in the output is still judged', () {
      // en5 is last in busyMac, so a parser that only closes a block when the
      // next header arrives would drop it.
      expect(NetworkService.unconfiguredActiveInterfaces(busyMac).last, 'en5');
    });

    test('empty output yields nothing', () {
      expect(NetworkService.unconfiguredActiveInterfaces(''), isEmpty);
    });
  });

  group('candidate selection', () {
    test('only the unconfigured gadget is picked out of a busy Mac', () {
      expect(NetworkService.newestUnconfiguredEthernet(busyMac), 'en5');
    });

    test('non-ethernet interfaces are not candidates', () {
      // bridge0 is active with no IPv4, so it survives the parse and has to be
      // dropped by the en filter rather than by luck.
      expect(
        NetworkService.unconfiguredActiveInterfaces(busyMac),
        contains('bridge0'),
      );
      expect(
        NetworkService.newestUnconfiguredEthernet(busyMac),
        isNot('bridge0'),
      );
    });

    test('en10 beats en2, which a text sort gets backwards', () {
      expect(NetworkService.newestUnconfiguredEthernet(doubleDigitMac), 'en10');
    });

    test('a Mac with nothing unconfigured yields null', () {
      const configured = '''
lo0: flags=8049<UP,LOOPBACK,RUNNING,MULTICAST> mtu 16384
\tinet 127.0.0.1 netmask 0xff000000
en0: flags=8863<UP,BROADCAST,SMART,RUNNING,SIMPLEX,MULTICAST> mtu 1500
\tinet 192.168.1.42 netmask 0xffffff00 broadcast 192.168.1.255
\tstatus: active
''';
      expect(NetworkService.newestUnconfiguredEthernet(configured), isNull);
    });
  });
}
