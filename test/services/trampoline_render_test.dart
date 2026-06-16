import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/trampoline_service.dart';

void main() {
  // flutter test runs with cwd at the package root, so the asset is readable
  // directly from disk without the Flutter asset bundle.
  final template = File('assets/trampoline.sh.template').readAsStringSync();

  group('renderTrampoline', () {
    test('substitutes every placeholder', () {
      final out = renderTrampoline(
        template,
        dbcImagePath: '/data/installer/dbc.wic.gz',
        osmTilesFile: '/data/installer/berlin.osm.tiles',
        valhallaTilesFile: '/data/installer/berlin.valhalla.tiles',
        installTiles: true,
        targetDbcVersion: 'v1.2.3',
        forceDbcReflash: false,
      );
      expect(out.contains('{{'), isFalse);
      expect(out, contains('/data/installer/dbc.wic.gz'));
      expect(out, contains('v1.2.3'));
    });

    test('rendered script passes sh -n', () async {
      final out = renderTrampoline(template, dbcImagePath: '/data/installer/dbc.wic.gz');
      final tmp = File('${Directory.systemTemp.path}/trampoline_render_test.sh')
        ..writeAsStringSync(out);
      final res = await Process.run('sh', ['-n', tmp.path]);
      tmp.deleteSync();
      expect(res.exitCode, 0, reason: 'sh -n failed: ${res.stderr}');
    });

    test('no CRLF survives rendering', () {
      final out = renderTrampoline(template, dbcImagePath: '/x');
      expect(out.contains('\r'), isFalse);
    });
  });
}
