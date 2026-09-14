// Persistent on-disk log. Every run writes one timestamped file into a
// well-known folder so a user who hits a problem can be pointed at a single
// path instead of hunting for it.
//
// Two processes can be involved in one run: the unelevated process the user
// starts and the elevated one it relaunches for the actual flashing. The
// unelevated process picks the path and hands it to the elevated child via
// `--log-file=`, so both append to the same file. Each line carries a tag
// saying which of the two wrote it.

import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:win32/win32.dart';

class LogService {

  /// How to reach the logged-in user's clipboard on macOS, with the locale
  /// pbcopy needs.
  ///
  /// pbcopy interprets its input in the current locale and falls back to Mac
  /// OS Roman when LC_CTYPE says nothing, which a GUI app's environment does
  /// not. The log is UTF-8, so without this every umlaut in it reaches the
  /// clipboard as the Mac OS Roman reading of its bytes: "aufgelöst" pasted
  /// into a bug report as "aufgel√∂st".
  ///
  /// The launchctl hop is for the elevated case, where the process is root
  /// and root's pasteboard is not the one the user pastes from.
  static (String, List<String>, Map<String, String>) pbcopyCommand(String uid) =>
      (
        'launchctl',
        ['asuser', uid, 'pbcopy'],
        const {'LC_CTYPE': 'UTF-8', 'LANG': 'en_US.UTF-8'},
      );

  /// Subfolder the log files live in, so nothing is dumped loose into the
  /// user's documents.
  static const _folderName = 'Librescoot Installer';

  /// Folder name used for the XDG state fallback on Linux, where a name with
  /// spaces would look out of place.
  static const _xdgFolderName = 'librescoot-installer';

  static const _filePrefix = 'librescoot-installer-';
  static const _fileSuffix = '.log';

  /// Number of runs to keep on disk. Older files are deleted on startup.
  static const _keepRuns = 20;

  /// Lines buffered until the file is open. Bounded so a failure to open the
  /// file can never grow without limit.
  static const _pendingLimit = 2000;

  static RandomAccessFile? _handle;
  static String? _filePath;
  static String _tag = 'user';
  static final List<String> _pending = [];
  static bool _disabled = false;

  /// Absolute path of this run's log file, or null if no file could be opened.
  static String? get filePath => _filePath;

  /// Open the log file and write the run header.
  ///
  /// [handoffPath] is the path the unelevated process passed down via
  /// `--log-file=`; when set, this process appends to that file instead of
  /// starting a new one.
  static Future<void> init({
    String? handoffPath,
    required String version,
    required String locale,
    required List<String> args,
  }) async {
    final elevatedChild = handoffPath != null;
    _tag = (elevatedChild || _looksLikeRoot()) ? 'admin' : 'user';

    // Appending to the path we were handed keeps one run in one file. The
    // other candidates cover the cases where that fails: no handoff at all,
    // or a Documents folder we are not allowed to write to (macOS gates it
    // behind a privacy prompt the user can decline).
    final candidates = <Future<File> Function()>[
      if (elevatedChild) () async => File(handoffPath),
      () async => _newLogFile(await _resolveLogDir()),
      () async => _newLogFile(await _resolveFallbackLogDir()),
    ];

    for (final candidate in candidates) {
      try {
        final file = await candidate();
        await file.parent.create(recursive: true);
        final existed = await file.exists();
        _handle = await file.open(mode: FileMode.writeOnlyAppend);
        _filePath = file.path;
        if (!existed) await _handOwnershipToUser(file);
        break;
      } catch (e) {
        debugPrint('Log: could not open log file: $e');
      }
    }

    if (_handle == null) {
      _disabled = true;
      _pending.clear();
      return;
    }

    _writeHeader(version: version, locale: locale, args: args);

    for (final line in _pending) {
      _writeLine(line);
    }
    _pending.clear();
  }

  /// Append one line. Cheap enough to sit on the debugPrint path: it is a
  /// single synchronous write into the OS page cache, which is what makes the
  /// log survive a hard crash or a hang mid-flash.
  static void write(String message) {
    if (_disabled) return;
    if (_handle == null) {
      if (_pending.length < _pendingLimit) _pending.add(message);
      return;
    }
    _writeLine(message);
  }

  /// Open the platform file manager with the log file selected.
  static Future<void> revealInFileManager() async {
    final target = _filePath;
    if (target == null) return;
    try {
      if (Platform.isWindows) {
        // explorer returns a non-zero exit code even on success, so the
        // result is not worth checking.
        await _spawnViewer('explorer', windowsExplorerArgs(target));
      } else if (Platform.isMacOS) {
        // Reveal in the logged-in user's Finder session, which is a different
        // session from this process when we run elevated.
        final uid = await _macConsoleUid();
        if (uid != null) {
          await _spawnViewer('launchctl', ['asuser', uid, 'open', '-R', target]);
        } else {
          await _spawnViewer('open', ['-R', target]);
        }
      } else {
        final dir = path.dirname(target);
        final sudoUser = Platform.environment['SUDO_USER'];
        if (sudoUser != null && sudoUser.isNotEmpty && sudoUser != 'root') {
          await _spawnViewer('sudo', ['-n', '-u', sudoUser, 'xdg-open', dir]);
        } else {
          await _spawnViewer('xdg-open', [dir]);
        }
      }
    } catch (e) {
      debugPrint('Log: could not reveal $target: $e');
    }
  }

  static Future<void> _spawnViewer(String exe, List<String> args) async {
    final proc = await Process.start(exe, args, mode: ProcessStartMode.detached);
    debugPrint('Log: opened the log folder with $exe (pid ${proc.pid})');
  }

  /// Explorer treats a quoted `/select,<path>` as an invalid switch. Keep
  /// the switch and path separate so Dart quotes only a path that needs it.
  static List<String> windowsExplorerArgs(String target) => ['/select,', target];

  static void _writeHeader({
    required String version,
    required String locale,
    required List<String> args,
  }) {
    final role = _tag == 'admin' ? 'elevated' : 'unelevated';
    _writeLine('=== Librescoot Installer $version ($role process, pid $pid) ===');
    _writeLine('platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
    _writeLine('locale: $locale');
    _writeLine('arguments: ${args.isEmpty ? '(none)' : args.join(' ')}');
    _writeLine('log file: $_filePath');
  }

  static void _writeLine(String message) {
    final handle = _handle;
    if (handle == null) return;
    try {
      handle.writeStringSync('${_lineStamp(DateTime.now())} [$_tag] $message\n');
    } catch (e) {
      // Removable media pulled, permissions changed: stop writing rather than
      // throwing on every log line for the rest of the run.
      _disabled = true;
      _handle = null;
      debugPrint('Log: write failed, on-disk log stopped: $e');
    }
  }

  static String _two(int v) => v.toString().padLeft(2, '0');

  static String _fileStamp(DateTime t) =>
      '${t.year}${_two(t.month)}${_two(t.day)}-'
      '${_two(t.hour)}${_two(t.minute)}${_two(t.second)}';

  static String _lineStamp(DateTime t) =>
      '${t.year}-${_two(t.month)}-${_two(t.day)} '
      '${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}.'
      '${t.millisecond.toString().padLeft(3, '0')}';

  /// Name this run's file in [dir] and drop the oldest runs kept there.
  static Future<File> _newLogFile(Directory dir) async {
    await dir.create(recursive: true);
    await _prune(dir);
    return File(path.join(dir.path, '$_filePrefix${_fileStamp(DateTime.now())}$_fileSuffix'));
  }

  /// Where this run's log file goes.
  static Future<Directory> _resolveLogDir() async {
    if (Platform.isWindows) {
      final documents = _windowsDocuments() ??
          path.join(Platform.environment['USERPROFILE'] ?? '', 'Documents');
      return Directory(path.join(documents, _folderName));
    }

    final home = await _userHome();
    final documents = Directory(path.join(home, 'Documents'));
    if (Platform.isMacOS || await documents.exists()) {
      return Directory(path.join(documents.path, _folderName));
    }

    // Linux without a Documents folder: the XDG state directory is where
    // logs belong. Only trust XDG_STATE_HOME when it agrees with the home
    // we resolved, since an elevated relaunch inherits root's environment.
    final xdgState = Platform.environment['XDG_STATE_HOME'];
    final base = (xdgState != null && xdgState.isNotEmpty && path.isWithin(home, xdgState))
        ? xdgState
        : path.join(home, '.local', 'state');
    return Directory(path.join(base, _xdgFolderName));
  }

  /// Used when the preferred folder cannot be written, which on macOS is what
  /// happens if the user declines the Documents privacy prompt. These are the
  /// per-platform log locations, always writable by the owning user.
  static Future<Directory> _resolveFallbackLogDir() async {
    if (Platform.isWindows) {
      final base = Platform.environment['LOCALAPPDATA'] ?? Directory.systemTemp.path;
      return Directory(path.join(base, 'Librescoot', 'Installer', 'logs'));
    }
    final home = await _userHome();
    if (Platform.isMacOS) {
      return Directory(path.join(home, 'Library', 'Logs', _folderName));
    }
    return Directory(path.join(home, '.local', 'state', _xdgFolderName));
  }

  /// Home directory of the user who started the installer. The elevated
  /// process runs with root's environment, so HOME alone would put the log
  /// in /var/root or /root where the user would never find it.
  static Future<String> _userHome() async {
    final cached = _cachedHome;
    if (cached != null) return cached;
    return _cachedHome = await _resolveUserHome();
  }

  static String? _cachedHome;

  static Future<String> _resolveUserHome() async {
    final sudoUser = Platform.environment['SUDO_USER'];
    if (sudoUser != null && sudoUser.isNotEmpty && sudoUser != 'root') {
      final home = await _homeOf(sudoUser);
      if (home != null) return home;
    }

    final envHome = Platform.environment['HOME'];
    if (envHome != null && envHome.isNotEmpty && !_isRootHome(envHome)) {
      return envHome;
    }

    // macOS elevation goes through osascript rather than sudo, so SUDO_USER
    // is not set. The console owner is the user sitting in front of the
    // machine, which is who launched us.
    if (Platform.isMacOS) {
      final consoleUser = await _macConsoleUser();
      if (consoleUser != null) {
        final home = await _homeOf(consoleUser);
        if (home != null) return home;
      }
    }

    return envHome ?? Directory.systemTemp.path;
  }

  static bool _isRootHome(String home) => home == '/var/root' || home == '/root';

  static bool _looksLikeRoot() {
    if (Platform.isWindows) return false;
    final home = Platform.environment['HOME'];
    return Platform.environment['SUDO_USER'] != null ||
        Platform.environment['USER'] == 'root' ||
        (home != null && _isRootHome(home));
  }

  static Future<String?> _homeOf(String user) async {
    try {
      if (Platform.isMacOS) {
        final result = await Process.run(
          'dscl',
          ['.', '-read', '/Users/$user', 'NFSHomeDirectory'],
        );
        final out = result.stdout.toString().trim();
        final colon = out.indexOf(':');
        if (result.exitCode == 0 && colon >= 0) {
          final home = out.substring(colon + 1).trim();
          if (home.isNotEmpty) return home;
        }
      } else {
        final result = await Process.run('getent', ['passwd', user]);
        final fields = result.stdout.toString().trim().split(':');
        if (result.exitCode == 0 && fields.length >= 6 && fields[5].isNotEmpty) {
          return fields[5];
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<String?> _macConsoleUser() async {
    try {
      final result = await Process.run('stat', ['-f', '%Su', '/dev/console']);
      final user = result.stdout.toString().trim();
      if (result.exitCode == 0 && user.isNotEmpty && user != 'root') return user;
    } catch (_) {}
    return null;
  }

  static Future<String?> _macConsoleUid() async {
    try {
      final result = await Process.run('stat', ['-f', '%u', '/dev/console']);
      final uid = result.stdout.toString().trim();
      if (result.exitCode == 0 && uid.isNotEmpty) return uid;
    } catch (_) {}
    return null;
  }

  /// Hand a file created by the elevated process back to the user, so they
  /// can still read and delete it afterwards. Skipped when this process is
  /// not the elevated one, where the file already has the right owner.
  static Future<void> _handOwnershipToUser(File file) async {
    if (Platform.isWindows || !_looksLikeRoot()) return;
    try {
      final home = await _userHome();
      final statArgs = Platform.isMacOS
          ? ['-f', '%u:%g', home]
          : ['-c', '%u:%g', home];
      final result = await Process.run('stat', statArgs);
      final owner = result.stdout.toString().trim();
      if (result.exitCode != 0 || owner.isEmpty || owner.startsWith('0:')) return;

      // The containing folder may have been created by this process too.
      await Process.run('chown', [owner, file.parent.path]);
      await Process.run('chown', [owner, file.path]);
      await Process.run('chmod', ['644', file.path]);
    } catch (e) {
      debugPrint('Log: could not hand ownership to the user: $e');
    }
  }

  /// Real Documents folder via the shell API. Reading %USERPROFILE%\Documents
  /// gives the wrong answer whenever OneDrive has taken over the known folder.
  static String? _windowsDocuments() {
    final folderId = calloc<GUID>();
    final buffer = calloc<Pointer<Utf16>>();
    try {
      folderId.ref.setGUID(FOLDERID_Documents);
      final hr = SHGetKnownFolderPath(folderId, KF_FLAG_DEFAULT, NULL, buffer);
      if (hr != S_OK || buffer.value == nullptr) return null;
      final documents = buffer.value.toDartString();
      return documents.isEmpty ? null : documents;
    } catch (e) {
      debugPrint('Log: SHGetKnownFolderPath failed: $e');
      return null;
    } finally {
      if (buffer.value != nullptr) CoTaskMemFree(buffer.value.cast());
      calloc.free(buffer);
      calloc.free(folderId);
    }
  }

  /// Keep the most recent runs, delete the rest.
  static Future<void> _prune(Directory dir) async {
    if (!await dir.exists()) return;
    try {
      final logs = <File>[];
      await for (final entry in dir.list(followLinks: false)) {
        if (entry is! File) continue;
        final name = path.basename(entry.path);
        if (name.startsWith(_filePrefix) && name.endsWith(_fileSuffix)) {
          logs.add(entry);
        }
      }
      if (logs.length < _keepRuns) return;
      // The timestamp in the name is zero-padded, so name order is age order.
      logs.sort((a, b) => path.basename(a.path).compareTo(path.basename(b.path)));
      // Leave room for the file this run is about to create.
      for (final old in logs.take(logs.length - _keepRuns + 1)) {
        try {
          await old.delete();
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Log: could not prune old logs: $e');
    }
  }
}
