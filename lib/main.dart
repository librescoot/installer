import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';
import 'screens/installer_screen.dart';
import 'services/elevation_service.dart';
import 'theme.dart';

/// Global log buffer accessible from anywhere.
final List<String> installerLog = [];

/// CLI args passed from unelevated → elevated process.
class LaunchArgs {
  final String? channel;
  final String? region;
  final String? lang;
  final String? mdbImage;
  final String? dbcImage;
  final bool autoStart;
  final bool dryRun;

  LaunchArgs({this.channel, this.region, this.lang, this.mdbImage, this.dbcImage, this.autoStart = false, this.dryRun = false});

  factory LaunchArgs.fromArgs(List<String> args) {
    String? channel, region, lang, mdbImage, dbcImage;
    var autoStart = false;
    var dryRun = false;
    for (final arg in args) {
      if (arg.startsWith('--channel=')) channel = arg.split('=')[1];
      if (arg.startsWith('--region=')) region = arg.split('=')[1];
      if (arg.startsWith('--lang=')) lang = arg.split('=')[1];
      if (arg.startsWith('--mdb-image=')) mdbImage = arg.split('=')[1];
      if (arg.startsWith('--dbc-image=')) dbcImage = arg.split('=')[1];
      if (arg == '--auto-start') autoStart = true;
      if (arg == '--dry-run') dryRun = true;
    }
    return LaunchArgs(channel: channel, region: region, lang: lang, mdbImage: mdbImage, dbcImage: dbcImage, autoStart: autoStart, dryRun: dryRun);
  }

  bool get hasLocalImages => mdbImage != null || dbcImage != null;

  List<String> toArgs() => [
        if (channel != null) '--channel=$channel',
        if (region != null) '--region=$region',
        if (lang != null) '--lang=$lang',
        if (mdbImage != null) '--mdb-image=$mdbImage',
        if (dbcImage != null) '--dbc-image=$dbcImage',
        if (dryRun) '--dry-run',
        '--auto-start',
      ];
}

late final LaunchArgs launchArgs;

/// Active app locale. Defaults to German; user can switch to English at runtime.
/// `--lang=xx` overrides the default at startup.
final ValueNotifier<Locale> appLocale = ValueNotifier(const Locale('de'));

/// Installer version. Injected by CI via --dart-define=APP_VERSION=<git describe>;
/// falls back to 'dev' for local unflagged builds.
const String appVersion = String.fromEnvironment('APP_VERSION', defaultValue: 'dev');

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  launchArgs = LaunchArgs.fromArgs(args);
  if (launchArgs.lang != null) {
    appLocale.value = Locale(launchArgs.lang!);
  }

  // Capture all debugPrint output into the global log
  final originalDebugPrint = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null) {
      final ts = DateTime.now().toIso8601String().substring(11, 19);
      installerLog.add('$ts $message');
    }
    originalDebugPrint(message, wrapWidth: wrapWidth);
  };

  debugPrint('Librescoot Installer $appVersion starting (lang=${appLocale.value.languageCode}, platform=${Platform.operatingSystem})');

  // Self-elevate on Windows / macOS so privileged operations later (raw
  // disk write, network config) don't fail mid-flow. If the user declines
  // the UAC / sudo prompt we put up an explanatory dialog and exit on Quit
  // — running unprivileged would just dead-end at the flash step. Linux
  // has its own pkexec story already; skip there.
  var elevationDeclined = false;
  if (!launchArgs.autoStart && (Platform.isWindows || Platform.isMacOS)) {
    final elevated = await ElevationService.isElevated();
    if (!elevated) {
      debugPrint('Elevation: not elevated, attempting self-elevate');
      final relaunched = await ElevationService.elevateIfNeeded(
        extraArgs: launchArgs.toArgs(),
      );
      if (relaunched) {
        debugPrint('Elevation: relaunched as elevated process, exiting parent');
        exit(0);
      }
      debugPrint('Elevation: user declined or relaunch failed; showing dialog');
      elevationDeclined = true;
    } else {
      debugPrint('Elevation: already elevated');
    }
  }

  // On fresh Windows installs, the CA certificate store may be incomplete.
  // Windows lazily downloads missing CA certs when SChannel-based apps (like
  // curl.exe) connect to HTTPS endpoints, but Dart's HTTP client only reads
  // what's already in the store. Warm up the store by hitting the endpoints
  // we'll need.
  if (Platform.isWindows) {
    Future.wait([
      Process.run('curl.exe', ['-s', '-o', 'NUL', 'https://api.github.com/']),
      Process.run('curl.exe', ['-s', '-o', 'NUL', 'https://github.com/']),
      Process.run('curl.exe', ['-s', '-o', 'NUL', 'https://release-assets.githubusercontent.com/']),
    ]).catchError((_) => <ProcessResult>[]);
  }

  // If we were launched as the elevated process, bring ourselves to front
  if (launchArgs.autoStart && Platform.isMacOS) {
    Future.delayed(const Duration(seconds: 1), () {
      // Activate by bundle ID — no Accessibility permissions needed
      Process.run('osascript', [
        '-e',
        'tell application id "org.librescoot.installer" to activate',
      ]);
    });
  }

  runApp(LibrescootInstaller(elevationDeclined: elevationDeclined));
}

class LibrescootInstaller extends StatelessWidget {
  const LibrescootInstaller({super.key, this.elevationDeclined = false});

  final bool elevationDeclined;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: appLocale,
      builder: (context, locale, _) => MaterialApp(
        title: 'Librescoot Installer',
        debugShowCheckedModeBanner: false,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: kAccent,
            brightness: Brightness.dark,
          ).copyWith(
            primary: kAccent,
            onPrimary: kOnAccent,
            secondary: kAccent,
            onSecondary: kOnAccent,
            surface: kBgPrimary,
            onSurface: kTextPrimary,
          ),
          scaffoldBackgroundColor: kBgPrimary,
          useMaterial3: true,
        ),
        home: elevationDeclined
            ? const ElevationRequiredScreen()
            : const InstallerScreen(),
      ),
    );
  }
}

class ElevationRequiredScreen extends StatelessWidget {
  const ElevationRequiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lock_outline, color: Colors.amber, size: 48),
                const SizedBox(height: 16),
                Text(
                  l10n.elevationRequiredTitle,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.elevationRequiredBody,
                  style: TextStyle(color: Colors.grey.shade300),
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () => exit(1),
                    child: Text(l10n.quitButton),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
