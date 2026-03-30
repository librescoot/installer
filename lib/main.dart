import 'dart:io';
import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';
import 'screens/installer_screen.dart';

/// CLI args passed from unelevated → elevated process.
class LaunchArgs {
  final String? channel;
  final String? region;
  final String? lang;
  final bool autoStart;
  final bool dryRun;

  LaunchArgs({this.channel, this.region, this.lang, this.autoStart = false, this.dryRun = false});

  factory LaunchArgs.fromArgs(List<String> args) {
    String? channel, region, lang;
    var autoStart = false;
    var dryRun = false;
    for (final arg in args) {
      if (arg.startsWith('--channel=')) channel = arg.split('=')[1];
      if (arg.startsWith('--region=')) region = arg.split('=')[1];
      if (arg.startsWith('--lang=')) lang = arg.split('=')[1];
      if (arg == '--auto-start') autoStart = true;
      if (arg == '--dry-run') dryRun = true;
    }
    return LaunchArgs(channel: channel, region: region, lang: lang, autoStart: autoStart, dryRun: dryRun);
  }

  List<String> toArgs() => [
        if (channel != null) '--channel=$channel',
        if (region != null) '--region=$region',
        if (lang != null) '--lang=$lang',
        if (dryRun) '--dry-run',
        '--auto-start',
      ];
}

late final LaunchArgs launchArgs;

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  launchArgs = LaunchArgs.fromArgs(args);

  // If we were launched as the elevated process, bring ourselves to front
  if (launchArgs.autoStart && Platform.isMacOS) {
    // Small delay to let the window render, then activate
    Future.delayed(const Duration(seconds: 1), () {
      Process.run('osascript', [
        '-e',
        'tell application "System Events" to set frontmost of '
            'process "librescoot_installer" to true',
      ]);
    });
  }

  runApp(const LibreScootInstaller());
}

class LibreScootInstaller extends StatelessWidget {
  const LibreScootInstaller({super.key});

  @override
  Widget build(BuildContext context) {
    final localeOverride = launchArgs.lang != null ? Locale(launchArgs.lang!) : null;
    return MaterialApp(
      title: 'LibreScoot Installer',
      debugShowCheckedModeBanner: false,
      locale: localeOverride,
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
