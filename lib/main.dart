import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'l10n/app_localizations.dart';
import 'screens/installer_screen.dart';
import 'services/log_service.dart';
import 'theme.dart';

/// Global log buffer accessible from anywhere.
final List<String> installerLog = [];

/// Append a message to the in-app log and the on-disk log file. The in-app
/// view gets a short time prefix; the file adds its own full timestamp.
void appendLog(String message) {
  final ts = DateTime.now().toIso8601String().substring(11, 19);
  installerLog.add('$ts $message');
  LogService.write(message);
}

/// Same, for continuation lines (stack frames, command output) that carry no
/// time of their own.
void appendLogRaw(String line) {
  installerLog.add(line);
  LogService.write(line);
}

/// Used by the global error handlers to surface a SnackBar from anywhere.
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Append an unhandled error to the installer log and show a non-blocking
/// SnackBar so the user knows something went wrong but the app keeps running.
/// Native crashes (FFI, signals) can't be caught here — only Dart errors.
void reportUnhandledError(Object error, StackTrace? stack, {String? from}) {
  final origin = from != null ? ' [$from]' : '';
  appendLog('ERROR$origin: $error');
  if (stack != null) {
    for (final line in stack.toString().split('\n')) {
      if (line.isNotEmpty) appendLogRaw('  $line');
    }
  }
  // Mirror to stderr/console so a terminal-launched run sees it too.
  FlutterError.dumpErrorToConsole(
    FlutterErrorDetails(exception: error, stack: stack, library: 'installer'),
  );

  final messenger = rootScaffoldMessengerKey.currentState;
  if (messenger == null) return;

  // The MaterialApp isn't necessarily built yet when this fires (e.g. an
  // error during startup, before runApp's first frame), so the messenger's
  // context may not carry a Localizations ancestor. Fall back to English
  // literals rather than the German ones this used to hardcode.
  final l10n = AppLocalizations.of(messenger.context);
  final internalErrorText = l10n?.internalError(error.toString()) ?? 'Internal error: $error';
  final copyLogText = l10n?.copyLog ?? 'Copy log';

  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      backgroundColor: Colors.red.shade900,
      duration: const Duration(seconds: 8),
      content: Text(
        internalErrorText,
        style: const TextStyle(color: Colors.white),
      ),
      action: SnackBarAction(
        label: copyLogText,
        textColor: Colors.white,
        onPressed: () {
          Clipboard.setData(ClipboardData(text: installerLog.join('\n')));
        },
      ),
    ),
  );
}

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
  /// Log file the unelevated process already opened. The elevated relaunch
  /// appends to it instead of starting a second file, so one run produces one
  /// log the user can hand over.
  final String? logFile;

  LaunchArgs({
    this.channel,
    this.region,
    this.lang,
    this.mdbImage,
    this.dbcImage,
    this.autoStart = false,
    this.noOfflineMaps = false,
    this.dryRun = false,
    this.logFile,
  });

  factory LaunchArgs.fromArgs(List<String> args) {
    String? channel, region, lang, mdbImage, dbcImage, logFile;
    var autoStart = false;
    var noOfflineMaps = false;
    var dryRun = false;
    for (final arg in args) {
      if (arg.startsWith('--channel=')) channel = arg.split('=')[1];
      if (arg.startsWith('--region=')) region = arg.split('=')[1];
      if (arg.startsWith('--lang=')) lang = arg.split('=')[1];
      if (arg.startsWith('--mdb-image=')) mdbImage = arg.split('=')[1];
      if (arg.startsWith('--dbc-image=')) dbcImage = arg.split('=')[1];
      // Paths may legitimately contain '=', so take everything after the
      // first one rather than splitting.
      if (arg.startsWith('--log-file=')) logFile = arg.substring('--log-file='.length);
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
      logFile: logFile,
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
        if (LogService.filePath != null) '--log-file=${LogService.filePath}',
        '--auto-start',
      ];
}

late final LaunchArgs launchArgs;

/// Active app locale. Defaults to German; user can switch to English at runtime.
/// `--lang=xx` overrides the default at startup.
final ValueNotifier<Locale> appLocale = ValueNotifier(const Locale('de'));

/// Installer version. Injected by CI via `--dart-define=APP_VERSION=<git describe>`;
/// falls back to 'dev' for local unflagged builds.
const String appVersion = String.fromEnvironment('APP_VERSION', defaultValue: 'dev');

void main(List<String> args) async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
      await windowManager.ensureInitialized();
      await windowManager.setPreventClose(true);
    }

    // Flutter framework errors (build/layout/paint exceptions). Without this,
    // a release build can end up in an unrecoverable state.
    FlutterError.onError = (details) {
      reportUnhandledError(details.exception, details.stack, from: 'flutter');
    };

    // Async errors that escape the framework (microtasks, untriaged Futures).
    // Returning true tells the engine we handled it — keep the app alive.
    PlatformDispatcher.instance.onError = (error, stack) {
      reportUnhandledError(error, stack, from: 'platform');
      return true;
    };

    launchArgs = LaunchArgs.fromArgs(args);
    if (launchArgs.lang != null) {
      appLocale.value = Locale(launchArgs.lang!);
    }

    // Capture all debugPrint output into the global log
    final originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) appendLog(message);
      originalDebugPrint(message, wrapWidth: wrapWidth);
    };

    // Open the on-disk log early: anything logged before this is buffered by
    // LogService and written out as soon as the file is there.
    await LogService.init(
      handoffPath: launchArgs.logFile,
      version: appVersion,
      locale: appLocale.value.languageCode,
      args: args,
    );

    debugPrint('Librescoot Installer $appVersion starting (lang=${appLocale.value.languageCode}, platform=${Platform.operatingSystem})');
    debugPrint('Log file: ${LogService.filePath ?? 'unavailable'}');

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
  }, (error, stack) {
    // Last-resort catch for anything that escaped both error handlers above.
    reportUnhandledError(error, stack, from: 'zone');
  });
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
        scaffoldMessengerKey: rootScaffoldMessengerKey,
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
