import 'dart:io';
import 'package:flutter/material.dart';
import 'services/services.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Check and request elevation on startup
  if (!await ElevationService.isElevated()) {
    final elevated = await ElevationService.elevateIfNeeded();
    if (elevated) {
      // Successfully launched elevated process, exit this one
      exit(0);
    }
    // Failed to elevate - continue anyway but warn user
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
