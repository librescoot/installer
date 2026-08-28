import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/network_service.dart';

/// `ip addr add` refusing because the address is already there means the
/// interface is configured, not that configuring it failed. Reading that as a
/// failure makes a working link look unconfigured on every reconnect after the
/// board reboots, which is exactly when the address is still on the interface.
void main() {
  test('the kernel EEXIST wording counts as already configured', () {
    expect(
      NetworkService.addressAlreadyAssigned(
          'RTNETLINK answers: File exists\n'),
      isTrue,
    );
  });

  test("iproute2's own validation wording counts as already configured", () {
    expect(
      NetworkService.addressAlreadyAssigned(
          'Error: ipv4: Address already assigned.\n'),
      isTrue,
    );
  });

  test('the match does not depend on capitalisation', () {
    expect(
      NetworkService.addressAlreadyAssigned('error: IPV4: ADDRESS ALREADY ASSIGNED.'),
      isTrue,
    );
  });

  test('a real failure is still a failure', () {
    for (final stderr in [
      'Error: argument "192.168.7.50/24" is wrong: invalid prefix\n',
      'Cannot find device "enx000000000000"\n',
      'RTNETLINK answers: Operation not permitted\n',
      '',
    ]) {
      expect(NetworkService.addressAlreadyAssigned(stderr), isFalse,
          reason: 'should not swallow: $stderr');
    }
  });
}
