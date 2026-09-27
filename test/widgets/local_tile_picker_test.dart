import 'dart:convert';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/l10n/app_localizations.dart';
import 'package:librescoot_installer/models/local_tile_selection.dart';
import 'package:librescoot_installer/models/region.dart';
import 'package:librescoot_installer/theme.dart';
import 'package:librescoot_installer/widgets/local_tile_picker.dart';
import 'package:path/path.dart' as path;

import '../goldens/font_harness.dart';

void main() {
  setUpAll(loadRealFonts);
  late Directory dir;
  late File map;
  late File routing;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('local-tile-picker-');
    map = File(path.join(dir.path, 'tiles_custom.mbtiles'));
    routing = File(path.join(dir.path, 'valhalla_tiles_custom.tar.zst'));
    await map.writeAsBytes([...ascii.encode('SQLite format 3\u0000'), 1]);
    await routing.writeAsBytes([1, 2, 3]);
  });
  tearDown(() async => dir.delete(recursive: true));

  Widget host({
    required ValueChanged<Future<LocalTileChoice?>> onOpened,
    Future<List<String>?> Function()? pickFiles,
    Region? selectedRegion,
    LocalTileSelection? initialSelection,
  }) => MaterialApp(
    theme: librescootTheme(),
    locale: const Locale('de'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => onOpened(
            showDialog<LocalTileChoice>(
              context: context,
              builder: (_) => LocalTilePicker(
                regions: [Region.fromSlug('graz')],
                selectedRegion: selectedRegion,
                initialSelection: initialSelection,
                pickFiles: pickFiles,
                validateFiles: (_) async {},
              ),
            ),
          ),
          child: const Text('Open'),
        ),
      ),
    ),
  );

  testWidgets('browse accepts one map and downloads the missing routing file', (
    tester,
  ) async {
    late Future<LocalTileChoice?> result;
    final grazMap = map.renameSync(path.join(dir.path, 'tiles_graz.mbtiles'));
    await tester.pumpWidget(
      host(
        onOpened: (value) => result = value,
        selectedRegion: Region.fromSlug('graz'),
        pickFiles: () async => [grazMap.path],
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('local-tiles-pick')));
    await tester.pumpAndSettle();
    expect(find.text('tiles_graz.mbtiles'), findsOneWidget);
    expect(find.text('Wird heruntergeladen'), findsOneWidget);
    await tester.tap(find.text('Dateien verwenden'));
    await tester.pumpAndSettle();
    final choice = await result;
    expect(choice?.selection?.mapPath, grazMap.path);
    expect(choice?.selection?.routingPath, isNull);
    expect(choice?.region?.slug, 'graz');
  });

  testWidgets('drop accepts a custom pair and picks its region', (
    tester,
  ) async {
    late Future<LocalTileChoice?> result;
    await tester.pumpWidget(host(onOpened: (value) => result = value));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final target = tester.widget<DropTarget>(find.byType(DropTarget));
    target.onDragDone!(
      DropDoneDetails(
        files: [DropItemFile(map.path), DropItemFile(routing.path)],
        localPosition: Offset.zero,
        globalPosition: Offset.zero,
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Dateien verwenden'));
    await tester.pumpAndSettle();
    final choice = await result;
    expect(choice?.selection?.mapPath, map.path);
    expect(choice?.selection?.routingPath, routing.path);
    expect(choice?.region?.slug, 'custom');
  });

  testWidgets('custom region with one file asks for the other', (tester) async {
    late Future<LocalTileChoice?> result;
    await tester.pumpWidget(
      host(
        onOpened: (value) => result = value,
        pickFiles: () async => [map.path],
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('local-tiles-pick')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dateien verwenden'));
    await tester.pumpAndSettle();
    expect(
      find.text('Für eine eigene Region brauchst du beide Dateien.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(await result, isNull);
  });
}
