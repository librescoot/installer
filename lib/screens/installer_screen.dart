import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart' show LaunchArgs, installerLog, launchArgs, showElevationRequiredDialog;
import '../l10n/app_localizations.dart';
import '../models/download_state.dart';
import '../models/install_state.dart';
import '../models/installer_phase.dart';
import '../models/region.dart';
import '../models/scooter_health.dart';
import '../models/substep.dart';
import '../models/trampoline_status.dart';
import '../services/resume_resolver.dart';
import '../services/services.dart';
import '../widgets/download_progress.dart';
import '../widgets/health_check_panel.dart';
import '../widgets/instruction_step.dart';
import '../widgets/phase_sidebar.dart';
import '../widgets/substep_list.dart';
import '../theme.dart';

class InstallerScreen extends StatefulWidget {
  const InstallerScreen({super.key});

  @override
  State<InstallerScreen> createState() => _InstallerScreenState();
}

class _InstallerScreenState extends State<InstallerScreen> {
  InstallerPhase _currentPhase = InstallerPhase.welcome;
  final Set<InstallerPhase> _completedPhases = {};
  final Set<InstallerPhase> _skippedPhases = {};
  String _statusMessage = '';
  bool _isProcessing = false;
  double _progress = 0.0;
  bool _isElevated = false;

  // Services
  late final UsbDetector _usbDetector;
  late final DownloadService _downloadService;
  final SshService _sshService = SshService();

  // State
  final DownloadState _downloadState = DownloadState();
  ScooterHealth? _scooterHealth;
  UsbDevice? _device;

  // Welcome screen state
  final List<bool> _prerequisiteChecks = [false, false, false, false];
  Map<DownloadChannel, ({String tag, String date})>? _availableChannels;
  bool _channelsLoading = true;
  // Regions on offer, derived from the published tile assets. Seeded with the
  // offline catalogue so the dropdown is populated immediately, then replaced
  // once the live listing resolves.
  List<Region> _availableRegions = Region.all;

  // Phase guard flags (prevent auto-start methods from re-firing on rebuild)
  bool _mdbConnectStarted = false;
  bool _healthCheckStarted = false;
  bool _mdbToUmsStarted = false;
  bool _mdbFlashStarted = false;
  bool _mdbBootStarted = false;
  bool _dbcUploadReady = false; // upload done, waiting for "Begin flashing DBC"
  // Stage-1 dashboardPrep tracking. The background DBC upload runs while
  // Bluetooth pairing + keycard enrollment happen in the foreground; the
  // "Begin flashing DBC" button only unlocks once all three are satisfied.
  bool _dashboardPrepStarted = false; // background upload kicked off
  bool _btDone = false;
  bool _btSkipped = false;
  bool _keycardDone = false;
  bool _keycardSkipped = false;
  // Which interactive sub-step the dashboardPrep screen is showing.
  _DashboardPrepStep _dashboardPrepStep = _DashboardPrepStep.bluetooth;
  bool _reconnectStarted = false;
  bool _showElevatedHandoff = false;
  bool _dbcFlashSimulateError = false;
  bool _cbbCheckFailed = false;
  DeviceInfo? _mdbInfo;
  bool _skipMdbFlash = false;
  bool _skipDbcFlash = false;
  String? _radioGagaBackupPath;
  bool _flashConfirmed = false;
  final Map<String, int> _retryCounts = {};
  bool _btPairingActive = false;
  String? _blePinCode;
  bool _bleConnected = false;
  String? _bleMac;
  Timer? _blePinPollTimer;
  final ScrollController _phaseScrollController = ScrollController();
  bool _keycardLearning = false;
  int _keycardAuthorizedCountBefore = 0; // captured at Start, compared at Done
  int _keycardSessionTapCount = 0; // driven by card-learned events
  // Substage of the keycardSetup phase. The phase is rendered as a small
  // state machine so we can branch between the cards-only legacy flow and
  // the new master-teach-in flow without splitting it into separate phases.
  _KeycardStage _keycardStage = _KeycardStage.loading;
  // null = capability still unknown, true = new keycard-service (supports
  // learn:master:start / reset / keycard:events), false = old service (only
  // the original learn:start/learn:stop/set-master commands).
  bool? _keycardServiceCanMaster;
  int _keycardMasterCount = 0;
  int _keycardAuthorizedCount = 0;
  Future<void> Function()? _keycardEventsStop;
  StreamSubscription<String>? _keycardEventsSub;
  String? _keycardToastMessage;
  Color _keycardToastColor = Colors.green;
  Timer? _keycardToastTimer;
  String? _awaitingUnlockState; // null when not awaiting; current vehicle state otherwise
  String? _resumePreviousError; // first error line from a leftover trampoline-status, if any
  ResumeDecision? _resumeDecision; // resolved resume target, applied by _continueFromResume
  Completer<bool>? _unlockCompleter;
  bool _keepCache = false;
  bool _isCriticalOperation = false; // prevent quit during flash/upload
  bool _awaitingFinishReboot = false;
  Process? _caffeinateProcess; // macOS sleep prevention

  StreamSubscription<UsbDevice?>? _deviceSub;

  @override
  void initState() {
    super.initState();
    _usbDetector = UsbDetector();
    _downloadService = DownloadService();
    _deviceSub = _usbDetector.deviceStream.listen((device) {
      setState(() => _device = device);
    });
    _usbDetector.startMonitoring();
    _sshService.setManualPasswordPrompt(_promptManualRootPassword);
    _checkElevation();
    _applyLaunchArgs();
    Future.microtask(_detectResumeState);
    _resolveAvailableChannels();
    _loadAvailableRegions();
    _detectRegionFromIp();
  }

  Future<String?> _promptManualRootPassword({
    required String? version,
    required int previousAttempts,
  }) async {
    if (!mounted) return null;
    return showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _ManualPasswordDialog(
        version: version,
        previousAttempts: previousAttempts,
        maxAttempts: SshService.maxManualPasswordAttempts,
      ),
    );
  }

  Future<void> _loadAvailableRegions() async {
    final regions = await _downloadService.fetchAvailableRegions();
    if (!mounted || regions.isEmpty) return;
    setState(() {
      _availableRegions = regions;
      // If a region was already chosen (launch args / IP), keep the user's
      // pick but swap in the instance from the live list so dropdown identity
      // lines up. Equality is by slug, so this is a no-op when slugs match.
      final selected = _downloadState.selectedRegion;
      if (selected != null) {
        _downloadState.selectedRegion =
            regions.where((r) => r.slug == selected.slug).firstOrNull;
      }
    });
  }

  static const _regionHeaderPrefix = '__country__';

  /// Build dropdown items grouped by country: a disabled bold header per
  /// country, followed by its (indented) regions. Relies on [_availableRegions]
  /// already being ordered so each country's regions are contiguous.
  List<DropdownMenuItem<Region>> _buildRegionDropdownItems(
      List<Region> regions) {
    final items = <DropdownMenuItem<Region>>[];
    String? currentCountry;
    for (final region in regions) {
      if (region.country != currentCountry) {
        currentCountry = region.country;
        items.add(DropdownMenuItem<Region>(
          enabled: false,
          value: Region(
              name: region.country,
              slug: '$_regionHeaderPrefix${region.country}'),
          child: Text(
            region.country,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600),
          ),
        ));
      }
      items.add(DropdownMenuItem<Region>(
        value: region,
        child: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Text(region.name),
        ),
      ));
    }
    return items;
  }

  Future<void> _detectRegionFromIp() async {
    if (_downloadState.selectedRegion != null) return; // already set (e.g. from launch args)
    final slug = await Region.detectSlugFromIp();
    if (slug == null || !mounted || _downloadState.selectedRegion != null) {
      return;
    }
    // Only preselect if we actually offer tiles for the detected region.
    final region = _availableRegions.where((r) => r.slug == slug).firstOrNull;
    if (region != null) {
      setState(() => _downloadState.selectedRegion = region);
    }
  }

  void _applyLaunchArgs() {
    final args = launchArgs;
    if (args.channel != null) {
      final ch = DownloadChannel.values.where((c) => c.name == args.channel).firstOrNull;
      if (ch != null) _downloadState.channel = ch;
    }
    if (args.region != null) {
      final r = Region.all.where((r) => r.slug == args.region).firstOrNull;
      if (r != null) _downloadState.selectedRegion = r;
    }
    if (args.noOfflineMaps) {
      _downloadState.wantsOfflineMaps = false;
    }
    if (args.autoStart) {
      // Auto-advance past welcome to notices on the elevated relaunch.
      // The user already filled in the welcome form on the unelevated
      // parent and clicked Start, so showing Welcome again would just
      // be noise; stop on Notices so the warnings still get read.
      // Use addPostFrameCallback so the first frame paints first
      // (otherwise the user briefly sees nothing while we transition),
      // but don't add a real delay — the old 2 s wait was for channel
      // resolution which Notices doesn't need.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _currentPhase == InstallerPhase.welcome) {
          _setPhase(InstallerPhase.notices);
        }
      });
    }
  }

  Future<void> _checkElevation() async {
    final elevated = await ElevationService.isElevated();
    if (mounted) setState(() => _isElevated = elevated);
  }

  Future<void> _detectResumeState() async {
    // Detection happens in _autoConnectMdb: no early jumping here.
  }

  @override
  void dispose() {
    _deviceSub?.cancel();
    _usbDetector.stopMonitoring();
    _blePinPollTimer?.cancel();
    _keycardToastTimer?.cancel();
    final stop = _keycardEventsStop;
    if (stop != null) {
      // Fire-and-forget: dispose can't await, but the SSH session should be
      // closed even if it briefly outlives the widget.
      stop();
      _keycardEventsStop = null;
    }
    _keycardEventsSub?.cancel();
    _phaseScrollController.dispose();
    if (_unlockCompleter != null && !_unlockCompleter!.isCompleted) {
      _unlockCompleter!.complete(false);
    }
    _allowSleep();
    super.dispose();
  }

  /// Returns true if the operation should be retried, false if max retries exceeded.
  /// Handles backoff delay and retry counting.
  Future<bool> _shouldRetry(String key, {int maxRetries = 5, int delaySecs = 5}) async {
    _retryCounts[key] = (_retryCounts[key] ?? 0) + 1;
    final count = _retryCounts[key]!;
    if (count >= maxRetries) {
      debugPrint('$key: giving up after $count attempts');
      return false;
    }
    debugPrint('$key: retry $count/$maxRetries in ${delaySecs}s');
    await Future.delayed(Duration(seconds: delaySecs));
    return mounted;
  }

  void _resetRetries(String key) => _retryCounts.remove(key);

  Future<void> _resolveAvailableChannels() async {
    try {
      final channels = await _downloadService.fetchAvailableChannels();
      if (mounted) {
        setState(() {
          _availableChannels = channels;
          _channelsLoading = false;
          // Default to best available: stable > testing > nightly. But only
          // if the user (or launchArgs --channel=) hasn't already chosen
          // one — otherwise the elevated relaunch's --channel=nightly would
          // get clobbered when this async fetch eventually completes.
          if (channels.isNotEmpty && launchArgs.channel == null) {
            if (channels.containsKey(DownloadChannel.stable)) {
              _downloadState.channel = DownloadChannel.stable;
            } else if (channels.containsKey(DownloadChannel.testing)) {
              _downloadState.channel = DownloadChannel.testing;
            } else if (channels.containsKey(DownloadChannel.nightly)) {
              _downloadState.channel = DownloadChannel.nightly;
            }
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _channelsLoading = false);
      }
    }
  }

  void _setPhase(InstallerPhase phase) {
    final leaving = _currentPhase;
    setState(() {
      _completedPhases.add(_currentPhase);
      _currentPhase = phase;
      _statusMessage = '';
      _progress = 0.0;
      _isProcessing = false;
    });
    if (leaving == InstallerPhase.keycardSetup &&
        phase != InstallerPhase.keycardSetup) {
      _keycardTearDown();
    }
    // The keycard sub-step inside dashboardPrep subscribes to keycard events
    // the same way the standalone phase does, so tear it down when we leave.
    if (leaving == InstallerPhase.dashboardPrep &&
        phase != InstallerPhase.dashboardPrep) {
      _keycardTearDown();
    }
    if (phase == InstallerPhase.keycardSetup) {
      _onEnterKeycardSetup();
    }
    if (phase == InstallerPhase.finish) {
      _onEnterFinish();
    }
    if (phase == InstallerPhase.dbcSwapAndFlash) {
      _dbcFlashWatchStarted = false;
      _dbcUsbDisconnected = false;
    }
    if (phase == InstallerPhase.dashboardPrep || phase == InstallerPhase.bluetoothPairing) {
      _fetchBleMac();
    }
  }

  /// Build an [InstallState] for the given [phase], carrying the fixed install
  /// config (channel, release, image, tiles, language, serial) plus the current
  /// Stage-1 progress flags. Used for every resume checkpoint write so the
  /// state file always reflects the full install context.
  InstallState _baseInstallState(InstallPhase phase) {
    final dbcItem = _downloadState.itemOfType(DownloadItemType.dbcFirmware);
    final osmItem = _downloadState.itemOfType(DownloadItemType.osmTiles);
    final valhallaItem = _downloadState.itemOfType(DownloadItemType.valhallaTiles);
    return InstallState(
      phase: phase,
      channel: _downloadState.channel.name,
      releaseTag: _downloadState.releaseTag,
      dbcImage: dbcItem?.filename,
      osmTiles: osmItem?.filename,
      valhallaTiles: valhallaItem?.filename,
      serial: _mdbInfo?.serialNumber,
      btPaired: _btDone,
      keycardEnrolled: _keycardDone,
    );
  }

  /// Read the scooter's BLE MAC from the MDB so the user can match it against
  /// the device they're pairing to. Best-effort; leaves _bleMac null on error.
  Future<void> _fetchBleMac() async {
    if (_isDryRun || !_sshService.isConnected) return;
    try {
      final out = (await _sshService
              .runCommand('redis-cli hget ble mac-address')
              .timeout(const Duration(seconds: 5)))
          .trim();
      if (mounted && out.isNotEmpty) {
        setState(() => _bleMac = out.toUpperCase());
      }
    } catch (e) {
      debugPrint('UI: BLE MAC fetch failed: $e');
    }
  }

  /// Park the two settings that interfere with a long-running install:
  /// auto-standby (would suspend the MDB mid-install) and the alarm (would
  /// trip on motion while we're working). Both are persisted by
  /// settings-service, so they get explicitly wiped in [_onEnterFinish]
  /// before we reapply the user's actual choices. Best-effort: older images
  /// may not know these keys.
  Future<void> _disableInstallerHazards({required String label}) async {
    if (_isDryRun || !_sshService.isConnected) return;
    try {
      await _sshService.runCommand('lsc set scooter.auto-standby-seconds 0');
      debugPrint('UI: scooter.auto-standby-seconds=0 ($label)');
    } catch (e) {
      debugPrint('UI: failed to set scooter.auto-standby-seconds=0 at $label (ok): $e');
    }
    try {
      await _sshService.runCommand('lsc set alarm.enabled false');
      debugPrint('UI: alarm.enabled=false ($label)');
    } catch (e) {
      debugPrint('UI: failed to set alarm.enabled=false at $label (ok): $e');
    }
    // The settings change propagates via a publish — if alarm-service is
    // mid-restart, was already armed when we set the flag, or the publish
    // gets dropped, the FSM can stay in an armed state. Belt-and-suspenders:
    // also push a runtime disarm onto the alarm command queue so the FSM
    // drops to Disarmed regardless of how alarm.enabled propagated.
    try {
      await _sshService.redisLpush('scooter:alarm', 'disarm');
      debugPrint('UI: scooter:alarm disarm ($label)');
    } catch (e) {
      debugPrint('UI: failed to push scooter:alarm disarm at $label (ok): $e');
    }
  }

  /// Wipe the persisted settings file and bounce settings-service so the
  /// installer-only overrides (auto-standby=0, alarm.enabled=false, etc.)
  /// don't leak into the user's daily-driver state. Called before we
  /// re-apply the user's actual choices in [_onEnterFinish].
  Future<void> _resetPersistedSettings() async {
    if (_isDryRun || !_sshService.isConnected) return;
    try {
      await _sshService.runCommand(
        'rm -f /data/settings.toml && systemctl restart librescoot-settings',
      );
      debugPrint('UI: wiped /data/settings.toml + restarted librescoot-settings');
      // Give settings-service a moment to come back and re-publish defaults
      // before we HSET into the settings hash again.
      await Future.delayed(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('UI: failed to reset persisted settings (ok): $e');
    }
  }

  /// Persist the user's installer choices on the MDB: dashboard language
  /// (so the UI matches what they used here) and OTA channel (so future
  /// updates pull from the same track they just installed). Both are
  /// best-effort — failure is harmless, the user can fix from the dashboard.
  Future<void> _onEnterFinish() async {
    if (_isDryRun || !_sshService.isConnected) {
      // Dry-run / no SSH: nothing to reboot, render the success screen
      // immediately.
      if (mounted) setState(() => _awaitingFinishReboot = false);
      return;
    }

    if (mounted) setState(() => _awaitingFinishReboot = true);

    // Kill the green success-blink (and the amber guard) before anything
    // else. The reboot below should tear down the transient systemd-run
    // units anyway, but if it doesn't fire (or doesn't fire promptly) this
    // is what keeps the scooter from sitting in standby with the LP5562
    // blinking green until someone power-cycles it.
    await _stopBootLedBlink();

    // Wipe first, then re-apply the user's choices: this drops our
    // installer-only overrides (auto-standby=0, alarm.enabled=false) so the
    // scooter behaves normally on next boot.
    await _resetPersistedSettings();

    final lang = Localizations.localeOf(context).languageCode;
    if (lang == 'en' || lang == 'de') {
      try {
        await _sshService.runCommand("lsc set dashboard.language '$lang'");
        debugPrint('UI: persisted dashboard.language=$lang');
      } catch (e) {
        debugPrint('UI: failed to persist dashboard.language: $e');
      }
    }

    final channel = _downloadState.channel.name;
    try {
      await _sshService.runCommand('lsc ota channel $channel');
      debugPrint('UI: persisted ota channel=$channel');
    } catch (e) {
      debugPrint('UI: failed to persist ota channel: $e');
    }

    // Wipe installer staging from /data before we kick off the reboot, so
    // the user doesn't carry a few hundred MB of leftover image/tile files
    // around forever. Skipped in non-release builds so devs can poke at
    // the trampoline state after a failed run.
    if (kReleaseMode) {
      await _cleanupMdb();
    } else {
      debugPrint('UI: skipping MDB cleanup (non-release build)');
    }

    // Reboot the MDB. The install path leaves several services stopped
    // (librescoot-pm) and the PWM LED channels for the four blinkers
    // deactivated (the trampoline drives them as a progress bar and clears
    // activate=1 on cleanup), so the running system can't flash blinkers
    // until a fresh boot re-initializes everything. A reboot here also picks
    // up the lsc settings we just persisted. Timing is fine: the user is
    // about to disconnect USB and physically reassemble the scooter, which
    // takes longer than the MDB needs to come back up.
    //
    // Restoring usb0-policy=auto and rebooting have to happen in the same
    // detached MDB-side shell. vehicle-service applies the policy change
    // synchronously: with the DBC powered off (it is, by the end of
    // onboot.sh) and keycards paired (the common path), usb0AutoEffective()
    // returns true and SetUsb0Enabled(false) tears down the USB gadget —
    // which is the SSH transport we're sitting on. Running it via nohup
    // lets the shell outlive the disconnect long enough to sync and reboot.
    try {
      await _sshService.runCommand(
        "nohup sh -c 'lsc set scooter.usb0-policy auto; sync; reboot' "
        '>/dev/null 2>&1 </dev/null &',
      );
      debugPrint('UI: queued policy reset + reboot on MDB');
    } catch (e) {
      debugPrint('UI: failed to queue reboot on finish: $e');
    }

    // Poll the SSH transport until it dies — that's the signal the reboot
    // command actually took effect. The detached shell sets usb0-policy=auto
    // first; with the DBC off + keycards paired, vehicle-service tears down
    // the USB gadget synchronously, so SSH drops well before the reboot
    // itself completes. We do NOT wait for the MDB to come back: after
    // reboot the scooter is in stand-by with policy=auto, so usb0 stays
    // down until the user unlocks. The SSH drop is the only signal we get.
    // 60s cap so a stuck reboot doesn't trap the user on the waiting screen.
    final deadline = DateTime.now().add(const Duration(seconds: 60));
    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      try {
        await _sshService.runCommand('echo ok').timeout(const Duration(seconds: 2));
      } catch (_) {
        debugPrint('UI: MDB SSH dropped — reboot confirmed');
        _sshService.disconnect();
        if (mounted) setState(() => _awaitingFinishReboot = false);
        return;
      }
    }
    debugPrint('UI: timed out waiting for MDB reboot, showing finish anyway');
    if (mounted) setState(() => _awaitingFinishReboot = false);
  }

  void _setStatus(String message, {double? progress}) {
    if (message.isNotEmpty) {
      installerLog.add('${DateTime.now().toIso8601String().substring(11, 19)} $message');
    }
    setState(() {
      _statusMessage = message;
      if (progress != null) _progress = progress;
    });
  }

  final _debugController = TextEditingController();

  void _showLogDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l10n.logDebugShell),
          content: SizedBox(
            width: 700,
            height: 500,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    reverse: true,
                    child: SelectableText(
                      installerLog.join('\n'),
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                    ),
                  ),
                ),
                const Divider(),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _debugController,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                        decoration: InputDecoration(
                          hintText: l10n.debugCommandHint,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                        onSubmitted: (cmd) async {
                          if (cmd.trim().isEmpty) return;
                          installerLog.add('> $cmd');
                          setDialogState(() {});
                          try {
                            final result = await Process.run('/bin/sh', ['-c', cmd]);
                            final out = result.stdout.toString().trim();
                            final err = result.stderr.toString().trim();
                            if (out.isNotEmpty) installerLog.add(out);
                            if (err.isNotEmpty) installerLog.add('stderr: $err');
                            installerLog.add('exit: ${result.exitCode}');
                          } catch (e) {
                            installerLog.add('error: $e');
                          }
                          _debugController.clear();
                          setDialogState(() {});
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.play_arrow),
                      onPressed: () async {
                        final cmd = _debugController.text;
                        if (cmd.trim().isEmpty) return;
                        installerLog.add('> $cmd');
                        setDialogState(() {});
                        try {
                          final result = await Process.run('/bin/sh', ['-c', cmd]);
                          final out = result.stdout.toString().trim();
                          final err = result.stderr.toString().trim();
                          if (out.isNotEmpty) installerLog.add(out);
                          if (err.isNotEmpty) installerLog.add('stderr: $err');
                          installerLog.add('exit: ${result.exitCode}');
                        } catch (e) {
                          installerLog.add('error: $e');
                        }
                        _debugController.clear();
                        setDialogState(() {});
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final text = installerLog.join('\n');
                if (Platform.isMacOS) {
                  final uid = (await Process.run('stat', ['-f', '%u', '/dev/console'])).stdout.toString().trim();
                  final proc = await Process.start('launchctl', ['asuser', uid, 'pbcopy']);
                  proc.stdin.write(text);
                  await proc.stdin.close();
                } else {
                  await Clipboard.setData(ClipboardData(text: text));
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(l10n.copyToClipboard),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.closeButton),
            ),
          ],
        ),
      ),
    );
  }

  void _setCritical(bool critical) {
    if (_isCriticalOperation == critical) return;
    setState(() => _isCriticalOperation = critical);
    if (critical) {
      _usbDetector.stopMonitoring();
      debugPrint('USB detector: paused during critical operation');
      _preventSleep();
    } else {
      _usbDetector.startMonitoring();
      debugPrint('USB detector: resumed after critical operation');
      _allowSleep();
    }
  }

  void _preventSleep() {
    if (Platform.isMacOS) {
      _caffeinateProcess?.kill();
      Process.start('caffeinate', ['-s']).then((p) {
        _caffeinateProcess = p;
        debugPrint('UI: sleep prevention started (caffeinate pid ${p.pid})');
      }).catchError((_) {});
    }
  }

  void _allowSleep() {
    if (_caffeinateProcess != null) {
      debugPrint('UI: sleep prevention stopped');
      _caffeinateProcess!.kill();
      _caffeinateProcess = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopScope(
      canPop: !_isCriticalOperation,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isCriticalOperation) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.cannotQuitWhileFlashing),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              // Elevation is handled at flash time via pkexec/sudo, no warning needed
              Expanded(
                child: Row(
                  children: [
                    PhaseSidebar(
                      currentPhase: _currentPhase,
                      completedPhases: _completedPhases,
                      skippedPhases: _skippedPhases,
                      downloadItems: _downloadState.items,
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, constraints) => Scrollbar(
                                controller: _phaseScrollController,
                                thumbVisibility: true,
                                child: SingleChildScrollView(
                                  controller: _phaseScrollController,
                                  padding: const EdgeInsets.all(32),
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(minHeight: constraints.maxHeight - 64),
                                    child: Center(child: _buildPhaseContent(l10n)),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          _buildStatusBar(l10n),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildElevationWarning(AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      color: Colors.orange.shade900,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.warning, color: Colors.orange, size: 16),
          const SizedBox(width: 8),
          Text(
            l10n.elevationWarning,
            style: const TextStyle(color: Colors.orange, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar(AppLocalizations l10n) {
    return Container(
      height: 36,
      color: kBgSidebar,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          if (_isProcessing)
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: _progress > 0 ? _progress : null,
                color: kAccent,
              ),
            ),
          if (_isProcessing) const SizedBox(width: 8),
          Expanded(
            child: Text(
              _statusMessage,
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_progress > 0 && _isProcessing)
            Text(
              '${(_progress * 100).toStringAsFixed(0)}%',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          if (installerLog.isNotEmpty)
            IconButton(
              onPressed: _showLogDialog,
              icon: Icon(Icons.article_outlined, size: 16, color: Colors.grey.shade600),
              tooltip: l10n.showLogTooltip,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            ),
        ],
      ),
    );
  }

  Widget _buildPhaseContent(AppLocalizations l10n) {
    if (_showElevatedHandoff) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.open_in_new, size: 48, color: kAccent),
            const SizedBox(height: 16),
            Text(l10n.installationContinuesInNewWindow,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(l10n.youCanCloseThisWindow,
                style: TextStyle(color: Colors.grey.shade400)),
          ],
        ),
      );
    }
    return switch (_currentPhase) {
      InstallerPhase.welcome => _buildWelcome(l10n),
      InstallerPhase.notices => _buildNotices(l10n),
      InstallerPhase.physicalPrep => _buildPhysicalPrep(l10n),
      InstallerPhase.mdbConnect => _buildMdbConnect(l10n),
      InstallerPhase.resumeDetected => _buildResumeDetected(l10n),
      InstallerPhase.healthCheck => _buildHealthCheck(l10n),
      InstallerPhase.batteryRemoval => _buildBatteryRemoval(l10n),
      InstallerPhase.mdbToUms => _buildMdbToUms(l10n),
      InstallerPhase.mdbFlash => _buildMdbFlash(l10n),
      InstallerPhase.scooterPrep => _buildScooterPrep(l10n),
      InstallerPhase.mdbBoot => _buildMdbBoot(l10n),
      InstallerPhase.cbbReconnect => _buildCbbReconnect(l10n),
      InstallerPhase.dashboardPrep => _buildDashboardPrep(l10n),
      InstallerPhase.dbcSwapAndFlash => _buildDbcSwapAndFlash(l10n),
      InstallerPhase.reconnect => _buildReconnect(l10n),
      InstallerPhase.bluetoothPairing => _buildBluetoothPairing(l10n),
      InstallerPhase.keycardSetup => _buildKeycardSetup(l10n),
      InstallerPhase.finish => _buildFinish(l10n),
    };
  }

  Widget _buildWelcome(AppLocalizations l10n) {
    final prerequisites = [
      l10n.prerequisiteScrewdriverPH2,
      l10n.prerequisiteScrewdriverFlat,
      l10n.prerequisiteUsbCable,
      l10n.prerequisiteTime,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.welcomeHeading,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(l10n.welcomeSubheading,
            style: TextStyle(color: Colors.grey.shade400)),
        const SizedBox(height: 24),

        // Prerequisites: items size to their content; a long item gets a row
        // to itself, short items pack onto a single line.
        Text(l10n.whatYouNeed, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 24,
          runSpacing: 4,
          children: [
            for (int i = 0; i < prerequisites.length; i++)
              _prerequisite(prerequisites[i], i),
          ],
        ),
        const SizedBox(height: 24),

        // Channel selection
        Text(l10n.firmwareChannel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        if (_channelsLoading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 12),
                Text(l10n.loadingChannels, style: TextStyle(color: Colors.grey.shade400)),
              ],
            ),
          )
        else
          _buildChannelSelector(l10n),
        const SizedBox(height: 24),

        // Region selection with skip checkbox inline
        Row(
          children: [
            Text(l10n.region, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Spacer(),
            InkWell(
              onTap: () => setState(() {
                _downloadState.wantsOfflineMaps = !_downloadState.wantsOfflineMaps;
              }),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: !_downloadState.wantsOfflineMaps,
                      onChanged: (v) => setState(() {
                        _downloadState.wantsOfflineMaps = !(v ?? false);
                      }),
                    ),
                    Text(l10n.skipOfflineMaps,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(l10n.regionHint,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
        const SizedBox(height: 8),
        if (_downloadState.wantsOfflineMaps)
          DropdownButtonFormField<Region>(
            initialValue: _downloadState.selectedRegion,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: l10n.selectRegion,
            ),
            items: _buildRegionDropdownItems(_availableRegions),
            selectedItemBuilder: (context) =>
                _buildRegionDropdownItems(_availableRegions).map((item) {
              final r = item.value!;
              final isHeader = r.slug.startsWith(_regionHeaderPrefix);
              return Align(
                alignment: Alignment.centerLeft,
                child: Text(isHeader ? '' : r.name),
              );
            }).toList(),
            onChanged: (r) {
              // Country headers are disabled, so onChanged only fires for real
              // regions, but guard against the header sentinel just in case.
              if (r == null || r.slug.startsWith(_regionHeaderPrefix)) return;
              setState(() => _downloadState.selectedRegion = r);
            },
          ),

        const SizedBox(height: 24),

        // Heads-up that clicking Start will trigger the UAC prompt.
        // Windows-only — macOS uses per-call authopen during the flash itself.
        if (!_isElevated && Platform.isWindows) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_outlined,
                  size: 18, color: Colors.grey.shade400),
              const SizedBox(width: 8),
              Expanded(
                child: Text(l10n.elevationNoticeWelcome,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],

        // Start button: fires the UAC / sudo elevation prompt on
        // Windows / macOS, then advances to Notices. We elevate here
        // (not at app startup) so the user can browse the welcome form
        // first, but BEFORE Notices so the prompt is the cost of the
        // big "I'm starting" click rather than buried inside Notices'
        // Continue. If the user declines elevation, they stay on this
        // page with the explanatory dialog and can try again.
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _isProcessing ||
                    _channelsLoading ||
                    (_availableChannels?.isEmpty ?? true) ||
                    (_downloadState.wantsOfflineMaps && _downloadState.selectedRegion == null)
                ? null
                : _startClickedAdvanceToNotices,
            icon: const Icon(Icons.arrow_forward),
            label: Text(l10n.startInstallation),
          ),
        ),
      ],
    );
  }

  Widget _buildNotices(AppLocalizations l10n) {
    // Kick downloads off as soon as the user lands here so the sidebar
    // shows progress while they read the warnings, and the Continue
    // button can gate on _downloadState.allReady. Microtask so we don't
    // mutate state during build.
    if (!_downloadsKicked && !launchArgs.hasLocalImages) {
      Future.microtask(_kickoffDownloads);
    }
    final downloadsReady = _downloadState.allReady && _downloadState.items.isNotEmpty;
    final hasItems = _downloadState.items.isNotEmpty;
    final waitingOnDownloads = !downloadsReady && hasItems;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.noticesHeading,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(l10n.noticesSubheading,
            style: TextStyle(color: Colors.grey.shade400)),
        const SizedBox(height: 24),

        // Critical no-power-cycle warning: users keep yanking power
        // when they think things are stuck, which is what actually
        // bricks scooters. Loud, red, with a direct Discord link.
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.shade400, width: 2),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.dangerous, color: Colors.red.shade300, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.noPowerCycleWarningTitle,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade300,
                          fontSize: 15,
                        )),
                    const SizedBox(height: 6),
                    Text(l10n.noPowerCycleWarningBody,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade200)),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => _openExternalUrl('https://discord.gg/BmY2P2T9j3'),
                      icon: Icon(Icons.chat_bubble_outline, size: 16, color: Colors.red.shade200),
                      label: Text(l10n.openLibrescootDiscord,
                          style: TextStyle(color: Colors.red.shade200)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Reliability warning: flash failures are dominated by USB drops
        // and laptop sleep.
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber, color: Colors.amber),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.reliabilityWarningTitle,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                    const SizedBox(height: 4),
                    Text(l10n.reliabilityWarningBody,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade300)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            TextButton.icon(
              onPressed: _isProcessing
                  ? null
                  : () => _setPhase(InstallerPhase.welcome),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: Text(l10n.backButton),
            ),
            // While downloads are in flight, the primary Continue is
            // disabled and we show a small "I'll have internet later"
            // override link next to it. Once downloads are ready,
            // Continue becomes a normal active button.
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (waitingOnDownloads) ...[
                  TextButton(
                    onPressed: _isProcessing
                        ? null
                        : () => _setPhase(InstallerPhase.physicalPrep),
                    child: Text(l10n.noticesContinueOfflineAnyway,
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                ],
                FilledButton.icon(
                  onPressed: _isProcessing || waitingOnDownloads
                      ? null
                      : _startDownloadsAndContinue,
                  icon: waitingOnDownloads
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.arrow_forward),
                  label: Text(waitingOnDownloads
                      ? l10n.noticesWaitingForDownloads
                      : l10n.noticesAcknowledgeButton),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChannelSelector(AppLocalizations l10n) {
    final channelInfo = <DownloadChannel, ({String name, String desc})>{
      DownloadChannel.stable: (name: l10n.channelStable, desc: l10n.channelStableDesc),
      DownloadChannel.testing: (name: l10n.channelTesting, desc: l10n.channelTestingDesc),
      DownloadChannel.nightly: (name: l10n.channelNightly, desc: l10n.channelNightlyDesc),
    };

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final channel in DownloadChannel.values) ...[
            if (channel.index > 0) const SizedBox(width: 12),
            Expanded(
              child: _buildChannelCard(
                l10n,
                channel: channel,
                name: channelInfo[channel]!.name,
                description: channelInfo[channel]!.desc,
                releaseTag: _availableChannels?[channel]?.tag,
                releaseDate: _availableChannels?[channel]?.date,
                available: _availableChannels?.containsKey(channel) ?? false,
                selected: _downloadState.channel == channel,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChannelCard(
    AppLocalizations l10n, {
    required DownloadChannel channel,
    required String name,
    required String description,
    required String? releaseTag,
    required String? releaseDate,
    required bool available,
    required bool selected,
  }) {
    return GestureDetector(
      onTap: available ? () => setState(() => _downloadState.channel = channel) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? kAccent : Colors.grey.shade700,
            width: selected ? 2 : 1,
          ),
          color: selected
              ? kAccent.withValues(alpha: 0.08)
              : available
                  ? Colors.transparent
                  : Colors.grey.shade900.withValues(alpha: 0.4),
        ),
        child: Opacity(
          opacity: available ? 1.0 : 0.4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: selected ? kAccent : null,
                  )),
              const SizedBox(height: 4),
              Text(description,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
              const SizedBox(height: 8),
              if (releaseTag != null) ...[
                Text(
                  releaseTag,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade300,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (releaseDate != null)
                  Text(
                    releaseDate,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  ),
              ] else
                Text(
                  l10n.channelNoReleases,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _prerequisite(String text, int index) {
    return InkWell(
      onTap: () => setState(() => _prerequisiteChecks[index] = !_prerequisiteChecks[index]),
      borderRadius: BorderRadius.circular(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _prerequisiteChecks[index] ? Icons.check_box : Icons.check_box_outline_blank,
            size: 18,
            color: _prerequisiteChecks[index] ? kAccent : Colors.grey,
          ),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(
            color: _prerequisiteChecks[index] ? Colors.grey.shade200 : Colors.grey.shade400,
          )),
        ],
      ),
    );
  }

  /// Welcome → Notices Start handler. Validates that a region was picked
  /// (when offline maps are wanted), then self-elevates on Windows / macOS
  /// if needed. On a successful elevation kick-off the parent exits and
  /// the elevated child resumes here via --auto-start. On UAC decline /
  /// silent abort, surface the explanatory dialog and bail. Linux relies
  /// on pkexec for the individual privileged calls; no UAC dance here.
  Future<void> _startClickedAdvanceToNotices() async {
    final l10n = AppLocalizations.of(context)!;
    if (_downloadState.wantsOfflineMaps && _downloadState.selectedRegion == null && !launchArgs.hasLocalImages) {
      _setStatus(l10n.selectRegionError);
      return;
    }

    setState(() => _isProcessing = true);

    // macOS: don't self-elevate the GUI. TCC gates /dev/rdiskN by responsible
    // app, and a self-elevated unsigned .app gets EPERM on raw disk opens even
    // as root. Instead let the bundled flasher pop its own authopen dialog
    // when it needs to write the device. Re-enable once the .app is signed +
    // notarised and Removable Volumes TCC can be granted to the bundle id.
    if (Platform.isWindows && !await ElevationService.isElevated()) {
      _setStatus(l10n.requestingAdminPrivileges);
      debugPrint('Elevation: not elevated, attempting self-elevate');
      final relaunched = await ElevationService.elevateIfNeeded(
        extraArgs: launchArgs.relaunchArgs(
          channelName: _downloadState.channel.name,
          regionSlug: _downloadState.selectedRegion?.slug,
          wantsOfflineMaps: _downloadState.wantsOfflineMaps,
        ),
      );
      if (relaunched) {
        debugPrint('Elevation: relaunched as elevated process, exiting parent');
        exit(0);
      }
      debugPrint('Elevation: user declined or relaunch failed; showing dialog');
      if (mounted) await showElevationRequiredDialog(context);
      if (mounted) {
        _setStatus('');
        setState(() => _isProcessing = false);
      }
      return;
    }

    if (mounted) {
      _setStatus('');
      setState(() => _isProcessing = false);
      _setPhase(InstallerPhase.notices);
    }
  }

  bool _downloadsKicked = false;

  /// Build the download queue and start downloads in the background.
  /// Called when the user enters the Notices phase so the sidebar shows
  /// progress while they read the warnings; the Continue button on
  /// Notices then waits on _downloadState.allReady (or the override).
  Future<void> _kickoffDownloads() async {
    if (_downloadsKicked) return;
    _downloadsKicked = true;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isProcessing = true);
    try {
      if (launchArgs.hasLocalImages) {
        _setStatus(l10n.usingLocalFirmwareImages);
        final items = <DownloadItem>[];
        if (launchArgs.mdbImage != null) {
          items.add(DownloadItem(
            type: DownloadItemType.mdbFirmware,
            url: '',
            filename: File(launchArgs.mdbImage!).uri.pathSegments.last,
            expectedSize: await File(launchArgs.mdbImage!).length(),
          )..localPath = launchArgs.mdbImage
           ..bytesDownloaded = await File(launchArgs.mdbImage!).length());
        }
        if (launchArgs.dbcImage != null) {
          items.add(DownloadItem(
            type: DownloadItemType.dbcFirmware,
            url: '',
            filename: File(launchArgs.dbcImage!).uri.pathSegments.last,
            expectedSize: await File(launchArgs.dbcImage!).length(),
          )..localPath = launchArgs.dbcImage
           ..bytesDownloaded = await File(launchArgs.dbcImage!).length());
        }
        setState(() => _downloadState.items = items);
      } else {
        _setStatus(l10n.resolvingReleases);
        final items = await _downloadService.buildDownloadQueue(
          channel: _downloadState.channel,
          region: _downloadState.selectedRegion,
          wantsOfflineMaps: _downloadState.wantsOfflineMaps,
        );
        setState(() => _downloadState.items = items);
        _downloadInBackground();
      }
    } catch (e) {
      _setStatus(l10n.errorPrefix(e.toString()));
      _downloadsKicked = false; // allow retry
    } finally {
      if (mounted) {
        _setStatus('');
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _startDownloadsAndContinue() async {
    // Downloads are kicked off when entering Notices (_kickoffDownloads),
    // so by the time Continue is clicked here all we need to do is move
    // the phase along. Falls back to _kickoffDownloads for the rare
    // race where the user landed here without going through Notices.
    if (!_downloadsKicked) {
      await _kickoffDownloads();
    }
    if (mounted) _setPhase(InstallerPhase.physicalPrep);
  }

  void _downloadInBackground() async {
    try {
      await _downloadService.downloadAll(
        _downloadState.items,
        onProgress: (item, bytes, total) {
          if (mounted) setState(() {}); // Trigger rebuild to update progress
        },
      );
      // The last onProgress fires before localPath is set on the final item,
      // so the UI is stuck in "almost-but-not-done" without this final rebuild.
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        setState(() => _downloadState.error = e.toString());
      }
    }
  }
  Widget _buildPhysicalPrep(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.physicalPrepHeading,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(l10n.physicalPrepSubheading,
            style: TextStyle(color: Colors.grey.shade400)),
        const SizedBox(height: 24),
        InstructionStep(
          number: 1,
          title: l10n.removeFootwellCover,
          description: l10n.removeFootwellCoverDesc,
          beforeImageAsset: 'assets/images/lsi-unu_scooter_footwell_closed.jpg',
          imageAsset: 'assets/images/lsi-unu_scooter_footwell_open.jpg',
        ),
        InstructionStep(
          number: 2,
          title: l10n.unscrewUsbCable,
          description: l10n.unscrewUsbCableDesc,
          beforeImageAsset: 'assets/images/lsi-mdb_usb_connected.jpg',
          imageAsset: 'assets/images/lsi-mdb_usb_disconnected.jpg',
        ),
        InstructionStep(
          number: 3,
          title: l10n.connectLaptopUsb,
          description: l10n.connectLaptopUsbDesc,
        ),
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: () => _setPhase(InstallerPhase.mdbConnect),
            icon: const Icon(Icons.arrow_forward),
            label: Text(l10n.doneDetectDevice),
          ),
        ),
      ],
    );
  }

  Widget _buildMdbConnect(AppLocalizations l10n) {
    if (!_mdbConnectStarted && !_isProcessing) {
      _mdbConnectStarted = true;
      Future.microtask(_autoConnectMdb);
    }

    if (_awaitingUnlockState != null) {
      return _buildAwaitingUnlock(l10n);
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.connectingToMdb,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (_isProcessing) ...[
            const SizedBox(width: 48, height: 48, child: CircularProgressIndicator()),
            const SizedBox(height: 16),
          ],
          Text(_statusMessage.isEmpty ? l10n.waitingForUsbDevice : _statusMessage,
              style: TextStyle(color: Colors.grey.shade400)),
          if (!_isProcessing) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                setState(() => _mdbConnectStarted = true);
                Future.microtask(_autoConnectMdb);
              },
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retryMdbConnect),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAwaitingUnlock(AppLocalizations l10n) {
    final isRtd = _awaitingUnlockState == 'ready-to-drive';
    return Center(
      child: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(isRtd ? Icons.local_parking : Icons.lock_open,
                size: 72, color: Colors.amber),
            const SizedBox(height: 16),
            Text(isRtd ? l10n.awaitingParkHeading : l10n.awaitingUnlockHeading,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.amber)),
            const SizedBox(height: 12),
            Text(isRtd ? l10n.awaitingParkDetail : l10n.awaitingUnlockDetail,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade300)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isRtd) ...[
                  FilledButton.icon(
                    onPressed: _userOverrideRtd,
                    icon: const Icon(Icons.arrow_forward),
                    label: Text(l10n.awaitingParkContinueAnyway),
                  ),
                  const SizedBox(width: 12),
                ],
                TextButton(
                  onPressed: _userCancelUnlockWait,
                  child: Text(l10n.cancelButton),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _waitForUnlock() async {
    final completer = Completer<bool>();
    _unlockCompleter = completer;

    Future<void> poll() async {
      while (!completer.isCompleted) {
        if (!mounted) {
          if (!completer.isCompleted) completer.complete(false);
          return;
        }
        String? state;
        try {
          state = await _sshService.getVehicleState();
        } catch (e) {
          debugPrint('SSH: vehicle state read failed: $e');
        }
        if (!mounted || completer.isCompleted) return;
        if (state == 'parked') {
          completer.complete(true);
          return;
        }
        if (state != null && state != _awaitingUnlockState && mounted) {
          setState(() => _awaitingUnlockState = state);
        }
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    unawaited(poll());
    final result = await completer.future;
    if (mounted) setState(() => _awaitingUnlockState = null);
    if (identical(_unlockCompleter, completer)) _unlockCompleter = null;
    return result;
  }

  void _userOverrideRtd() {
    if (_awaitingUnlockState == 'ready-to-drive' &&
        _unlockCompleter != null && !_unlockCompleter!.isCompleted) {
      debugPrint('UI: user override accepted ready-to-drive as parked');
      _unlockCompleter!.complete(true);
    }
  }

  void _userCancelUnlockWait() {
    if (_unlockCompleter != null && !_unlockCompleter!.isCompleted) {
      debugPrint('UI: user cancelled unlock wait');
      _unlockCompleter!.complete(false);
    }
  }

  Future<void> _autoConnectMdb() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isProcessing = true);

    if (_isDryRun) {
      _setStatus('[DRY RUN] Loading auth assets...');
      try {
        await _sshService.loadDeviceConfig('assets');
        _setStatus('[DRY RUN] Auth loaded, simulating MDB v1.15.0 connection...');
      } catch (e) {
        _setStatus('[DRY RUN] Auth load failed: $e: continuing anyway');
      }
      await Future.delayed(const Duration(seconds: 1));
      _setPhase(InstallerPhase.healthCheck);
      return;
    }

    _setStatus(l10n.waitingForRndis);
    // Wait for any USB device (RNDIS or UMS)
    while (_device == null) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
    }

    if (_device!.mode == DeviceMode.massStorage) {
      // Device is already in UMS mode: skip ahead to flash
      _setStatus(l10n.mdbDetectedUmsSkipping);
      await Future.delayed(const Duration(seconds: 1));
      _setPhase(InstallerPhase.mdbFlash);
      return;
    }

    // RNDIS mode: normal flow.
    //
    // Always run installDriver() rather than gating on isDriverInstalled():
    // the driver may be in the driver store from a prior run while the device
    // is currently bound to usbser. installDriver() short-circuits internally
    // when the binding is already correct, and pnputil /add-driver is
    // idempotent.
    if (Platform.isWindows) {
      _setStatus(l10n.checkingRndisDriver);
      await DriverService.installDriver();
    }

    _setStatus(l10n.configuringNetwork);
    final networkService = NetworkService();
    final iface = await networkService.findLibrescootInterface();
    if (iface != null) {
      try {
        final configured = await networkService.configureInterface(iface);
        if (!configured && !await networkService.isMdbReachable()) {
          // macOS path: configureInterface returns false (no exception) when
          // `networksetup -setmanual` fails for lack of admin. The macOS
          // auth dialog is asynchronous — auto-retrying here just churns the
          // UI through configuring/ssh-fail/retry cycles until the user
          // clicks Allow. Stop and let them hit the retry button when ready.
          _setStatus(l10n.networkConfigNeedsPermission);
          setState(() => _isProcessing = false);
          return;
        }
      } on NetworkPrivilegeException catch (e) {
        _setStatus(l10n.errorPrefix(e.toString()));
        setState(() => _isProcessing = false);
        return;
      }
    }

    _setStatus(l10n.connectingSsh);
    try {
      await _sshService.loadDeviceConfig('assets');
      final info = await _sshService.connectToMdb();
      setState(() => _mdbInfo = info);
      debugPrint('SSH: firmware=${info.firmwareVersion}, serial=${info.serialNumber ?? "unknown"}');

      // An install that died mid-flash leaves /data/installer behind with
      // keycard + bluetooth masked (the trampoline masks them pre-flash).
      // After a power cycle such a scooter cannot be unlocked at all: no
      // keycard reader, no BLE, so the parked-state gate below would wait
      // forever. state.json (written once the MDB runs Librescoot) proves an
      // earlier session already passed the gate; so do the legacy leftover
      // trampoline artifacts (older builds wrote no state.json). On either
      // signal, skip the gate and clean up the masked services / error
      // signals before resuming at the resolved phase.
      final st = await _sshService.readInstallState();
      final status = await _sshService.readTrampolineStatus();
      var resumingUnfinished = st != null;
      if (!resumingUnfinished) {
        try {
          final leftover = await _sshService.runCommand(
            'ls /data/installer/trampoline-status /data/installer/trampoline.sh 2>/dev/null; true',
          );
          resumingUnfinished = leftover.trim().isNotEmpty;
        } catch (e) {
          debugPrint('SSH: unfinished-install check failed (ok): $e');
        }
      }

      if (resumingUnfinished) {
        final decision = resolveResume(state: st, status: status);
        debugPrint('SSH: unfinished install detected (state=${st?.phase.wire ?? "none"}), '
            'resuming at ${decision.phase.name}, skipping unlock gate');
        _setStatus(l10n.unfinishedInstallDetected);
        try {
          await _sshService.runCommand(
            '[ -x /data/installer/stop-error-signals.sh ] && /data/installer/stop-error-signals.sh; '
            '[ -x /data/stop-error-signals.sh ] && /data/stop-error-signals.sh; true',
          );
        } catch (_) {}
        // The staged stop-error-signals.sh is whatever the PREVIOUS
        // installer version wrote; older builds only handled keycard and
        // the LEDs. Re-assert the unmasks ourselves so we don't depend on
        // it: without bluetooth-service the nRF52 bridge is down and the
        // upcoming health check sees no AUX/CBB data at all. Keycard is
        // unmasked but deliberately not started (keycardSetup starts it
        // after disengaging auto-master-learn).
        try {
          await _sshService.runCommand(
            'systemctl unmask librescoot-keycard keycard-service '
            'librescoot-bluetooth librescoot-ums 2>/dev/null; '
            'systemctl start librescoot-bluetooth librescoot-ums 2>/dev/null; true',
          );
        } catch (e) {
          debugPrint('SSH: service unmask on resume failed (ok): $e');
        }
        // Stash the decision for the resume screen's Continue handler, and
        // surface what the previous run recorded so the user can acknowledge
        // it before continuing.
        if (!mounted) return;
        setState(() {
          _resumeDecision = decision;
          _resumePreviousError = decision.previousError;
          _isProcessing = false;
        });
        _setPhase(InstallerPhase.resumeDetected);
        return;
      }

      // Wait for scooter to be in parked state (or user-overridden
      // ready-to-drive)
      _setStatus(l10n.waitingForUnlock);
      final ok = await _waitForUnlock();
      if (!ok) {
        // User cancelled, or widget went away.
        if (mounted) {
          setState(() { _isProcessing = false; _mdbConnectStarted = false; });
        }
        return;
      }
      debugPrint('SSH: scooter is parked (or overridden), locking...');

      await _completeConnectionSetup(l10n);
    } catch (e) {
      _setStatus(l10n.sshConnectionFailed(e.toString()));
      // No auto-retry here: SSH failure means the previous network config
      // didn't actually deliver a reachable MDB. Repeating the same dance
      // every second flickers the UI. The retry button below explicitly
      // re-arms _mdbConnectStarted and re-invokes us.
      setState(() => _isProcessing = false);
    }
  }

  /// Shared tail of the connect phase: runs after the unlock gate (normal
  /// flow) or after the user confirms the resume screen. Pins the USB
  /// gadget, disables alarm/auto-standby, locks the scooter, and moves on
  /// to [nextPhase] (the health check on a fresh install, or the resolved
  /// resume target).
  Future<void> _completeConnectionSetup(
    AppLocalizations l10n, {
    InstallerPhase nextPhase = InstallerPhase.healthCheck,
  }) async {
    // Keep MDB USB gadget powered while the scooter is locked so we don't
    // lose RNDIS mid-flash. Best-effort: the key may not exist on older
    // images and `lsc set` returns non-zero in that case.
    try {
      await _sshService.runCommand('lsc set scooter.usb0-policy always-on');
      debugPrint('UI: scooter.usb0-policy=always-on');
    } catch (e) {
      debugPrint('UI: failed to set scooter.usb0-policy=always-on (ok): $e');
    }

    // Don't let the old image fall into auto-standby or trip its alarm
    // during the install. We get reset on the new image (see keycardSetup
    // entry) and explicitly cleaned up at finish. Best-effort.
    await _disableInstallerHazards(label: 'pre-flash');

    // Lock the scooter for safe flashing
    _setStatus(l10n.lockingScooter);
    await _sshService.redisLpush('scooter:state', 'lock');
    final locked = await _sshService.waitForVehicleState('stand-by', timeout: const Duration(seconds: 30));
    if (!locked) {
      debugPrint('SSH: lock did not reach stand-by, continuing anyway');
    }
    debugPrint('SSH: scooter locked');

    _setStatus(l10n.connected);
    setState(() => _isProcessing = false);
    _setPhase(nextPhase);
  }

  /// Continue button on the resume screen. Applies the resolved
  /// ResumeDecision: seeds the dashboard-prep completion flags from the
  /// recorded progress, runs the shared connection-setup side effects
  /// (USB policy, hazard disable, lock), and jumps straight to the resolved
  /// phase instead of always restarting from the health check. The unlock
  /// gate is intentionally not run here: on resume the scooter may have
  /// keycard/BLE masked and could not be unlocked at all.
  Future<void> _continueFromResume() async {
    final l10n = AppLocalizations.of(context)!;
    final decision = _resumeDecision;
    setState(() {
      _isProcessing = true;
      if (decision != null) {
        // Treat recorded progress as satisfied so the dashboardPrep gate
        // (_btDone || _btSkipped, _keycardDone || _keycardSkipped) passes
        // without redoing pairing/enrollment.
        if (decision.bluetoothDone) _btDone = true;
        if (decision.keycardDone) _keycardDone = true;
      }
    });
    try {
      await _completeConnectionSetup(
        l10n,
        nextPhase: decision?.phase ?? InstallerPhase.healthCheck,
      );
    } catch (e) {
      _setStatus(l10n.sshConnectionFailed(e.toString()));
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Widget _buildResumeDetected(AppLocalizations l10n) {
    return Center(
      child: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.history, size: 72, color: Colors.amber),
            const SizedBox(height: 16),
            Text(l10n.resumeFoundHeading,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.amber)),
            const SizedBox(height: 12),
            Text(l10n.resumeFoundBody,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade300)),
            if (_resumePreviousError != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.resumeFoundLastError,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                    const SizedBox(height: 4),
                    SelectableText(_resumePreviousError!,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _isProcessing ? null : _continueFromResume,
              icon: const Icon(Icons.arrow_forward),
              label: Text(l10n.continueButton),
            ),
          ],
        ),
      ),
    );
  }

  bool get _isDryRun => launchArgs.dryRun;

  /// Wait for MDB to reboot into RNDIS, reconfigure network, reconnect SSH.
  Future<bool> _reconnectToMdb() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      _setStatus(l10n.waitingForMdbToReboot);
      final found = await _waitForDevice(DeviceMode.ethernet, timeout: const Duration(seconds: 60));
      if (!found) return false;

      // MDB needs time to fully boot after RNDIS appears
      _setStatus(l10n.mdbDetectedWaitingForSsh);
      await Future.delayed(const Duration(seconds: 10));

      final iface = await NetworkService().findLibrescootInterface();
      if (iface != null) {
        try {
          await NetworkService().configureInterface(iface);
        } on NetworkPrivilegeException catch (e) {
          _setStatus(l10n.errorPrefix(e.toString()));
          return false;
        }
      }

      // Retry SSH connection a few times (MDB may still be starting sshd)
      for (var i = 0; i < 5; i++) {
        try {
          await _sshService.loadDeviceConfig('assets');
          await _sshService.connectToMdb();
          _setStatus(l10n.reconnectedToMdb);
          return true;
        } catch (_) {
          await Future.delayed(const Duration(seconds: 5));
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _waitForDevice(DeviceMode mode, {Duration timeout = const Duration(seconds: 120)}) async {
    if (_isDryRun) {
      await Future.delayed(const Duration(seconds: 1));
      return true;
    }
    final deadline = DateTime.now().add(timeout);
    while (_device?.mode != mode) {
      if (DateTime.now().isAfter(deadline)) return false;
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
    }
    return true;
  }

  /// Like _waitForDevice(DeviceMode.ethernet), but with a 5-minute soft
  /// deadline that surfaces the reconnect diagnostic panel without giving
  /// up. Returns true once the device shows up, false if the user navigated
  /// away or cancelled mid-wait. Updates the [setStep] callback's detail
  /// with elapsed time so the substep row shows a live counter.
  Future<bool> _waitForRndisWithTimeout(
    AppLocalizations l10n,
    void Function(String, SubstepState, {String? detail}) setStep,
  ) async {
    if (_isDryRun) {
      await Future.delayed(const Duration(seconds: 1));
      return true;
    }
    final start = DateTime.now();
    while (_device?.mode != DeviceMode.ethernet) {
      if (!mounted) return false;
      if (_currentPhase != InstallerPhase.reconnect) return false;
      final elapsed = DateTime.now().difference(start).inSeconds;
      setStep(
        'rndis',
        SubstepState.active,
        detail: l10n.elapsedSeconds(elapsed),
      );
      if (elapsed >= 300 && !_reconnectShowDiagnostics) {
        await _surfaceReconnectDiagnostics(l10n);
      }
      await Future.delayed(const Duration(seconds: 1));
    }
    return true;
  }

  /// Show the orange diagnostic panel after a long-running wait. Probes
  /// the OS for the current USB device list (lsusb / system_profiler /
  /// PowerShell) and dumps it into [_reconnectDiagnostics]. The panel
  /// stays visible until the user clicks one of the action buttons.
  Future<void> _surfaceReconnectDiagnostics(AppLocalizations l10n) async {
    if (!mounted) return;
    setState(() {
      _reconnectShowDiagnostics = true;
      _reconnectDiagnostics = l10n.collectingUsbInfo;
    });
    String snapshot;
    try {
      if (Platform.isMacOS) {
        final r = await Process.run(
          '/usr/sbin/system_profiler',
          ['SPUSBDataType'],
        ).timeout(const Duration(seconds: 8));
        snapshot = r.stdout.toString();
      } else if (Platform.isLinux) {
        final r = await Process.run('lsusb', []).timeout(const Duration(seconds: 5));
        snapshot = r.stdout.toString();
      } else if (Platform.isWindows) {
        final r = await Process.run(
          'powershell',
          ['-NoProfile', '-Command',
           "Get-PnpDevice -PresentOnly | Where-Object { \$_.InstanceId -like '*VID_0525*' -or \$_.InstanceId -like '*VID_15A2*' } | Format-List Name,Status,Class,InstanceId"],
        ).timeout(const Duration(seconds: 8));
        snapshot = r.stdout.toString();
      } else {
        snapshot = l10n.usbInfoUnsupportedPlatform;
      }
    } catch (e) {
      snapshot = '${l10n.usbInfoCollectFailed}: $e';
    }
    if (!mounted) return;
    setState(() => _reconnectDiagnostics = snapshot.trim());
  }

  bool get _isLibrescootFirmware {
    // /etc/os-release ID= is the authoritative discriminator. Stable
    // Librescoot ships VERSION_ID=1.0.1, indistinguishable from stock by
    // version alone: the channel-tag heuristic only catches nightly /
    // testing builds. Fall back to the heuristic if osId wasn't readable.
    final id = _mdbInfo?.osId ?? '';
    if (id.startsWith('librescoot')) return true;
    final v = _mdbInfo?.firmwareVersion ?? '';
    return v.contains('librescoot') || v.contains('nightly') ||
        v.contains('testing') || v.contains('stable');
  }

  bool get _isUntestedStockFirmware {
    if (_isLibrescootFirmware) return false;
    final v = _mdbInfo?.firmwareVersion ?? '';
    if (v.isEmpty || v.toLowerCase() == 'unknown') return false;
    return _semverLessThan(v, '1.12.0');
  }

  bool _semverLessThan(String a, String b) {
    int n(String s) {
      final c = s.trim().toLowerCase().replaceFirst('v', '');
      final p = c.split('.');
      final major = p.isNotEmpty ? int.tryParse(p[0]) ?? 0 : 0;
      final minor = p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0;
      final patch = p.length > 2 ? int.tryParse(p[2]) ?? 0 : 0;
      return major * 1000000 + minor * 1000 + patch;
    }
    return n(a) < n(b);
  }

  Widget _buildHealthCheck(AppLocalizations l10n) {
    if (!_healthCheckStarted && _scooterHealth == null && !_isProcessing) {
      _healthCheckStarted = true;
      Future.microtask(_runHealthCheck);
    }

    void proceed() {
      if (_skipMdbFlash) {
        // Mark all MDB flash phases as skipped
        for (final phase in MajorStep.mdbFlash.phases) {
          _skippedPhases.add(phase);
        }
        if (_skipDbcFlash) {
          // DBC flash itself is skipped, but Bluetooth pairing + keycard
          // enrollment still run as Stage 1. dashboardPrep handles that and
          // the "skip DBC, finish" button when _skipDbcFlash is set.
          for (final phase in MajorStep.dbc.phases) {
            _skippedPhases.add(phase);
          }
          _setPhase(InstallerPhase.dashboardPrep);
        } else {
          _setPhase(InstallerPhase.cbbReconnect);
        }
      } else {
        _setPhase(InstallerPhase.batteryRemoval);
      }
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.healthCheckHeading,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_mdbInfo != null)
            Text(l10n.firmwareVersionDisplay(_mdbInfo!.firmwareVersion),
                style: TextStyle(color: Colors.grey.shade400)),
          const SizedBox(height: 8),
          Text(l10n.verifyingReadiness,
              style: TextStyle(color: Colors.grey.shade400)),
          if (_isUntestedStockFirmware) ...[
            const SizedBox(height: 16),
            Container(
              width: 400,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber, color: Colors.amber),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.untestedFirmwareHeading,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                        const SizedBox(height: 4),
                        Text(l10n.untestedFirmwareBody(_mdbInfo?.firmwareVersion ?? ''),
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade300)),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () => _openExternalUrl('https://discord.gg/BmY2P2T9j3'),
                          icon: const Icon(Icons.chat_bubble_outline, size: 16, color: Colors.amber),
                          label: Text(l10n.openLibrescootDiscord,
                              style: const TextStyle(color: Colors.amber)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          if (_scooterHealth != null)
            SizedBox(width: 400, child: HealthCheckPanel(health: _scooterHealth!)),

          // Config backup status
          if (_scooterHealth != null && _radioGagaBackupPath != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: SizedBox(
                width: 400,
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(l10n.configBackedUp,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade400))),
                  ],
                ),
              ),
            ),

          // Librescoot detected: offer to skip MDB reflash
          if (_scooterHealth != null && _isLibrescootFirmware) ...[
            const SizedBox(height: 24),
            Container(
              width: 400,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kAccent.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.librescootFirmwareDetected,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: kAccent)),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.skipMdbReflash),
                    subtitle: Text(l10n.keepCurrentMdbFirmware),
                    value: _skipMdbFlash,
                    onChanged: (v) => setState(() => _skipMdbFlash = v ?? false),
                  ),
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.skipDbcFlashOption),
                    subtitle: Text(l10n.onlyFlashMdbSkipDbc),
                    value: _skipDbcFlash,
                    onChanged: (v) => setState(() => _skipDbcFlash = v ?? false),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),
          if (_scooterHealth != null && _scooterHealth!.allOk)
            FilledButton.icon(
              onPressed: proceed,
              icon: const Icon(Icons.arrow_forward),
              label: Text(l10n.continueButton),
            ),
          if (_scooterHealth != null && !_scooterHealth!.allOk) ...[
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _scooterHealth = null;
                  _healthCheckStarted = false;
                });
              },
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retryButton),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: proceed,
              child: Text(l10n.proceedAtOwnRisk,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _runHealthCheck() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isProcessing = true);
    if (_isDryRun) {
      setState(() => _scooterHealth = ScooterHealth()
        ..auxCharge = 75
        ..cbbStateOfHealth = 100
        ..cbbCharge = 92
        ..batteryPresent = true);
      setState(() => _isProcessing = false);
      return;
    }
    try {
      // aux-battery and cb-battery in Redis are bridged from the nRF52 by
      // bluetooth-service. If that was just unmasked and started (resuming
      // an unfinished install) or the MDB only just booted, the hashes are
      // empty for a while and a single read fails every check except main
      // battery presence. Poll until the data lands before rendering the
      // verdict; after the deadline show whatever we have (a genuinely
      // disconnected CBB/AUX should still surface as a failure).
      var health = await _sshService.queryHealth();
      final deadline = DateTime.now().add(const Duration(seconds: 90));
      while ((health.auxCharge == null ||
              health.cbbCharge == null ||
              health.cbbStateOfHealth == null) &&
          DateTime.now().isBefore(deadline)) {
        _setStatus(l10n.waitingForBatteryData);
        await Future.delayed(const Duration(seconds: 3));
        if (!mounted) return;
        health = await _sshService.queryHealth();
      }
      setState(() => _scooterHealth = health);
      await _sshService.logScooterStats('health-check');

      // Back up radio-gaga config before we flash anything
      _setStatus(l10n.backingUpConfig);
      final cacheDir = await DownloadService.getCacheDir();
      final backupPath = await _sshService.backupRadioGagaConfig(cacheDir.path);
      if (backupPath != null) {
        setState(() => _radioGagaBackupPath = backupPath);
        debugPrint('UI: radio-gaga config backed up to $backupPath');
      }
    } catch (e) {
      _setStatus(l10n.healthCheckFailed(e.toString()));
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  bool _batteryRemovalStarted = false;

  Widget _buildBatteryRemoval(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.batteryRemovalHeading,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          if (_scooterHealth?.batteryPresent == true) ...[
            InstructionStep(
              number: 1,
              title: l10n.seatboxOpening,
              description: l10n.seatboxOpeningDesc,
            ),
            InstructionStep(
              number: 2,
              title: l10n.removeMainBattery,
              description: l10n.removeMainBatteryDesc,
            ),
            const SizedBox(height: 16),
            if (!_isProcessing)
              FilledButton(
                onPressed: _openSeatboxAndWaitForBattery,
                child: Text(l10n.openSeatbox),
              ),
            if (_isProcessing) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 8),
              Text(_statusMessage, style: TextStyle(color: Colors.grey.shade400)),
            ],
          ] else ...[
            const Icon(Icons.check_circle, size: 48, color: kAccent),
            const SizedBox(height: 16),
            Text(l10n.mainBatteryAlreadyRemoved),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _setPhase(InstallerPhase.mdbToUms),
              icon: const Icon(Icons.arrow_forward),
              label: Text(l10n.continueButton),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openSeatboxAndWaitForBattery() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isProcessing = true);
    if (_isDryRun) {
      _setStatus('[DRY RUN] Simulating battery removal...');
      await Future.delayed(const Duration(seconds: 1));
      setState(() { _scooterHealth?.batteryPresent = false; _isProcessing = false; });
      _setPhase(InstallerPhase.mdbToUms);
      return;
    }
    _setStatus(l10n.openingSeatbox);
    await _sshService.openSeatbox();

    _setStatus(l10n.waitingForBatteryRemoval);
    debugPrint('Battery: waiting for depart on battery:0');
    while (await _sshService.isBatteryPresent()) {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
    }
    debugPrint('Battery: depart detected on battery:0');
    await _sshService.logScooterStats('battery-removed');

    _setStatus(l10n.batteryRemoved);
    setState(() {
      _scooterHealth?.batteryPresent = false;
      _isProcessing = false;
    });
    _setPhase(InstallerPhase.mdbToUms);
  }
  Widget _buildMdbToUms(AppLocalizations l10n) {
    if (!_mdbToUmsStarted && !_isProcessing) {
      _mdbToUmsStarted = true;
      Future.microtask(_configureMdbUms);
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.configuringMdbBootloader,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (_isProcessing)
            const SizedBox(width: 48, height: 48, child: CircularProgressIndicator()),
          const SizedBox(height: 16),
          Text(_statusMessage.isEmpty ? l10n.preparing : _statusMessage,
              style: TextStyle(color: Colors.grey.shade400)),
          if (!_isProcessing && !_mdbToUmsStarted) ...[
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton.icon(
                  onPressed: () {
                    _mdbToUmsStarted = true;
                    _configureMdbUms();
                  },
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.retryMdbToUms),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: _showLogDialog,
                  icon: const Icon(Icons.article_outlined),
                  label: Text(l10n.showLog),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _configureMdbUms() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isProcessing = true);
    if (_isDryRun) {
      _setStatus('[DRY RUN] Simulating UMS mode...');
      await Future.delayed(const Duration(seconds: 1));
      _setPhase(InstallerPhase.mdbFlash);
      return;
    }
    try {
      _setStatus(l10n.uploadingBootloaderTools);
      await _sshService.configureMassStorageMode();

      // Verify the bootcmd was actually set.
      // fw_setenv behaves as fw_printenv when invoked under that name.
      _setStatus(l10n.verifyingBootloaderConfig);
      try {
        await _sshService.runCommand('ln -sf /tmp/fw_setenv /tmp/fw_printenv');
        final bootcmd = await _sshService.runCommand(
          'fw_printenv bootcmd 2>/dev/null || /tmp/fw_printenv -c /tmp/fw_env.config bootcmd'
        );
        debugPrint('SSH: verified bootcmd = $bootcmd');
        if (!bootcmd.contains('ums')) {
          _setStatus('fw_setenv failed: bootcmd is still: ${bootcmd.trim()}');
          setState(() { _isProcessing = false; _mdbToUmsStarted = false; });
          return;
        }
      } catch (e) {
        debugPrint('SSH: bootcmd verification failed ($e), proceeding');
      }

      // Suppress Windows "format this disk" popup before UMS mode
      await DriverService.suppressAutoPlay();

      _setStatus(l10n.rebootingMdbUms);
      await _sshService.reboot();
      _setStatus(l10n.waitingForUmsDevice);
      final found = await _waitForDevice(DeviceMode.massStorage, timeout: const Duration(seconds: 60));
      if (found) {
        _setPhase(InstallerPhase.mdbFlash);
        return;
      }

      // UMS didn't appear: show retry/log buttons
      _setStatus(l10n.umsNotDetectedTimeout);
    } catch (e) {
      _setStatus('Error: $e');
    }
    setState(() { _isProcessing = false; _mdbToUmsStarted = false; });
  }

  Widget _buildMdbFlash(AppLocalizations l10n) {
    if (!_flashConfirmed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.readyToFlash,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(l10n.readyToFlashHint,
                style: TextStyle(color: Colors.grey.shade400)),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () { _resetRetries('mdbFlash'); setState(() => _flashConfirmed = true); },
              icon: const Icon(Icons.flash_on),
              label: Text(l10n.beginFlashing),
            ),
          ],
        ),
      );
    }

    if (!_mdbFlashStarted && !_isProcessing) {
      _mdbFlashStarted = true;
      Future.microtask(_flashMdb);
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.flashingMdb,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(l10n.flashingMdbSubheading,
              style: TextStyle(color: Colors.grey.shade400)),
          const SizedBox(height: 24),
          SizedBox(
            width: 400,
            child: Column(
              children: [
                LinearProgressIndicator(value: _progress, minHeight: 8),
                const SizedBox(height: 8),
                Text(_statusMessage, style: TextStyle(color: Colors.grey.shade400)),
              ],
            ),
          ),
          if (!_isProcessing && !_mdbFlashStarted) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                setState(() {
                  _mdbFlashStarted = true;
                });
                Future.microtask(_flashMdb);
              },
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retryMdbFlash),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _flashMdb() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isProcessing = true);
    _setCritical(true);

    if (_isDryRun) {
      for (var i = 0; i <= 10; i++) {
        _setStatus('[DRY RUN] Simulating flash... ${i * 10}%', progress: i / 10);
        await Future.delayed(const Duration(milliseconds: 200));
        if (!mounted) return;
      }
      _setPhase(InstallerPhase.scooterPrep);
      return;
    }

    var mdbItem = _downloadState.itemOfType(DownloadItemType.mdbFirmware);
    // Bmap is optional (older releases may not ship one), but if it was
    // queued we must wait for it: flashing the .gz sequentially when a
    // bmap was meant to be used skips the sparse-write fast path.
    var mdbBmapItem = _downloadState.itemOfType(DownloadItemType.mdbBmap);
    if (mdbItem == null || !mdbItem.isComplete ||
        (mdbBmapItem != null && !mdbBmapItem.isComplete)) {
      _setStatus(l10n.waitingForMdbFirmware);
      while (mdbItem == null || !mdbItem.isComplete ||
          (mdbBmapItem != null && !mdbBmapItem.isComplete)) {
        await Future.delayed(const Duration(seconds: 1));
        if (!mounted) return;
        mdbItem = _downloadState.itemOfType(DownloadItemType.mdbFirmware);
        mdbBmapItem = _downloadState.itemOfType(DownloadItemType.mdbBmap);
      }
    }

    try {
      // Resolve the block device path (macOS needs diskutil lookup)
      _setStatus(l10n.waitingForDevicePath);
      String? devicePath;
      for (var i = 0; i < 15; i++) {
        devicePath = _device?.path;
        if (devicePath != null && devicePath.isNotEmpty) break;
        devicePath = await _usbDetector.resolveDevicePath();
        if (devicePath != null && devicePath.isNotEmpty) break;
        await Future.delayed(const Duration(seconds: 1));
        if (!mounted) return;
      }
      if (devicePath == null || devicePath.isEmpty) {
        _setStatus(l10n.noDevicePathFound);
        setState(() { _isProcessing = false; _mdbFlashStarted = false; });
        return;
      }
      debugPrint('Flash: device path resolved: $devicePath');

      final flashService = FlashService()..l10n = l10n;
      final bmapPath = _downloadState.bmapPathFor(DownloadItemType.mdbFirmware);
      await flashService.writeTwoPhase(
        mdbItem.localPath!,
        devicePath,
        bmapPath: bmapPath,
        onProgress: (progress, message) {
          _setStatus(message, progress: progress);
        },
      );

      _setCritical(false);
      // Restore Windows AutoPlay after flashing
      await DriverService.restoreAutoPlay();
      _setStatus(l10n.mdbFlashComplete);
      await Future.delayed(const Duration(seconds: 1));
      _setPhase(InstallerPhase.scooterPrep);
    } catch (e, stackTrace) {
      debugPrint('Flash ERROR: $e');
      debugPrint('Flash STACKTRACE: $stackTrace');
      _setCritical(false);
      await DriverService.restoreAutoPlay();

      final errText = e.toString();
      final midWrite = RegExp(r'write at offset (\d+)').firstMatch(errText);
      final pathGone = errText.contains('No such file or directory') ||
          errText.contains('authopen') ||
          errText.contains('device not configured');

      String diagnosis = errText;
      if (midWrite != null) {
        final offset = int.tryParse(midWrite.group(1)!);
        final mb = offset == null ? '?' : (offset / (1024 * 1024)).toStringAsFixed(1);
        diagnosis += '\n\nDevice stopped responding mid-write at $mb MB. '
            'This is almost always the USB cable or port. '
            'Unplug and replug the USB cable (try a different cable or port), then retry. '
            'Only power-cycle the MDB if the device does not reappear.';
      } else if (pathGone || _device == null) {
        diagnosis += '\n\nDevice is no longer present. '
            'Unplug and replug the USB cable, then retry. '
            'Only power-cycle the MDB if the device does not reappear.';
      } else if (_device!.mode != DeviceMode.massStorage) {
        diagnosis += '\n\nDevice is in ${_device!.mode.name} mode, not mass storage. '
            'Power-cycle the board so u-boot re-enters UMS mode.';
      } else {
        diagnosis += '\n\nDevice is still visible: you can retry.';
      }
      _setStatus(diagnosis);
      setState(() => _isProcessing = false);

      if (!await _shouldRetry('mdbFlash')) return;

      // Wait for the device to come back before re-running the flash —
      // otherwise we burn retries against a stale path that can't be
      // opened. Detector was resumed by _setCritical(false) above.
      _setStatus('$diagnosis\n\nWaiting for the device to be re-detected...');
      final back = await _waitForMassStorageDevice(timeout: const Duration(seconds: 60));
      if (!back) {
        _setStatus('$diagnosis\n\nDevice did not come back within 60s. '
            'Replug the USB (or, as a last resort, power-cycle the MDB) '
            'and use the manual retry button.');
        setState(() => _mdbFlashStarted = false);
        return;
      }
      setState(() => _mdbFlashStarted = false);
    }
  }

  /// Wait until the USB detector reports a mass-storage device with a usable
  /// path again. Returns false on timeout or unmount.
  Future<bool> _waitForMassStorageDevice({required Duration timeout}) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (!mounted) return false;
      if (_device != null && _device!.mode == DeviceMode.massStorage) {
        final path = await _usbDetector.resolveDevicePath();
        if (path != null && path.isNotEmpty) {
          debugPrint('Flash: device reappeared as $path');
          return true;
        }
      }
      await Future.delayed(const Duration(seconds: 1));
    }
    return false;
  }

  Widget _buildScooterPrep(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.scooterPrepHeading,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(l10n.scooterPrepSubheading,
            style: TextStyle(color: Colors.grey.shade400)),
        const SizedBox(height: 24),
        InstructionStep(
          number: 1,
          title: l10n.disconnectCbb,
          description: l10n.disconnectCbbDesc,
          isWarning: true,
          beforeImageAsset: 'assets/images/lsi-unu_scooter_cbb_connected.jpg',
          imageAsset: 'assets/images/lsi-unu_scooter_cbb_disconnected.jpg',
        ),
        InstructionStep(
          number: 2,
          title: l10n.disconnectAuxPole,
          description: l10n.disconnectAuxPoleDesc,
          isWarning: true,
          beforeImageAsset: 'assets/images/lsi-unu_scooter_aux_connected.jpg',
          imageAsset: 'assets/images/lsi-unu_scooter_aux_pos_disconnected.jpg',
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade900.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.shade700),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning, color: Colors.orange),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.auxDisconnectWarning,
                  style: const TextStyle(color: Colors.orange, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: () => _setPhase(InstallerPhase.mdbBoot),
            icon: const Icon(Icons.arrow_forward),
            label: Text(l10n.doneCbbAuxDisconnected),
          ),
        ),
      ],
    );
  }

  Widget _buildMdbBoot(AppLocalizations l10n) {
    if (!_mdbBootStarted && !_isProcessing) {
      _mdbBootStarted = true;
      Future.microtask(_waitForMdbBoot);
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.waitingForMdbBoot,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          InstructionStep(
            number: 1,
            title: l10n.reconnectAuxPole,
            description: l10n.reconnectAuxPoleDesc,
            imageAsset: 'assets/images/lsi-unu_scooter_aux_connected.jpg',
          ),
          const SizedBox(height: 16),
          Text(l10n.dbcLedHint,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          const SizedBox(height: 16),
          if (_isProcessing)
            const SizedBox(width: 48, height: 48, child: CircularProgressIndicator()),
          const SizedBox(height: 8),
          Text(_statusMessage.isEmpty ? l10n.waitingForUsbDevice : _statusMessage,
              style: TextStyle(color: Colors.grey.shade400)),
          if (!_isProcessing && !_mdbBootStarted) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                setState(() => _mdbBootStarted = true);
                Future.microtask(_waitForMdbBoot);
              },
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retryMdbBoot),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _waitForMdbBoot() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isProcessing = true);

    if (_isDryRun) {
      _setStatus('[DRY RUN] Simulating MDB boot...');
      await Future.delayed(const Duration(seconds: 2));
      _setPhase(InstallerPhase.cbbReconnect);
      return;
    }

    _setStatus(l10n.waitingForUsbDevice);
    while (_device == null) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
    }

    if (_device?.mode == DeviceMode.massStorage) {
      _setStatus(l10n.mdbStillUms);
      setState(() {
        _isProcessing = false;
        _mdbFlashStarted = false;
      });
      _setPhase(InstallerPhase.mdbFlash);
      return;
    }

    _setStatus(l10n.mdbDetectedNetwork);

    // Reconfigure the host iface BEFORE pinging. The MDB reboot tears down the
    // cdc_ether USB iface; on Linux+NetworkManager the new iface (often a fresh
    // enxXXXX) doesn't carry our prior unmanaged flag or 192.168.7.50, so pings
    // would never succeed without redoing the static config. configureInterface
    // no-ops if the MDB is already reachable.
    final networkService = NetworkService();
    final iface = await networkService.findLibrescootInterface();
    if (iface != null) {
      try {
        await networkService.configureInterface(iface);
      } on NetworkPrivilegeException catch (e) {
        _setStatus(l10n.errorPrefix(e.toString()));
        setState(() { _isProcessing = false; _mdbBootStarted = false; });
        return;
      }
    }

    var stableCount = 0;
    var failedSeconds = 0;
    var diagnosticsLogged = false;
    while (stableCount < 10) {
      final reachable = await _pingMdb();
      if (reachable) {
        stableCount++;
        failedSeconds = 0;
        _setStatus(l10n.pingStable(stableCount));
      } else {
        stableCount = 0;
        failedSeconds++;
        if (failedSeconds >= 15 && !diagnosticsLogged && Platform.isLinux && iface != null) {
          diagnosticsLogged = true;
          final diag = await networkService.gatherLinuxDiagnostics(iface.name);
          debugPrint('Network: stable-ping stalled ${failedSeconds}s on ${iface.name}.\n$diag');
          _setStatus(l10n.stableConnectionStallHint);
        } else if (!diagnosticsLogged) {
          _setStatus(l10n.waitingStableConnection);
        }
      }
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
    }

    _setStatus(l10n.reconnectingSsh);
    try {
      await _sshService.connectToMdb();

      // MDB has booted the freshly-flashed image and we have SSH back: persist
      // the resume point so an interruption during Stage 1 (BT/keycard/DBC
      // upload) resumes from here instead of re-flashing the MDB.
      try {
        await _sshService.writeInstallState(_baseInstallState(InstallPhase.mdbBooted));
      } catch (e) {
        debugPrint('UI: failed to write install state (mdb-booted), non-fatal: $e');
      }

      // Disable keycard-service for the rest of the install. A freshly flashed
      // MDB boots into auto-master-learn mode; any tap before the explicit
      // keycard-setup phase would silently teach in a master card. We re-start
      // the service on entry to that phase, after disengaging master mode.
      try {
        await _sshService.runCommand('systemctl stop librescoot-keycard 2>/dev/null; true');
        debugPrint('SSH: stopped librescoot-keycard to prevent accidental master teach-in');
      } catch (_) {}

      // Reapply the install-time scooter config on the freshly-flashed image:
      // usb0 must stay up while the scooter is locked (so we keep RNDIS for
      // the rest of the install), auto-standby and the alarm must be off so
      // the next 10–20 minutes of DBC flash + BT pairing + keycard setup
      // don't put the MDB into suspend or honk the alarm at the workshop.
      // All three get reset at finish — see _resetPersistedSettings.
      try {
        await _sshService.runCommand('lsc set scooter.usb0-policy always-on');
        debugPrint('UI: scooter.usb0-policy=always-on (mdb-boot)');
      } catch (e) {
        debugPrint('UI: failed to set scooter.usb0-policy=always-on at mdb-boot (ok): $e');
      }
      await _disableInstallerHazards(label: 'mdb-boot');

      // Restore radio-gaga config if we backed it up
      if (_radioGagaBackupPath != null) {
        _setStatus(l10n.restoringConfig);
        final restored = await _sshService.restoreRadioGagaConfig(_radioGagaBackupPath!);
        if (restored) {
          debugPrint('UI: radio-gaga config restored to /data/radio-gaga/');
        }
      }

      if (_skipDbcFlash) {
        // Even when skipping the DBC flash, Stage 1 (BT + keycard) still runs.
        _setPhase(InstallerPhase.dashboardPrep);
      } else {
        _setPhase(InstallerPhase.cbbReconnect);
      }
    } catch (e) {
      _setStatus(l10n.sshReconnectionFailed(e.toString()));
    }
    setState(() { _isProcessing = false; _mdbBootStarted = false; });
  }

  Future<bool> _pingMdb() async {
    try {
      final result = await Process.run('ping', [
        if (Platform.isWindows) ...['-n', '1', '-w', '1000'] else ...['-c', '1', '-W', '1'],
        '192.168.7.1',
      ]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  // Stop the boot-LED blinker started on MDB by /data/onboot.sh (green on
  // success / red on failure). onboot.sh runs the loop as a transient
  // systemd-run unit (librescoot-bootled-blink) in its own cgroup so it
  // survives onboot.sh exiting, which means `systemctl stop` is the only
  // thing that actually ends it. The PID-file kill below is legacy cleanup
  // for older images that drove the blink via /data/bootled-blink.pid; the
  // i2cset calls are the final LED-off once the loop is gone (do them last,
  // after the loop is stopped, or it just re-asserts the colour 400ms
  // later). The boot-LED guard re-asserts amber every 2s, so stop it too.
  // Both drive the LP5562 over the same i2c bus the keycard reader uses.
  Future<void> _stopBootLedBlink() async {
    if (_isDryRun) return;
    try {
      await _sshService.runCommand(
        r'''systemctl stop librescoot-bootled-blink.service 2>/dev/null; systemctl stop librescoot-bootled-guard.service 2>/dev/null; [ -f /data/bootled-blink.pid ] && kill "$(cat /data/bootled-blink.pid)" 2>/dev/null; rm -f /data/bootled-blink.pid; i2cset -f -y 2 0x30 0x02 0x00 2>/dev/null; i2cset -f -y 2 0x30 0x03 0x00 2>/dev/null; i2cset -f -y 2 0x30 0x04 0x00 2>/dev/null; true''',
      );
      debugPrint('SSH: stopped boot LED blink');
    } catch (_) {}
  }
  bool _cbbAutoCheckStarted = false;
  bool _cbbDetected = false;
  bool _batteryDetected = false;
  bool _cbbWaitNoticeShown = false;

  // Poll for CBB presence. Up to 3 minutes (90 × 2s); flips _cbbWaitNoticeShown
  // after 30s so the "be patient" notice appears.
  static const int _cbbPollIterations = 90;
  static const int _cbbNoticeAfterIterations = 15;

  Future<bool> _pollForCbb(AppLocalizations l10n) async {
    if (_isDryRun) {
      _setStatus('[DRY RUN] CBB detected');
      await Future.delayed(const Duration(seconds: 1));
      return true;
    }
    // Force the nRF52 to re-emit every cached field on the next 1s tick,
    // so any stale `present=true` latched in its old_* cache (e.g. from a
    // disconnect that happened while the data stream was off) gets cleared
    // before the user reconnects the cable. Best-effort; ignore errors.
    try {
      await _sshService.redisLpush('scooter:bluetooth', 'data-stream-sync');
    } catch (e) {
      debugPrint('CBB: data-stream-sync failed (non-fatal): $e');
    }
    debugPrint('CBB: waiting for insert on cb-battery');
    for (var i = 0; i < _cbbPollIterations; i++) {
      if (!mounted) return false;
      if (await _sshService.isCbbPresent()) {
        debugPrint('CBB: insert detected on cb-battery');
        return true;
      }
      if (!mounted) return false;
      if (i + 1 == _cbbNoticeAfterIterations && !_cbbWaitNoticeShown) {
        setState(() => _cbbWaitNoticeShown = true);
      }
      _setStatus(l10n.waitingForCbb(i + 1));
      await Future.delayed(const Duration(seconds: 2));
    }
    debugPrint('CBB: poll timed out (no insert seen)');
    return false;
  }

  Widget _buildCbbReconnect(AppLocalizations l10n) {
    // Auto-check CBB on enter: poll for up to 3 minutes
    if (!_cbbAutoCheckStarted && !_isProcessing) {
      _cbbAutoCheckStarted = true;
      Future.microtask(() async {
        if (mounted) setState(() => _isProcessing = true);
        _setStatus(l10n.checkingCbb);
        final detected = await _pollForCbb(l10n);
        if (!mounted) return;
        setState(() {
          _cbbDetected = detected;
          _isProcessing = false;
        });
        _setStatus('');
        if (detected) {
          final bat = _isDryRun ? true : await _sshService.isBatteryPresent();
          if (bat) {
            debugPrint('Battery: insert detected on battery:0');
            await _sshService.logScooterStats('cbb-and-battery-reconnected');
          }
          if (mounted) {
            setState(() => _batteryDetected = bat);
            if (bat) _setPhase(InstallerPhase.dashboardPrep);
          }
        }
      });
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.reconnectCbbHeading,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),

          // Step 1: Reconnect CBB
          InstructionStep(
            number: 1,
            title: l10n.reconnectCbbStep,
            description: l10n.reconnectCbbStepDesc,
            imageAsset: 'assets/images/lsi-unu_scooter_cbb_connected.jpg',
          ),
          if (_cbbDetected)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, size: 16, color: kAccent),
                const SizedBox(width: 8),
                Text(l10n.cbbDetected, style: const TextStyle(color: kAccent, fontSize: 13)),
              ],
            )
          else ...[
            if (_cbbWaitNoticeShown)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
                child: Text(
                  l10n.cbbDetectionMayTakeMinutes,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ),
            if (!_isProcessing)
              FilledButton(
                onPressed: () async {
                  setState(() => _isProcessing = true);
                  _setStatus(l10n.checkingCbb);
                  final detected = await _pollForCbb(l10n);
                  if (!mounted) return;
                  if (detected) {
                    setState(() { _cbbDetected = true; _isProcessing = false; });
                    _setStatus('');
                  } else {
                    _setStatus(l10n.cbbNotDetected);
                    setState(() { _isProcessing = false; _cbbDetected = false; });
                  }
                },
                child: Text(l10n.verifyCbbConnection),
              ),
          ],

          const SizedBox(height: 16),

          // Step 2: Insert battery (greyed out until CBB connected)
          Opacity(
            opacity: _cbbDetected ? 1.0 : 0.4,
            child: Column(
              children: [
                InstructionStep(
                  number: 2,
                  title: l10n.insertMainBatteryStep,
                  description: l10n.insertMainBatteryStepDesc,
                ),
                if (_cbbDetected) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _sshService.isConnected ? () async {
                          try { await _sshService.runCommand('lsc open'); } catch (_) {}
                        } : null,
                        icon: const Icon(Icons.lock_open, size: 18),
                        label: Text(l10n.openSeatboxButton),
                      ),
                    ],
                  ),
                  if (_batteryDetected)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle, size: 16, color: kAccent),
                          const SizedBox(width: 8),
                          Text(l10n.batteryDetected, style: const TextStyle(color: kAccent, fontSize: 13)),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),
          if (_isProcessing) ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 8),
            Text(_statusMessage, style: TextStyle(color: Colors.grey.shade400)),
          ] else if (_cbbDetected) ...[
            FilledButton(
              onPressed: () async {
                setState(() => _isProcessing = true);
                _setStatus(l10n.checkingCbbAndBattery);
                final bat = _isDryRun ? true : await _sshService.isBatteryPresent();
                if (bat) {
                  debugPrint('Battery: insert detected on battery:0 (manual verify)');
                  await _sshService.logScooterStats('cbb-and-battery-reconnected');
                  setState(() { _batteryDetected = true; _isProcessing = false; });
                  await Future.delayed(const Duration(seconds: 1));
                  if (mounted) _setPhase(InstallerPhase.dashboardPrep);
                } else {
                  _setStatus(l10n.cbbNotDetected);
                  setState(() => _isProcessing = false);
                }
              },
              child: Text(l10n.verifyBatteryPresence),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => _setPhase(InstallerPhase.dashboardPrep),
              child: Text(l10n.proceedWithoutCbb,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            ),
          ] else ...[
            TextButton(
              onPressed: () {
                setState(() => _cbbDetected = true);
              },
              child: Text(l10n.proceedWithoutCbb,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _waitForCbb() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isProcessing = true);
    if (_isDryRun) {
      _setStatus('[DRY RUN] CBB connected');
      await Future.delayed(const Duration(seconds: 1));
      _setPhase(InstallerPhase.dashboardPrep);
      return;
    }
    _setStatus(l10n.checkingCbbAndBattery);
    var attempts = 0;
    while (attempts < 30) {
      if (await _sshService.isCbbPresent()) {
        _setStatus(l10n.cbbConnected);
        await Future.delayed(const Duration(seconds: 1));
        _setPhase(InstallerPhase.dashboardPrep);
        return;
      }
      attempts++;
      _setStatus(l10n.waitingForCbb(attempts));
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
    }
    _setStatus(l10n.cbbNotDetected);
    setState(() {
      _isProcessing = false;
      _cbbCheckFailed = true;
    });
  }

  /// Stage 1: pair Bluetooth and enroll keycards in the foreground while the
  /// DBC image/tiles upload runs in the background. The "Begin flashing DBC"
  /// button unlocks only once BT is done-or-skipped, keycard is
  /// done-or-skipped, and the background upload has completed.
  Widget _buildDashboardPrep(AppLocalizations l10n) {
    // Kick off the background upload once, on first entry. The upload itself
    // doesn't navigate; it just flips _dbcUploadReady when finished. When the
    // DBC flash is skipped there is nothing to upload, so treat it as ready.
    if (!_dashboardPrepStarted) {
      _dashboardPrepStarted = true;
      if (_skipDbcFlash) {
        _dbcUploadReady = true;
      } else {
        Future.microtask(_uploadDbcFiles);
      }
    }

    final btSatisfied = _btDone || _btSkipped;
    final keycardSatisfied = _keycardDone || _keycardSkipped;
    final beginEnabled =
        btSatisfied && keycardSatisfied && _dbcUploadReady && !_isProcessing;

    final Widget interactive;
    if (_dashboardPrepStep == _DashboardPrepStep.bluetooth) {
      interactive = _bluetoothPairingContent(l10n);
    } else {
      interactive = _keycardSetupContent(l10n);
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // No upload to show when the DBC flash is being skipped.
            if (!_skipDbcFlash) ...[
              _dbcUploadProgressStrip(l10n),
              const SizedBox(height: 24),
            ],
            interactive,
            const SizedBox(height: 24),
            Center(
              child: FilledButton.icon(
                onPressed: beginEnabled ? _onBeginFlashingDbc : null,
                icon: Icon(_skipDbcFlash ? Icons.arrow_forward : Icons.bolt),
                label: Text(_skipDbcFlash ? l10n.skipDbcFlashOption : l10n.dbcReadyButton),
              ),
            ),
            if (!beginEnabled) ...[
              const SizedBox(height: 8),
              Center(
                child: Text(
                  !_dbcUploadReady ? l10n.waitingForDownloads : l10n.finishStepsAboveToContinue,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Small persistent strip showing the background DBC upload progress while
  /// the user works through BT pairing + keycard enrollment.
  Widget _dbcUploadProgressStrip(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                _dbcUploadReady ? Icons.check_circle : Icons.cloud_upload_outlined,
                size: 18,
                color: _dbcUploadReady ? kAccent : Colors.grey.shade400,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _dbcUploadReady ? l10n.dbcFlashSuccessful : l10n.preparingDbcFlash,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (!_dbcUploadReady) ...[
            LinearProgressIndicator(value: _progress > 0 ? _progress : null, minHeight: 6),
            const SizedBox(height: 8),
            if (_dbcPrepSubsteps.isNotEmpty)
              SubstepList(substeps: _dbcPrepSubsteps)
            else
              Text(_statusMessage,
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
            // Upload failed (not processing, not ready): offer a retry.
            if (!_isProcessing) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() => _dbcPrepSubsteps = const []);
                    Future.microtask(_uploadDbcFiles);
                  },
                  icon: const Icon(Icons.refresh, size: 16),
                  label: Text(l10n.retryDbcPrep),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  /// "Begin flashing DBC" handler for the Stage-1 screen. Arms the trampoline
  /// (last thing over SSH) and hands off to the cable-swap screen. When the
  /// user opted to skip the DBC flash entirely, jump straight to finish.
  Future<void> _onBeginFlashingDbc() async {
    if (_skipDbcFlash) {
      _setPhase(InstallerPhase.finish);
      return;
    }
    await _startTrampoline();
  }

  Future<void> _uploadDbcFiles() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isProcessing = true);
    _setCritical(true);

    setState(() => _dbcUploadReady = false);

    if (_isDryRun) {
      _setStatus('[DRY RUN] Simulating DBC upload...');
      await Future.delayed(const Duration(seconds: 1));
      _setCritical(false);
      setState(() { _isProcessing = false; _dbcUploadReady = true; });
      return;
    }

    if (!_downloadState.allReady) {
      _setStatus(l10n.waitingForDownloads);
      while (!_downloadState.allReady) {
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) setState(() {});
        if (!mounted) return;
      }
    }

    try {
      final trampolineService = TrampolineService(_sshService);
      final dbcItem = _downloadState.itemOfType(DownloadItemType.dbcFirmware);
      final osmItem = _downloadState.itemOfType(DownloadItemType.osmTiles);
      final valhallaItem = _downloadState.itemOfType(DownloadItemType.valhallaTiles);

      final dbcBmapItem = _downloadState.itemOfType(DownloadItemType.dbcBmap);

      await trampolineService.uploadAll(
        dbcImageLocalPath: dbcItem!.localPath!,
        dbcBmapLocalPath: dbcBmapItem?.localPath,
        osmTilesLocalPath: osmItem?.localPath,
        valhallaTilesLocalPath: valhallaItem?.localPath,
        region: _downloadState.selectedRegion,
        // Identity-based idempotent skip: the trampoline compares this against
        // the DBC's os-release VERSION_ID over SSH and skips the destructive
        // flash if they match. releaseTag is the version/tag of the release
        // being installed; an empty tag simply never triggers the skip.
        targetDbcVersion: _downloadState.releaseTag ?? '',
        forceDbcReflash: false,
        onProgress: (status, progress) {
          _setStatus(status, progress: progress);
        },
        onSubsteps: (steps) {
          if (mounted) setState(() => _dbcPrepSubsteps = steps);
        },
      );

      // Upload is done, but DON'T start the trampoline yet. The trampoline's
      // first act is to wait for the laptop to disconnect, after which the
      // install runs autonomously and we lose SSH. Stay on this page and
      // surface the "Begin flashing DBC" button instead, so the user
      // explicitly confirms before that point of no return. The cable-swap
      // instructions only appear on the next screen, after the trampoline
      // has started, so nobody can swap the cable before start() runs.
      try {
        await _sshService.writeInstallState(_baseInstallState(InstallPhase.dbcStaged));
      } catch (e) {
        debugPrint('UI: failed to write install state (dbc-staged), non-fatal: $e');
      }
      _setCritical(false);
      if (mounted) setState(() { _isProcessing = false; _dbcUploadReady = true; });
    } catch (e) {
      _setCritical(false);
      _setStatus(l10n.uploadError(e.toString()));
      debugPrint('DBC prep error: $e');
      if (mounted) setState(() => _isProcessing = false);
      // _dbcUploadReady stays false; the upload-progress strip's retry button
      // re-runs _uploadDbcFiles.
    }
  }

  /// Confirm handler for the "Begin flashing DBC" button on the Stage-1 page:
  /// fire the trampoline (the last thing we do over SSH) and hand off to the
  /// swap-cables screen, which is the first place the user is told to touch
  /// the cable.
  Future<void> _startTrampoline() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() { _isProcessing = true; });
    _setCritical(true);

    if (_isDryRun) {
      _setStatus('[DRY RUN] Simulating trampoline start...');
      await Future.delayed(const Duration(seconds: 1));
      _setCritical(false);
      setState(() => _isProcessing = false);
      _setPhase(InstallerPhase.dbcSwapAndFlash);
      return;
    }

    try {
      _setStatus(l10n.startingTrampoline);
      await TrampolineService(_sshService).start();
      try {
        await _sshService.writeInstallState(_baseInstallState(InstallPhase.trampolineArmed));
      } catch (e) {
        debugPrint('UI: failed to write install state (trampoline-armed), non-fatal: $e');
      }
      _setCritical(false);
      setState(() => _isProcessing = false);
      await Future.delayed(const Duration(seconds: 1));
      _setPhase(InstallerPhase.dbcSwapAndFlash);
    } catch (e) {
      _setCritical(false);
      _setStatus(l10n.uploadError(e.toString()));
      debugPrint('Trampoline start error: $e');
      // The upload is still intact; the Begin button stays enabled so the user
      // can retry instead of being demoted to a full prep retry over a
      // transient SSH error.
      setState(() { _isProcessing = false; });
    }
  }

  bool _dbcFlashWatchStarted = false;
  bool _dbcUsbDisconnected = false;
  List<Substep> _dbcPrepSubsteps = const [];
  List<Substep> _reconnectSubsteps = const [];
  DateTime? _reconnectRndisWaitStart;
  DateTime? _reconnectStatusWaitStart;
  bool _reconnectShowDiagnostics = false;
  String? _reconnectDiagnostics;

  Widget _buildDbcSwapAndFlash(AppLocalizations l10n) {
    // Watch for the laptop USB cable being unplugged so we can flip from the
    // swap-cables instructions to the in-progress view. On the happy path we
    // do NOT poll the MDB or auto-advance; the user confirms via the buttons.
    if (!_dbcFlashWatchStarted) {
      _dbcFlashWatchStarted = true;
      _watchDbcFlash();
    }

    if (!_dbcUsbDisconnected) {
      // Step 1: waiting for user to swap cables. The trampoline is already
      // running and waiting for the laptop to disconnect, so this is the
      // first place we tell the user to touch the cable.
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.dbcFlashSwapCablesTitle,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              // Move the same MDB USB plug from the laptop cable to the DBC
              // cable. Photos are self-labelled ("Laptop"/"DBC"), so the
              // arrow between them carries the meaning without extra captions.
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.asset('assets/images/lsi-mdb_usb_laptop.jpg',
                            fit: BoxFit.cover),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(Icons.arrow_forward, color: kAccent, size: 28),
                  ),
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.asset('assets/images/lsi-mdb_usb_dbc.jpg',
                            fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              InstructionStep(
                number: 1,
                title: l10n.disconnectUsbFromLaptop,
                description: l10n.disconnectUsbFromLaptopDesc,
              ),
              InstructionStep(
                number: 2,
                title: l10n.reconnectDbcUsbToMdb,
                description: l10n.reconnectDbcUsbToMdbDesc,
              ),
              const SizedBox(height: 16),
              Text(l10n.waitingForUsbDisconnect,
                  style: TextStyle(color: Colors.grey.shade400),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      );
    }

    // Step 2: USB disconnected: MDB is flashing autonomously.
    //
    // Once the cable is unplugged we have NO link to the MDB until it
    // comes back as RNDIS. The MDB no longer drives a per-phase progress
    // LED, so this is a walk-away screen: tell the user the swap is done,
    // they can leave for a few minutes, and how to read the outcome (the
    // dashboard lights up = done; hazards/red light = something went wrong).
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.dbcFlashInProgress,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.14),
                border: Border.all(color: Colors.orange.shade700, width: 2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.schedule, color: Colors.orange.shade300, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n.dbcWalkAwayHeadline,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade100,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.dbcWalkAwayBody,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.orange.shade100,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade800),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _walkAwayOutcome(
                    Icons.check_circle,
                    Colors.green,
                    l10n.dbcWalkAwayDashboardLit,
                  ),
                  const SizedBox(height: 10),
                  _walkAwayOutcome(
                    Icons.error,
                    Colors.red,
                    l10n.dbcWalkAwayFailure,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                // Happy path: the dashboard powered on. No MDB reconnect, no
                // verify; we trust the lit display and finish.
                FilledButton.icon(
                  onPressed: () => _setPhase(InstallerPhase.finish),
                  icon: const Icon(Icons.check_circle, color: Colors.green),
                  label: Text(l10n.dbcWalkAwayDashboardLitButton),
                ),
                // Failure path: reconnect the laptop and run the verify logic
                // to surface the trampoline error log.
                OutlinedButton.icon(
                  onPressed: () {
                    _dbcFlashSimulateError = true;
                    _setPhase(InstallerPhase.reconnect);
                  },
                  icon: const Icon(Icons.error, color: Colors.red),
                  label: Text(l10n.dbcWalkAwayWentWrongButton),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // One outcome line on the walk-away screen: an icon plus the guidance for
  // that outcome (dashboard lit = done, hazards/red = something went wrong).
  Widget _walkAwayOutcome(IconData icon, Color color, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.grey.shade300, fontSize: 13, height: 1.4),
          ),
        ),
      ],
    );
  }

  Future<void> _watchDbcFlash() async {
    // Detect the connected → disconnected transition, not the static null
    // state. If `_device` happens to be momentarily null when this watcher
    // starts (USB detector poll lag, brief enumeration glitch right after
    // trampoline upload), we'd otherwise skip the prep screen entirely and
    // go straight to the autonomous flash view — leaving the user without
    // the disconnect-USB-and-plug-into-DBC instructions.
    //
    // Wait for the device to be present first (10s grace), then wait for
    // it to actually go away.
    final presentDeadline = DateTime.now().add(const Duration(seconds: 10));
    while (mounted && _device == null && DateTime.now().isBefore(presentDeadline)) {
      await Future.delayed(const Duration(milliseconds: 500));
    }
    while (mounted && _device != null) {
      await Future.delayed(const Duration(seconds: 1));
    }
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _dbcUsbDisconnected = true);
    _setStatus(l10n.mdbDisconnectedFlashingDbc);
    // Happy path stops here: the laptop is out of the loop and the scooter
    // flashes the DBC on its own. The user confirms completion with the
    // "dashboard lit up" button; the failure affordance routes to the verify
    // logic. We deliberately do NOT poll the MDB or auto-advance here anymore.
  }

  Widget _buildReconnect(AppLocalizations l10n) {
    if (!_reconnectStarted && !_isProcessing) {
      _reconnectStarted = true;
      Future.microtask(_verifyDbcFlash);
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.verifyingDbcInstallation,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            if (_reconnectSubsteps.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade800),
                ),
                child: SubstepList(substeps: _reconnectSubsteps),
              )
            else
              Center(
                child: Text(
                  _statusMessage.isEmpty ? l10n.reconnectUsbToLaptop : _statusMessage,
                  style: TextStyle(color: Colors.grey.shade400),
                  textAlign: TextAlign.center,
                ),
              ),
            if (_reconnectShowDiagnostics) ...[
              const SizedBox(height: 16),
              _buildReconnectDiagnosticsPanel(l10n),
            ],
            if (!_isProcessing) ...[
              const SizedBox(height: 16),
              Center(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: () {
                        setState(() {
                          _reconnectStarted = true;
                          _reconnectShowDiagnostics = false;
                          _reconnectDiagnostics = null;
                        });
                        Future.microtask(_verifyDbcFlash);
                      },
                      icon: const Icon(Icons.refresh),
                      label: Text(l10n.retryVerification),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        // Re-arm from Stage 1: BT + keycard are already done
                        // (their flags persist), so dashboardPrep re-runs only
                        // the upload, then the user re-confirms Begin.
                        setState(() {
                          _dashboardPrepStarted = false;
                          _dashboardPrepStep = _DashboardPrepStep.bluetooth;
                          _dbcUploadReady = false;
                          _reconnectStarted = false;
                          _reconnectShowDiagnostics = false;
                          _reconnectDiagnostics = null;
                          _reconnectSubsteps = const [];
                          _dbcPrepSubsteps = const [];
                        });
                        _setPhase(InstallerPhase.dashboardPrep);
                      },
                      icon: const Icon(Icons.replay),
                      label: Text(l10n.retryDbcFlash),
                    ),
                    TextButton(
                      onPressed: () => _setPhase(InstallerPhase.finish),
                      child: Text(l10n.skipToFinish),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReconnectDiagnosticsPanel(AppLocalizations l10n) {
    final waitedSecs = _reconnectRndisWaitStart != null
        ? DateTime.now().difference(_reconnectRndisWaitStart!).inSeconds
        : (_reconnectStatusWaitStart != null
            ? DateTime.now().difference(_reconnectStatusWaitStart!).inSeconds
            : 0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.10),
        border: Border.all(color: Colors.orange.shade700),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange.shade300, size: 22),
              const SizedBox(width: 8),
              Text(l10n.reconnectTimeoutHeading,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade100,
                    fontSize: 15,
                  )),
            ],
          ),
          const SizedBox(height: 6),
          Text(l10n.reconnectTimeoutBody(waitedSecs ~/ 60),
              style: TextStyle(color: Colors.orange.shade100, fontSize: 13)),
          const SizedBox(height: 10),
          Text(
            '${l10n.usbDeviceCurrentlyDetected}: '
            '${_device?.name ?? l10n.usbDeviceNone}',
            style: TextStyle(color: Colors.grey.shade300, fontSize: 12),
          ),
          if (_reconnectDiagnostics != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(maxHeight: 160),
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(4),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  _reconnectDiagnostics!,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _verifyDbcFlash() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isProcessing = true;
      _reconnectShowDiagnostics = false;
      _reconnectDiagnostics = null;
      _reconnectSubsteps = [
        Substep(id: 'rndis', label: l10n.substepWaitRndis),
        Substep(id: 'net', label: l10n.substepConfigureNetwork),
        Substep(id: 'ssh', label: l10n.substepConnectSsh),
        Substep(id: 'hazards', label: l10n.substepDisableHazards),
        Substep(id: 'status', label: l10n.substepReadStatus),
      ];
    });
    void setStep(String id, SubstepState state, {String? detail}) {
      if (!mounted) return;
      setState(() {
        final idx = _reconnectSubsteps.indexWhere((s) => s.id == id);
        if (idx < 0) return;
        _reconnectSubsteps = [
          for (var i = 0; i < _reconnectSubsteps.length; i++)
            if (i == idx) _reconnectSubsteps[i].copyWith(state: state, detail: detail)
            else _reconnectSubsteps[i],
        ];
      });
    }

    if (_isDryRun) {
      await Future.delayed(const Duration(seconds: 1));
      if (_dbcFlashSimulateError) {
        _setStatus('[DRY RUN] DBC flash failed!');
        setState(() => _isProcessing = false);
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(l10n.dbcFlashError),
              content: const SingleChildScrollView(
                child: SelectableText(
                  '12:34:56 Trampoline started\n'
                  '12:34:57 Waiting for laptop to disconnect...\n'
                  '12:35:02 Laptop disconnected\n'
                  '12:35:03 Powering on DBC...\n'
                  '12:35:18 DBC is reachable\n'
                  '12:35:19 Configuring DBC bootloader...\n'
                  '12:35:25 Rebooting DBC...\n'
                  '12:35:30 Switching USB to host mode...\n'
                  '12:35:32 Waiting for DBC UMS device...\n'
                  '12:37:32 ERROR: DBC UMS device not found within 120s',
                  style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.closeButton)),
              ],
            ),
          );
        }
        return;
      }
      _setStatus('[DRY RUN] DBC flash successful!');
      _setPhase(InstallerPhase.finish);
      return;
    }

    setStep('rndis', SubstepState.active);
    _setStatus(l10n.waitingForRndisDevice);
    _reconnectRndisWaitStart = DateTime.now();
    final rndisOk = await _waitForRndisWithTimeout(l10n, setStep);
    _reconnectRndisWaitStart = null;
    if (!rndisOk) return;
    setStep('rndis', SubstepState.done);
    // RNDIS came back: pop the timeout panel even if it was showing.
    if (_reconnectShowDiagnostics) {
      setState(() {
        _reconnectShowDiagnostics = false;
        _reconnectDiagnostics = null;
      });
    }

    setStep('net', SubstepState.active);
    _setStatus(l10n.configuringNetwork);
    final iface = await NetworkService().findLibrescootInterface();
    if (iface != null) {
      try {
        await NetworkService().configureInterface(iface);
      } on NetworkPrivilegeException catch (e) {
        setStep('net', SubstepState.failed, detail: e.toString());
        _setStatus(l10n.errorPrefix(e.toString()));
        setState(() { _isProcessing = false; _reconnectStarted = false; });
        return;
      }
    }
    setStep('net', SubstepState.done);

    setStep('ssh', SubstepState.active);
    _setStatus(l10n.connectingSsh);
    try {
      await _sshService.connectToMdb();
    } catch (e) {
      setStep('ssh', SubstepState.failed, detail: e.toString());
      _setStatus(l10n.sshConnectionFailed(e.toString()));
      setState(() { _isProcessing = false; _reconnectStarted = false; });
      return;
    }
    setStep('ssh', SubstepState.done);

    setStep('hazards', SubstepState.active);
    // Freshly-flashed image boots with default settings (alarm.enabled=true,
    // auto-standby=900s). With the scooter locked + stood up on the lift in
    // the workshop, alarm-service will arm and trip on any vibration during
    // bluetooth pairing or keycard setup. Disable both before either phase.
    await _disableInstallerHazards(label: 'reconnect');
    setStep('hazards', SubstepState.done);

    setStep('status', SubstepState.active);
    // Poll for trampoline status. A slow DBC first-boot (resize2fs on a
    // fresh filesystem) can take 5–10 minutes. Give it 5 minutes of quiet
    // polling, then surface the diagnostic panel — user can keep waiting,
    // retry, or skip.
    _setStatus(l10n.readingTrampolineStatus);
    _reconnectStatusWaitStart = DateTime.now();
    TrampolineStatus status;
    final pollStart = DateTime.now();
    while (true) {
      status = await _sshService.readTrampolineStatus();
      if (status.result != TrampolineResult.unknown) break;
      final elapsed = DateTime.now().difference(pollStart).inSeconds;
      debugPrint('Trampoline: status still unknown after ${elapsed}s, waiting...');
      _setStatus(l10n.readingTrampolineStatusElapsed(elapsed));
      setStep('status', SubstepState.active,
          detail: l10n.readingTrampolineStatusElapsed(elapsed));
      if (elapsed >= 300 && !_reconnectShowDiagnostics) {
        await _surfaceReconnectDiagnostics(l10n);
      }
      await Future.delayed(const Duration(seconds: 5));
      if (!mounted) return;
      if (_currentPhase != InstallerPhase.reconnect) return;
    }
    _reconnectStatusWaitStart = null;
    setStep('status', SubstepState.done);

    // Re-stop librescoot-keycard in case onboot.sh on the DBC-side flash
    // brought it back up. We deliberately keep it stopped through bluetooth
    // pairing so a stray tap can't silently teach in a master card. The
    // keycard-setup phase starts it again after disengaging auto-master-learn.
    try {
      await _sshService.runCommand('systemctl stop librescoot-keycard 2>/dev/null; true');
    } catch (_) {}

    if (status.result == TrampolineResult.success) {
      // The green success-blink onboot.sh started means "safe to swap the
      // MDB's USB port back to the laptop". We only get here because the
      // laptop is already back on USB (that's how we read the status), so
      // the cue has done its job — stop it now. BT pairing and keycard setup
      // already happened in Stage 1, so a confirmed flash goes straight to
      // finish.
      await _stopBootLedBlink();
      _setStatus(l10n.dbcFlashSuccessful);
      await Future.delayed(const Duration(seconds: 2));
      _setPhase(InstallerPhase.finish);
    } else if (status.result == TrampolineResult.error) {
      // Quiet the failure indicators (red blink + hazards) now that we're
      // about to surface the actual error to the user. The helper also
      // unmasks librescoot-keycard so a later reboot has a working reader.
      try {
        await _sshService.runCommand(
          '[ -x /data/installer/stop-error-signals.sh ] && /data/installer/stop-error-signals.sh; '
          '[ -x /data/stop-error-signals.sh ] && /data/stop-error-signals.sh; true',
        );
      } catch (_) {}
      _setStatus(l10n.dbcFlashFailed(status.message ?? ''));
      if (mounted && status.errorLog != null) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.dbcFlashError),
            content: SingleChildScrollView(
              child: SelectableText(status.errorLog!,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.closeButton)),
            ],
          ),
        );
      }
      setState(() => _isProcessing = false);
    } else {
      _setStatus(l10n.trampolineStatusUnknown);
      setState(() => _isProcessing = false);
    }
  }

  Widget _buildBluetoothPairing(AppLocalizations l10n) {
    return Center(child: _bluetoothPairingContent(l10n));
  }

  /// Inner content of the Bluetooth pairing step, without the outer page
  /// scaffold. Reused both as the standalone phase and as the first
  /// interactive sub-step of the Stage-1 dashboardPrep screen.
  Widget _bluetoothPairingContent(AppLocalizations l10n) {
    return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bluetooth, size: 48, color: Colors.blueAccent),
          const SizedBox(height: 16),
          Text(l10n.bluetoothPairingHeading,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(l10n.bluetoothPairingHint,
              style: TextStyle(color: Colors.grey.shade400)),
          if (_bleMac != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${l10n.bleMacLabel}: ',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
                  SelectableText(_bleMac!,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace')),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),

          if (!_btPairingActive) ...[
            FilledButton.icon(
              onPressed: _startBluetoothPairing,
              icon: const Icon(Icons.bluetooth_searching),
              label: Text(l10n.startPairing),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _skipBluetoothPairing,
              child: Text(l10n.skipPairing),
            ),
          ],

          if (_btPairingActive) ...[
            const SizedBox(height: 16),
            if (_bleConnected)
              Container(
                width: 400,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.bluetooth_connected, size: 32, color: Colors.green),
                    const SizedBox(height: 12),
                    Text(l10n.bleAlreadyConnected,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                    const SizedBox(height: 8),
                    Text(l10n.bleAlreadyConnectedHint,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
                  ],
                ),
              )
            else
              Container(
                width: 400,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.bluetooth_searching, size: 32, color: Colors.blueAccent),
                    const SizedBox(height: 12),
                    Text(l10n.pairingActive,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(l10n.pairingActiveHint,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
                  ],
                ),
              ),
            if (_blePinCode != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.4)),
                ),
                child: Text(_blePinCode!,
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8,
                      fontFamily: 'monospace',
                    )),
              ),
              const SizedBox(height: 8),
              Text(l10n.blePinHint,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _stopBluetoothPairing,
              icon: const Icon(Icons.check),
              label: Text(l10n.pairingDone),
            ),
          ],
        ],
      );
  }

  Future<void> _startBluetoothPairing() async {
    try {
      await _sshService.redisLpush('scooter:state', 'unlock');
      debugPrint('UI: scooter unlocked for BT pairing');
      setState(() {
        _btPairingActive = true;
        _blePinCode = null;
      });
      _startBlePinPolling();
    } catch (e) {
      debugPrint('UI: failed to unlock scooter: $e');
      _setStatus('Failed to unlock scooter: $e');
    }
  }

  void _startBlePinPolling() {
    _blePinPollTimer?.cancel();
    _blePinPollTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) {
        _blePinPollTimer?.cancel();
        return;
      }
      try {
        final connected = await _sshService.redisHget('ble', 'connected');
        final isConnected = connected == 'true';
        if (isConnected != _bleConnected) {
          setState(() => _bleConnected = isConnected);
        }

        final pin = await _sshService.redisHget('ble', 'pin-code');
        if (pin != null && pin.isNotEmpty) {
          if (_blePinCode != pin) {
            setState(() => _blePinCode = pin);
          }
        } else if (_blePinCode != null) {
          // PIN cleared: pairing completed for this device
          setState(() => _blePinCode = null);
        }
      } catch (_) {}
    });
  }

  Future<void> _stopBluetoothPairing() async {
    _blePinPollTimer?.cancel();
    _blePinPollTimer = null;
    try {
      await _sshService.redisLpush('scooter:state', 'lock');
      debugPrint('UI: scooter locked after BT pairing');
    } catch (e) {
      debugPrint('UI: failed to lock scooter: $e');
    }
    setState(() {
      _btPairingActive = false;
      _blePinCode = null;
      _bleConnected = false;
    });
    await _bluetoothComplete(skipped: false);
  }

  /// Skip handler for the Bluetooth step. Stops any active pairing first.
  Future<void> _skipBluetoothPairing() async {
    if (_btPairingActive) {
      _blePinPollTimer?.cancel();
      _blePinPollTimer = null;
      try {
        await _sshService.redisLpush('scooter:state', 'lock');
      } catch (_) {}
      setState(() {
        _btPairingActive = false;
        _blePinCode = null;
        _bleConnected = false;
      });
    }
    await _bluetoothComplete(skipped: true);
  }

  /// Bluetooth step finished (done or skipped). Inside the Stage-1
  /// dashboardPrep screen this records the result and advances the interactive
  /// sub-step to keycard enrollment, persisting the resume checkpoint on a real
  /// pairing. As the standalone phase it just advances to keycardSetup.
  Future<void> _bluetoothComplete({required bool skipped}) async {
    if (_currentPhase == InstallerPhase.dashboardPrep) {
      setState(() {
        if (skipped) {
          _btSkipped = true;
        } else {
          _btDone = true;
        }
        _dashboardPrepStep = _DashboardPrepStep.keycard;
      });
      if (!skipped) {
        try {
          await _sshService.writeInstallState(_baseInstallState(InstallPhase.btPaired));
        } catch (e) {
          debugPrint('UI: failed to write install state (bt-paired), non-fatal: $e');
        }
      }
      // Spin up the keycard sub-step the same way the standalone phase does.
      await _onEnterKeycardSetup();
      return;
    }
    _setPhase(InstallerPhase.keycardSetup);
  }

  // Killed on entry to keycardSetup so that any auto-startup master-learning
  // mode in keycard-service is disengaged before the user can tap a card.
  // Without this, a stray tap on the reader during the install would be
  // learned as the master keycard and wipe the authorized list.
  Future<void> _onEnterKeycardSetup() async {
    setState(() {
      _keycardLearning = false;
      _keycardStage = _KeycardStage.loading;
      _keycardServiceCanMaster = null;
      _keycardMasterCount = 0;
      _keycardAuthorizedCount = 0;
      _keycardSessionTapCount = 0;
      _keycardToastMessage = null;
    });
    if (!_canDriveKeycard) {
      // No SSH and no dry-run — render an empty cards stage so the Skip
      // button still works; the actual commands will no-op.
      if (mounted) setState(() => _keycardStage = _KeycardStage.cards);
      return;
    }

    if (_isDryRun) {
      debugPrint('UI: [DRY RUN] would send set-master:NONE');
      // Pretend the new service is present so the master flow is testable.
      setState(() {
        _keycardServiceCanMaster = true;
        _keycardStage = _KeycardStage.cards;
      });
      return;
    }

    // Re-apply always-on USB gadget policy: the MDB has been re-flashed since
    // we first set it, so the freshly-installed image is back to the default.
    // We restore it to auto on finish. Best-effort: missing on older images.
    try {
      await _sshService.runCommand('lsc set scooter.usb0-policy always-on');
      debugPrint('UI: scooter.usb0-policy=always-on (keycardSetup)');
    } catch (e) {
      debugPrint('UI: failed to set scooter.usb0-policy=always-on at keycardSetup (ok): $e');
    }

    // Same hazards on the freshly-installed image: keycard learning can sit
    // here for a while, and the parked-but-locked scooter is fair game for
    // both the auto-standby timer and the alarm. Cleared at finish.
    await _disableInstallerHazards(label: 'keycardSetup');

    // Stop our manual green LED blinker before keycard-service starts; both
    // drive the LP5562 via i2c and would otherwise race.
    await _stopBootLedBlink();

    // Bring librescoot-keycard back up. We stopped it post-flash to prevent
    // accidental master teach-in during the install; this is the first phase
    // that actually needs it.
    //
    // By the time the user reaches this phase, the laptop has been
    // reconnected to the MDB — which only happens after onboot.sh has run
    // to completion and unmasked the unit. So is-enabled should never be
    // "masked" here. If it is, an upstream path skipped its unmask: log
    // loudly so we can fix the offending path, then unmask here as a
    // recovery so this install can still finish.
    String enabledState = 'unknown';
    try {
      enabledState = (await _sshService.runCommand(
        'systemctl is-enabled librescoot-keycard 2>&1',
      )).trim();
    } catch (_) {}
    if (enabledState == 'masked') {
      debugPrint(
        'UI: librescoot-keycard is still masked at keycardSetup entry — '
        'an upstream unmask was skipped; recovering',
      );
      try {
        await _sshService.runCommand('systemctl unmask librescoot-keycard');
      } catch (e) {
        debugPrint('UI: unmask of librescoot-keycard failed: $e');
      }
    }

    try {
      await _sshService.runCommand('systemctl start librescoot-keycard 2>/dev/null; true');
      debugPrint('UI: started librescoot-keycard for keycard setup phase');
    } catch (e) {
      debugPrint('UI: failed to start librescoot-keycard: $e');
    }

    // Wait up to ~3s for the unit to actually be active. If it isn't, log
    // loudly so the (otherwise silent) downstream "capability probe timed
    // out" / "no taps register" failure is at least diagnosable.
    String activeState = 'unknown';
    for (var i = 0; i < 10; i++) {
      await Future.delayed(const Duration(milliseconds: 300));
      try {
        activeState = (await _sshService.runCommand(
          'systemctl is-active librescoot-keycard 2>&1',
        )).trim();
      } catch (_) {}
      if (activeState == 'active') break;
    }
    if (activeState != 'active') {
      debugPrint('UI: librescoot-keycard not active after start (state=$activeState)');
    }

    // Subscribe to keycard:events early so we don't miss any tap during the
    // capability probe or initial state read. Both the regular learn flow
    // (card-learned, card-duplicate) and the master teach-in flow emit on
    // this channel; legacy services don't publish here, which is harmless.
    try {
      await _keycardSubscribeEvents();
    } catch (e) {
      debugPrint('UI: failed to subscribe to keycard events: $e');
    }

    // Disengage boot-time auto-master-learning before any tap can land.
    try {
      await _sshService.redisLpush('scooter:keycard', 'set-master:NONE');
      debugPrint('UI: keycardSetup entered, master mode disengaged');
    } catch (e) {
      debugPrint('UI: failed to disengage master-learning on entry: $e');
    }

    final canMaster = await _keycardDetectCapability();
    await _keycardRefreshCounts();
    if (!mounted) return;

    setState(() {
      _keycardServiceCanMaster = canMaster;
      if (canMaster &&
          (_keycardMasterCount > 0 || _keycardAuthorizedCount > 0)) {
        _keycardStage = _KeycardStage.alreadyConfigured;
      } else {
        _keycardStage = _KeycardStage.cards;
      }
    });
  }

  bool get _canDriveKeycard => _sshService.isConnected || _isDryRun;

  /// Probe the keycard-service for new-command support by sending
  /// `learn:master:stop` and inspecting `keycard.command-result`. The new
  /// service answers either `ok` (was in master teach-in) or
  /// `error:not in master teach-in`; the old service answers
  /// `error:unknown command`. We snapshot command-result before the probe so
  /// we can wait for it to actually change, instead of racing against an old
  /// stale value.
  Future<bool> _keycardDetectCapability() async {
    try {
      final before = await _sshService.redisHget('keycard', 'command-result');
      await _sshService.redisLpush('scooter:keycard', 'learn:master:stop');
      // ~3 s budget at 150 ms intervals. The keycard-service typically writes
      // command-result well under 500 ms on the local USB-network link.
      for (var i = 0; i < 20; i++) {
        await Future.delayed(const Duration(milliseconds: 150));
        final result = await _sshService.redisHget('keycard', 'command-result');
        if (result == null || result == before) continue;
        final lower = result.toLowerCase();
        if (lower.startsWith('error:unknown')) {
          debugPrint('UI: keycard capability probe -> legacy ($result)');
          return false;
        }
        debugPrint('UI: keycard capability probe -> new ($result)');
        return true;
      }
      debugPrint('UI: keycard capability probe timed out, assuming legacy');
    } catch (e) {
      debugPrint('UI: keycard capability probe failed: $e');
    }
    return false;
  }

  Future<void> _keycardRefreshCounts() async {
    if (_isDryRun) return;
    try {
      final m = await _sshService.redisHget('system', 'keycard-master-count');
      final a = await _sshService.redisHget('system', 'keycard-authorized-count');
      if (!mounted) return;
      setState(() {
        _keycardMasterCount = int.tryParse(m ?? '') ?? 0;
        _keycardAuthorizedCount = int.tryParse(a ?? '') ?? 0;
      });
    } catch (e) {
      debugPrint('UI: failed to read keycard counts: $e');
    }
  }

  void _keycardShowToast(String message, Color color, {int ms = 3000}) {
    _keycardToastTimer?.cancel();
    setState(() {
      _keycardToastMessage = message;
      _keycardToastColor = color;
    });
    _keycardToastTimer = Timer(Duration(milliseconds: ms), () {
      if (!mounted) return;
      setState(() => _keycardToastMessage = null);
    });
  }

  Future<void> _keycardTearDown() async {
    _keycardToastTimer?.cancel();
    _keycardToastTimer = null;
    final stop = _keycardEventsStop;
    _keycardEventsStop = null;
    if (stop != null) {
      try {
        await stop();
      } catch (_) {}
    }
    await _keycardEventsSub?.cancel();
    _keycardEventsSub = null;
  }

  Future<void> _startKeycardLearning() async {
    if (_isDryRun) {
      // Carry the previous session's count forward so "Add more" simulates
      // the additive semantics of the real service.
      _keycardAuthorizedCountBefore = _keycardAuthorizedCount;
    } else {
      try {
        final raw = await _sshService.redisHget('system', 'keycard-authorized-count');
        _keycardAuthorizedCountBefore = int.tryParse(raw ?? '') ?? 0;
      } catch (e) {
        debugPrint('UI: failed to read authorized count before learn: $e');
        _keycardAuthorizedCountBefore = 0;
      }
      try {
        await _sshService.redisLpush('scooter:keycard', 'learn:start');
      } catch (e) {
        debugPrint('UI: failed to start keycard learning: $e');
        if (mounted) {
          _setStatus(AppLocalizations.of(context)!.keycardStartLearningFailed(e.toString()));
        }
        return;
      }
    }
    debugPrint('UI: keycard learning started');
    // Live tap progress is driven by card-learned events on keycard:events
    // (subscribed at keycardSetup entry). The count hash on `system` is only
    // updated after learn:stop fsyncs, so polling it during the session is
    // pointless — the events are the source of truth.
    setState(() {
      _keycardLearning = true;
      _keycardSessionTapCount = 0;
      _keycardAuthorizedCount = _keycardAuthorizedCountBefore;
    });
  }

  Future<void> _stopKeycardLearning({bool advance = true}) async {
    int sessionDelta = _keycardSessionTapCount;
    if (_isDryRun && sessionDelta == 0) sessionDelta = 1;
    if (!_isDryRun) {
      try {
        await _sshService.redisLpush('scooter:keycard', 'learn:stop');
      } catch (e) {
        debugPrint('UI: failed to stop keycard learning: $e');
      }
      // Wait for the count hash to settle to the value events already told
      // us about. fsync after learn:stop can take 2+ seconds on a freshly
      // flashed eMMC, so poll for up to ~5 s. Trust the event-derived count
      // if the hash never catches up — we've seen each tap directly.
      final expected = _keycardAuthorizedCountBefore + sessionDelta;
      int polled = _keycardAuthorizedCountBefore;
      for (var i = 0; i < 25; i++) {
        try {
          final raw = await _sshService.redisHget('system', 'keycard-authorized-count');
          polled = int.tryParse(raw ?? '') ?? polled;
        } catch (_) {}
        if (polled >= expected) break;
        await Future.delayed(const Duration(milliseconds: 200));
      }
      if (polled != expected) {
        debugPrint('UI: count after learn:stop ($polled) != expected ($expected); '
            'trusting events (sessionDelta=$sessionDelta)');
      }
      _keycardAuthorizedCount =
          polled >= _keycardAuthorizedCountBefore ? polled : expected;
    }
    final registered = sessionDelta > 0;
    debugPrint('UI: keycard learning stopped (registered=$registered, sessionDelta=$sessionDelta)');
    if (!mounted) return;
    setState(() {
      _keycardLearning = false;
      _keycardSessionTapCount = sessionDelta;
      if (advance) {
        _keycardStage = registered
            ? _KeycardStage.cardsReview
            : _KeycardStage.cards;
      }
    });
  }

  void _keycardSimulateCardTap() {
    if (!_isDryRun || !_keycardLearning) return;
    setState(() {
      _keycardSessionTapCount += 1;
      _keycardAuthorizedCount += 1;
    });
  }

  Future<void> _keycardStartMasterStage() async {
    setState(() {
      _keycardStage = _KeycardStage.master;
      _keycardToastMessage = null;
    });
    if (!_isDryRun) {
      try {
        await _keycardSubscribeEvents();
      } catch (e) {
        debugPrint('UI: failed to subscribe to keycard events: $e');
      }
      try {
        await _sshService.redisLpush('scooter:keycard', 'learn:master:start');
      } catch (e) {
        debugPrint('UI: failed to start master teach-in: $e');
      }
    }
  }

  Future<void> _keycardSubscribeEvents() async {
    if (_keycardEventsStop != null) return;
    final sub = await _sshService.subscribeRedisChannel('keycard:events');
    _keycardEventsStop = sub.stop;
    _keycardEventsSub = sub.events.listen(
      _handleKeycardEvent,
      onError: (Object e) => debugPrint('UI: keycard event stream error: $e'),
      onDone: () => debugPrint('UI: keycard event stream closed'),
    );
  }

  void _handleKeycardEvent(String payload) {
    debugPrint('UI: keycard event: $payload');
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    if (payload.startsWith('card-learned:')) {
      // Per-tap event during regular learn mode. The count hash isn't
      // updated until learn:stop fsyncs, so events are the only live signal.
      if (_keycardLearning) {
        setState(() {
          _keycardSessionTapCount += 1;
          _keycardAuthorizedCount += 1;
        });
      }
    } else if (payload.startsWith('card-duplicate:')) {
      if (_keycardLearning) {
        _keycardShowToast(l10n.keycardCardDuplicateToast, Colors.orangeAccent);
      }
    } else if (payload.startsWith('master-learned:')) {
      _keycardShowToast(l10n.keycardMasterStageLearnedToast, Colors.green);
      _keycardRefreshCounts();
      // Auto-advance: master successfully registered.
      Timer(const Duration(milliseconds: 1200), () async {
        if (!mounted) return;
        await _keycardTearDown();
        if (!mounted) return;
        await _keycardComplete(skipped: false);
      });
    } else if (payload.startsWith('rejected:already-authorized:')) {
      _keycardShowToast(l10n.keycardMasterStageRejectedToast, Colors.redAccent);
    } else if (payload.startsWith('error:save-failed:')) {
      _keycardShowToast(l10n.keycardMasterStageSaveFailedToast, Colors.redAccent);
    } else if (payload == 'reset') {
      // Service told everyone state was wiped; refresh counts.
      _keycardRefreshCounts();
    }
  }

  Future<void> _keycardSimulateMasterEvent(String payload) async {
    if (!_isDryRun) return;
    if (payload.startsWith('master-learned:')) {
      setState(() {
        _keycardMasterCount += 1;
      });
    }
    _handleKeycardEvent(payload);
  }

  Future<void> _keycardStopMasterStage({required bool advance}) async {
    if (!_isDryRun) {
      try {
        await _sshService.redisLpush('scooter:keycard', 'learn:master:stop');
      } catch (e) {
        debugPrint('UI: failed to stop master teach-in: $e');
      }
    }
    await _keycardTearDown();
    if (!mounted) return;
    if (advance) {
      await _keycardComplete(skipped: false);
    } else {
      setState(() {
        _keycardStage = _KeycardStage.cardsReview;
      });
    }
  }

  Future<void> _keycardStartOver() async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.keycardStartOverConfirmTitle),
        content: Text(l10n.keycardStartOverConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.keycardStartOverConfirmNo),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.keycardStartOverConfirmYes),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    if (_keycardLearning) {
      // Don't bother advancing — we're going to wipe anyway.
      _keycardLearning = false;
    }
    if (!_isDryRun) {
      try {
        await _sshService.redisLpush('scooter:keycard', 'reset');
      } catch (e) {
        debugPrint('UI: failed to send reset: $e');
      }
      // Brief wait for keycard-service to flush counts.
      await Future.delayed(const Duration(milliseconds: 300));
      await _keycardRefreshCounts();
    }
    if (!mounted) return;
    setState(() {
      _keycardSessionTapCount = 0;
      if (_isDryRun) {
        _keycardMasterCount = 0;
        _keycardAuthorizedCount = 0;
      }
      _keycardStage = _KeycardStage.cards;
    });
  }

  Future<void> _skipKeycardSetupEntirely() async {
    if (_keycardLearning && _canDriveKeycard) {
      await _stopKeycardLearning(advance: false);
    }
    await _keycardTearDown();
    await _keycardComplete(skipped: true);
  }

  /// Keycard step finished (done or skipped). Inside the Stage-1 dashboardPrep
  /// screen this records the result and stays on the screen so the "Begin
  /// flashing DBC" button can unlock; on a real enrollment it persists the
  /// resume checkpoint. As the standalone phase it advances to finish.
  Future<void> _keycardComplete({required bool skipped}) async {
    if (_currentPhase == InstallerPhase.dashboardPrep) {
      setState(() {
        if (skipped) {
          _keycardSkipped = true;
        } else {
          _keycardDone = true;
        }
      });
      if (!skipped) {
        try {
          await _sshService
              .writeInstallState(_baseInstallState(InstallPhase.keycardEnrolled));
        } catch (e) {
          debugPrint('UI: failed to write install state (keycard-enrolled), non-fatal: $e');
        }
      }
      return;
    }
    if (mounted) _setPhase(InstallerPhase.finish);
  }

  Widget _buildKeycardSetup(AppLocalizations l10n) {
    return Center(child: _keycardSetupContent(l10n));
  }

  /// Inner content of the keycard enrollment step, without the outer page
  /// scaffold. Reused both as the standalone phase and as the second
  /// interactive sub-step of the Stage-1 dashboardPrep screen.
  Widget _keycardSetupContent(AppLocalizations l10n) {
    return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.nfc, size: 48, color: kAccent),
            const SizedBox(height: 16),
            Text(_keycardStageHeading(l10n),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            switch (_keycardStage) {
              _KeycardStage.loading => const Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              _KeycardStage.alreadyConfigured =>
                _buildKeycardAlreadyConfigured(l10n),
              _KeycardStage.cards => _buildKeycardCardsStage(l10n),
              _KeycardStage.cardsReview => _buildKeycardCardsReview(l10n),
              _KeycardStage.master => _buildKeycardMasterStage(l10n),
              _KeycardStage.done => const Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
            },
          ],
        ),
      );
  }

  String _keycardStageHeading(AppLocalizations l10n) {
    switch (_keycardStage) {
      case _KeycardStage.alreadyConfigured:
        return l10n.keycardEntryAlreadyConfiguredHeading;
      case _KeycardStage.master:
        return l10n.keycardMasterStageHeading;
      default:
        return l10n.keycardLearningHeading;
    }
  }

  Widget _buildKeycardAlreadyConfigured(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.keycardEntryAlreadyConfiguredBody(
              _keycardMasterCount, _keycardAuthorizedCount),
          style: TextStyle(fontSize: 13, color: Colors.grey.shade300),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () => _keycardComplete(skipped: false),
          icon: const Icon(Icons.arrow_forward),
          label: Text(l10n.keycardEntryContinueButton),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _keycardStartOver,
          icon: const Icon(Icons.refresh, size: 18),
          label: Text(l10n.keycardStartOverButton),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _skipKeycardSetupEntirely,
          child: Text(l10n.skipKeycardSetup),
        ),
      ],
    );
  }

  Widget _buildKeycardCardsStage(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.keycardLearningBody,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade300),
        ),
        const SizedBox(height: 16),
        if (!_keycardLearning)
          Center(
            child: OutlinedButton.icon(
              onPressed: _canDriveKeycard ? _startKeycardLearning : null,
              icon: const Icon(Icons.nfc, size: 18),
              label: Text(l10n.keycardStartLearning),
            ),
          )
        else ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kAccent.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                const Icon(Icons.contactless, size: 28, color: kAccent),
                const SizedBox(height: 8),
                Text(l10n.keycardLearningActive,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: kAccent)),
                const SizedBox(height: 4),
                Text(l10n.keycardLearningActiveHint,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                const SizedBox(height: 8),
                Text(l10n.keycardLearningTapped(_keycardSessionTapCount),
                    style: TextStyle(
                      fontSize: 13,
                      color: _keycardSessionTapCount > 0
                          ? Colors.green
                          : Colors.grey.shade400,
                      fontWeight: _keycardSessionTapCount > 0
                          ? FontWeight.bold
                          : FontWeight.normal,
                    )),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: FilledButton.icon(
              onPressed: () => _stopKeycardLearning(),
              icon: const Icon(Icons.check, size: 18),
              label: Text(l10n.keycardStopLearning),
            ),
          ),
          if (_isDryRun) ...[
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: _keycardSimulateCardTap,
                icon: const Icon(Icons.touch_app, size: 16),
                label: Text(l10n.keycardSimulateTapButton),
              ),
            ),
          ],
        ],
        if (!_keycardLearning && (_keycardServiceCanMaster ?? false)) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _keycardStartOver,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(l10n.keycardStartOverButton),
          ),
        ],
        if (!_keycardLearning) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: _skipKeycardSetupEntirely,
            child: Text(l10n.skipKeycardSetup),
          ),
        ],
      ],
    );
  }

  Widget _buildKeycardCardsReview(AppLocalizations l10n) {
    final canMaster = _keycardServiceCanMaster ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(l10n.keycardLearnedAck(_keycardSessionTapCount),
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade200)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => _keycardComplete(skipped: false),
          icon: const Icon(Icons.arrow_forward),
          label: Text(l10n.keycardCardsStageContinueButton),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _canDriveKeycard ? _startKeycardLearning : null,
          icon: const Icon(Icons.nfc, size: 18),
          label: Text(l10n.keycardAddMore),
        ),
        if (canMaster && _keycardAuthorizedCount > 0) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _keycardStartMasterStage,
            icon: const Icon(Icons.shield_outlined, size: 18),
            label: Text(l10n.keycardCardsStageAddMasterButton),
          ),
        ],
        if (canMaster) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _keycardStartOver,
            icon: const Icon(Icons.refresh, size: 16),
            label: Text(l10n.keycardStartOverButton),
          ),
        ],
      ],
    );
  }

  Widget _buildKeycardMasterStage(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.redAccent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.6), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.redAccent, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(l10n.keycardMasterStageWarningHeading,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        )),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(l10n.keycardMasterStageWarningBody,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade200)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: kAccent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kAccent.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              const Icon(Icons.contactless, size: 28, color: kAccent),
              const SizedBox(height: 8),
              Text(l10n.keycardMasterStageHint,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: kAccent)),
            ],
          ),
        ),
        if (_keycardToastMessage != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _keycardToastColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _keycardToastColor.withValues(alpha: 0.4)),
            ),
            child: Text(_keycardToastMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: _keycardToastColor,
                  fontWeight: FontWeight.w600,
                )),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => _keycardStopMasterStage(advance: true),
          icon: const Icon(Icons.skip_next),
          label: Text(l10n.keycardMasterStageSkipButton),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _keycardStartOver,
          icon: const Icon(Icons.refresh, size: 18),
          label: Text(l10n.keycardStartOverButton),
        ),
        if (_isDryRun) ...[
          const SizedBox(height: 16),
          Text('[DRY RUN]',
              style: TextStyle(
                  fontSize: 11, color: Colors.grey.shade500)),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: () =>
                _keycardSimulateMasterEvent('master-learned:DEADBEEF'),
            icon: const Icon(Icons.touch_app, size: 16),
            label: Text(l10n.keycardSimulateMasterTapButton),
          ),
          TextButton.icon(
            onPressed: () => _keycardSimulateMasterEvent(
                'rejected:already-authorized:CAFEBABE'),
            icon: const Icon(Icons.block, size: 16),
            label: Text(l10n.keycardSimulateRejectedTapButton),
          ),
        ],
      ],
    );
  }

  Widget _buildFinish(AppLocalizations l10n) {
    if (_awaitingFinishReboot) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.restart_alt, size: 56, color: kAccent),
              const SizedBox(height: 20),
              Text(
                l10n.finishRebootingTitle,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.finishRebootingBody,
                style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      );
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.celebration, size: 64, color: kAccent),
            const SizedBox(height: 16),
            Text(l10n.welcomeToLibrescoot,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: kAccent)),
            const SizedBox(height: 24),
            Text(l10n.finalSteps, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            InstructionStep(
              number: 1,
              title: l10n.disconnectUsbFromLaptopFinal,
              description: l10n.disconnectUsbFromLaptopFinalDesc,
            ),
            InstructionStep(
              number: 2,
              title: l10n.reconnectDbcUsbCable,
              description: l10n.reconnectDbcUsbCableDesc,
            ),
            InstructionStep(
              number: 3,
              title: l10n.closeSeatboxAndFootwell,
              description: l10n.closeSeatboxAndFootwellDesc,
            ),
            InstructionStep(
              number: 4,
              title: l10n.unlockScooter,
              description: l10n.unlockScooterDesc,
            ),
            const SizedBox(height: 24),
            _buildGettingStarted(l10n),
            const SizedBox(height: 24),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.keepCachedDownloads),
              subtitle: Text(l10n.mbOnDisk(_totalCacheSizeMb()),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              value: _keepCache,
              onChanged: (v) => setState(() => _keepCache = v ?? false),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                if (!_keepCache) {
                  await _offerCleanup();
                }
                if (mounted) exit(0);
              },
              icon: const Icon(Icons.check_circle),
              label: Text(l10n.finished),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGettingStarted(AppLocalizations l10n) {
    final isGerman = Localizations.localeOf(context).languageCode == 'de';
    final handbookUrl = isGerman
        ? 'https://librescoot.org/handbook/'
        : 'https://librescoot.org/en/handbook/';
    const websiteUrl = 'https://librescoot.org/';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: kAccent.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(8),
        color: kAccent.withValues(alpha: 0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline, size: 20, color: kAccent),
              const SizedBox(width: 8),
              Text(l10n.gettingStartedTitle,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kAccent)),
            ],
          ),
          const SizedBox(height: 16),
          _buildTip(Icons.menu_open, l10n.gettingStartedOpenMenuTitle, l10n.gettingStartedOpenMenuDesc),
          _buildTip(Icons.swipe_vertical, l10n.gettingStartedDriveMenuTitle, l10n.gettingStartedDriveMenuDesc),
          _buildTip(Icons.system_update_alt, l10n.gettingStartedUpdateModeTitle, l10n.gettingStartedUpdateModeDesc),
          _buildTip(Icons.navigation_outlined, l10n.gettingStartedNavigationTitle, l10n.gettingStartedNavigationDesc),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(l10n.gettingStartedFooter,
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
              _buildLinkButton(Icons.open_in_new, l10n.gettingStartedLinkWebsite, websiteUrl),
              _buildLinkButton(Icons.menu_book_outlined, l10n.gettingStartedLinkHandbook, handbookUrl),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTip(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: kAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Text(description, style: TextStyle(color: Colors.grey.shade400, fontSize: 13, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkButton(IconData icon, String label, String url) {
    return TextButton.icon(
      onPressed: () => _openExternalUrl(url),
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: kAccent,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(url)),
      );
    }
  }

  String _totalCacheSizeMb() {
    final total = _downloadState.items.fold<int>(0, (sum, i) => sum + i.expectedSize);
    return (total / 1024 / 1024).toStringAsFixed(0);
  }

  Future<void> _cleanupMdb() async {
    if (!_sshService.isConnected) return;
    try {
      // /data/installer/ holds everything this installer stages. The
      // legacy rm -f list below covers leftovers from installers that
      // wrote directly to /data/ — harmless once those versions are gone,
      // but cheap to keep for now so upgraders don't accumulate orphans.
      await _sshService.runCommand(
        'rm -rf /data/installer; '
        'rm -f /data/librescoot-unu-*.sdimg.gz /data/librescoot-unu-*.sdimg.bmap '
        '/data/tiles_*.mbtiles /data/valhalla_tiles_*.tar '
        '/data/trampoline.sh /data/trampoline.log /data/trampoline-status '
        '/data/trampoline-stdout.log /data/trampoline-journal.log '
        '/data/stop-error-signals.sh /data/librescoot-flasher '
        '/data/onboot.sh.bak '
        '/data/test-trampoline-*.sh /data/test-step*.log; '
        'rm -rf /data/fwtools',
      );
      debugPrint('Cleanup: removed installer staging from MDB');
    } catch (e) {
      debugPrint('Cleanup: MDB cleanup failed: $e');
    }
  }

  Future<void> _offerCleanup() async {
    final l10n = AppLocalizations.of(context)!;
    final freed = await _downloadService.deleteCache(_downloadState.items);
    if (mounted) {
      _setStatus(l10n.deletedCache((freed / 1024 / 1024).toStringAsFixed(0)));
    }
  }
}

class _ManualPasswordDialog extends StatefulWidget {
  final String? version;
  final int previousAttempts;
  final int maxAttempts;

  const _ManualPasswordDialog({
    required this.version,
    required this.previousAttempts,
    required this.maxAttempts,
  });

  @override
  State<_ManualPasswordDialog> createState() => _ManualPasswordDialogState();
}

class _ManualPasswordDialogState extends State<_ManualPasswordDialog> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text;
    if (value.isEmpty) return;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final remaining = widget.maxAttempts - widget.previousAttempts;
    final String description;
    if (widget.previousAttempts > 0) {
      description = l10n.manualPasswordPromptRetry(remaining);
    } else if (widget.version != null) {
      description = l10n.manualPasswordPromptVersion(widget.version!);
    } else {
      description = l10n.manualPasswordPrompt;
    }

    return AlertDialog(
      title: Text(l10n.manualPasswordTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(description),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            focusNode: _focus,
            obscureText: true,
            autofocus: true,
            decoration: InputDecoration(
              labelText: l10n.manualPasswordFieldLabel,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(l10n.cancelButton),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(l10n.manualPasswordSubmit),
        ),
      ],
    );
  }
}

enum _KeycardStage {
  loading,
  alreadyConfigured,
  cards,
  cardsReview,
  master,
  done,
}

/// Interactive sub-step shown inside the Stage-1 dashboardPrep screen. The
/// background DBC upload progresses independently of this; this only tracks
/// which foreground task (BT pairing, then keycard enrollment) is visible.
enum _DashboardPrepStep { bluetooth, keycard }
