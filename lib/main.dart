import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';
import 'services/services.dart';
import 'screens/installer_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('CWD: ${Directory.current.path}');

  // In debug, do not self-relaunch for elevation because it breaks
  // `flutter run` debugger attachment.
  if (!kDebugMode) {
    if (!await ElevationService.isElevated()) {
      final elevated = await ElevationService.elevateIfNeeded();
      if (elevated) {
        // Successfully launched elevated process, exit this one.
        exit(0);
      }
      // Failed to elevate - continue anyway but warn user.
    }
  } else {
    debugPrint('Elevation auto-relaunch disabled in debug mode');
  }

  runApp(const LibreScootInstaller());
}

class LibreScootInstaller extends StatelessWidget {
  const LibreScootInstaller({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LibreScoot Installer',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const InstallerScreen(),
    );
  }
}
