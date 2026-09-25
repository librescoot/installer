import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('welcome and offline-map plan use the same country-tab picker', () {
    final source = File('lib/screens/installer_screen.dart').readAsStringSync();
    expect(RegExp(r'RegionPicker\(').allMatches(source).length, 2);
    expect(source, contains('selectedRegion: _downloadState.selectedRegion'));
    expect(
      source,
      contains('onSelected: (region) => _updateDownloadSelection'),
    );
    expect(source, contains('maxRegionHeight: 240'));
    expect(
      source,
      contains('onSelected: (value) => refresh(() => region = value)'),
    );
    expect(source, isNot(contains('DropdownMenu<Region>')));
    expect(source, isNot(contains('DropdownButtonFormField<Region>')));
  });
}
