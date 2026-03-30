import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';
import 'screens/installer_screen.dart';

/// CLI args passed from unelevated → elevated process.
class LaunchArgs {
  final String? channel;
  final String? region;
  final bool autoStart;

  LaunchArgs({this.channel, this.region, this.autoStart = false});

  factory LaunchArgs.fromArgs(List<String> args) {
    String? channel, region;
    var autoStart = false;
    for (final arg in args) {
      if (arg.startsWith('--channel=')) channel = arg.split('=')[1];
      if (arg.startsWith('--region=')) region = arg.split('=')[1];
      if (arg == '--auto-start') autoStart = true;
    }
    return LaunchArgs(channel: channel, region: region, autoStart: autoStart);
  }

  List<String> toArgs() => [
        if (channel != null) '--channel=$channel',
        if (region != null) '--region=$region',
        '--auto-start',
      ];
}

late final LaunchArgs launchArgs;

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  launchArgs = LaunchArgs.fromArgs(args);
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
