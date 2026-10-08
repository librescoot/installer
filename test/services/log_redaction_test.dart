import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/main.dart'
    show appendLog, appendLogRaw, installerLog;
import 'package:librescoot_installer/services/log_redaction.dart';

void main() {
  test(
    'keycard commands, events, JSON and launch arguments hide entire UIDs',
    () {
      for (final message in [
        'UI: add:044573C27C6780 -> ok',
        'UI: keycard event: card-learned:044573c27c6780',
        'UI: keycard event: master-learned:DEADBEEF',
        'rejected:already-authorized:0123456789ABCDEF0123',
        '{"uid":"044573C27C6780","count":2}',
        'arguments: --keycards=DEADBEEF,044573C27C6780 --lang=de',
        'keycard UID=04:45:73:c2:7c:67:80 count=2',
        'keycard UID=0445 73c2 7c6780 count=2',
        '044573C27C6780\nDEADBEEF\n',
      ]) {
        final redacted = redactLogMessage(message);
        expect(redacted, isNot(contains('044573')));
        expect(redacted, isNot(contains('DEADBEEF')));
        expect(redacted, isNot(contains('0123456789ABCDEF0123')));
        expect(redacted, isNot(contains('04:45:73')));
        expect(redacted, isNot(contains('0445 73')));
        expect(redacted, contains('[keycard UID]'));
        expect(redactLogMessage(redacted), redacted);
      }
    },
  );

  test('phone credential IDs in keycard events are masked', () {
    const credential = '0123456789ABCDEF0123456789ABCDEF';
    for (final event in ['phone-learned', 'phone-duplicate', 'phone-added']) {
      final redacted = redactLogMessage(
        'UI: keycard event: $event:$credential',
      );
      expect(redacted, 'UI: keycard event: $event:[keycard UID]');
    }
  });

  test(
    'MAC addresses are masked in network output and Bluetooth device paths',
    () {
      for (final message in [
        'UI: BLE MAC AA:BB:CC:DD:EE:FF',
        'link/ether aa:bb:cc:dd:ee:ff brd ff:ff:ff:ff:ff:ff',
        'Physical Address: AA-BB-CC-DD-EE-FF',
        '/org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF',
        r'BTHLE\DEV_AABBCCDDEEFF',
        'ble mac-address=aabbccddeeff',
      ]) {
        final redacted = redactLogMessage(message);
        expect(redacted.toLowerCase(), isNot(contains('aabbccddeeff')));
        expect(redacted.toLowerCase(), isNot(contains('aa:bb:cc')));
        expect(redacted.toLowerCase(), isNot(contains('aa-bb-cc')));
        expect(redacted.toLowerCase(), isNot(contains('aa_bb_cc')));
        expect(redacted, contains('[Bluetooth MAC]'));
        expect(redactLogMessage(redacted), redacted);
      }
    },
  );

  test('diagnostic addresses, hashes, capacities and counts stay useful', () {
    const message =
        'SSH: host 192.168.7.1:22 dev usb0\n'
        'Flash: capacity=7818182656 version=20261006\n'
        'sha256=bf91e181f96308727170bed109770c533573a7d5\n'
        'UI: keycard authorized-count=2 master-count=1';
    expect(redactLogMessage(message), message);
  });

  test('in-app and clipboard source buffers only receive redacted copies', () {
    installerLog.clear();
    addTearDown(installerLog.clear);
    appendLog('UI: keycard event: card-learned:044573C27C6780');
    appendLogRaw('AA:BB:CC:DD:EE:FF');
    expect(installerLog.join('\n'), isNot(contains('044573C27C6780')));
    expect(installerLog.join('\n'), isNot(contains('AA:BB:CC:DD:EE:FF')));
    expect(installerLog.join('\n'), contains('[keycard UID]'));
    expect(installerLog.join('\n'), contains('[Bluetooth MAC]'));
  });
}
