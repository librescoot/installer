import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Widget tests ship no real fonts, so anything rendered to a file comes out
/// as empty boxes. Loading a system face under the default family makes a
/// golden readable, which is the whole point of writing one: to look at it.
///
/// A screen can be rendered and looked at in about three seconds this way.
/// The alternative is a release build, a copy to the test laptop, a launch
/// and a walk through the flow with a mouse, which is minutes per glance.
Future<void> loadRealFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  const candidates = [
    '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
    '/usr/share/fonts/TTF/DejaVuSans.ttf',
    '/System/Library/Fonts/Helvetica.ttc',
  ];
  final path = candidates.firstWhere((p) => File(p).existsSync(),
      orElse: () => throw StateError('no system font found for goldens'));
  final bytes = File(path).readAsBytesSync();
  for (final family in ['Roboto', 'monospace', 'IBM Plex Sans']) {
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
  }
  await _loadIcons();
}

/// The icon face, from the SDK the test is running under. Without it every
/// icon in a golden is an empty box, and an empty box looks exactly like an
/// icon that got dropped.
Future<void> _loadIcons() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  final candidates = [
    if (root != null)
      '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    '/home/teal/src/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ];
  for (final path in candidates) {
    final file = File(path);
    if (!file.existsSync()) continue;
    final loader = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.view(file.readAsBytesSync().buffer)));
    await loader.load();
    return;
  }
}
