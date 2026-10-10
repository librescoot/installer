import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/elevation_service.dart';

void main() {
  test('the askpass reason is supplied by its caller', () {
    final flash = ElevationService.macOsAskpassScript('to write to the card');
    final network = ElevationService.macOsAskpassScript(
      'to set up the USB network',
    );
    expect(flash, contains('to write to the card'));
    expect(network, contains('to set up the USB network'));
  });
}
