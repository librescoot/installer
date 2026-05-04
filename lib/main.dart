import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';
import 'screens/installer_screen.dart';
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
  /// Set by self-elevation when we relaunch ourselves with admin rights.
  /// Causes the elevated process to skip the welcome screen and resume
  /// the install starting from "Start Installation" was clicked, with
  /// the user's selections carried over as --channel/--region/etc.
  final bool autoStart;
  /// True if the user explicitly unchecked "offline maps" before clicking
  /// Start. Lets the elevated relaunch preserve that choice (otherwise it
  /// would default back to wanting offline maps and trip over a missing
  /// region selection).
  final bool noOfflineMaps;
  final bool dryRun;

  LaunchArgs({
    this.channel,
    this.region,
    this.lang,
    this.mdbImage,
    this.dbcImage,
    this.autoStart = false,
    this.noOfflineMaps = false,
    this.dryRun = false,
  });

  factory LaunchArgs.fromArgs(List<String> args) {
    String? channel, region, lang, mdbImage, dbcImage;
    var autoStart = false;
    var noOfflineMaps = false;
    var dryRun = false;
    for (final arg in args) {
      if (arg.startsWith('--channel=')) channel = arg.split('=')[1];
      if (arg.startsWith('--region=')) region = arg.split('=')[1];
      if (arg.startsWith('--lang=')) lang = arg.split('=')[1];
      if (arg.startsWith('--mdb-image=')) mdbImage = arg.split('=')[1];
      if (arg.startsWith('--dbc-image=')) dbcImage = arg.split('=')[1];
      if (arg == '--auto-start') autoStart = true;
      if (arg == '--no-offline-maps') noOfflineMaps = true;
      if (arg == '--dry-run') dryRun = true;
    }
    return LaunchArgs(
      channel: channel,
      region: region,
      lang: lang,
      mdbImage: mdbImage,
      dbcImage: dbcImage,
      autoStart: autoStart,
      noOfflineMaps: noOfflineMaps,
      dryRun: dryRun,
    );
  }

  bool get hasLocalImages => mdbImage != null || dbcImage != null;

  /// Build the args to relaunch with after the user has clicked Start
  /// and made selections in the welcome screen. Pulls from the live
  /// state, not from the original CLI args, so the elevated child
  /// resumes with what the user picked.
  List<String> relaunchArgs({
    required String channelName,
    required String? regionSlug,
    required bool wantsOfflineMaps,
  }) =>
      [
        '--channel=$channelName',
        if (regionSlug != null) '--region=$regionSlug',
        if (lang != null) '--lang=$lang',
        if (mdbImage != null) '--mdb-image=$mdbImage',
        if (dbcImage != null) '--dbc-image=$dbcImage',
        if (!wantsOfflineMaps) '--no-offline-maps',
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

  // Self-elevation no longer happens here; it's deferred until the user
  // actually clicks Start Installation. That way the user can browse the
  // welcome screen, pick a channel/region etc. without the UAC/sudo
  // prompt firing in their face on every launch, AND a --dry-run launch
  // doesn't get auto-clicked through to the next phase before the user
  // sees anything. See _startDownloadsAndContinue in installer_screen.dart.

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
      // Activate by bundle ID: no Accessibility permissions needed
      Process.run('osascript', [
        '-e',
        'tell application id "org.librescoot.installer" to activate',
      ]);
    });
  }

  runApp(const LibrescootInstaller());
}

class LibrescootInstaller extends StatelessWidget {
  const LibrescootInstaller({super.key});

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
        home: const InstallerScreen(),
      ),
    );
  }
}

/// Modal shown when the user clicks Start Installation but UAC/sudo is
/// declined. The user dismisses it and can re-attempt by clicking Start
/// again, or close the app.
Future<void> showElevationRequiredDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.lock_outline, color: Colors.amber, size: 36),
      title: Text(l10n.elevationRequiredTitle),
      content: Text(l10n.elevationRequiredBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(l10n.continueButton),
        ),
      ],
    ),
  );
}
