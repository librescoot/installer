import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

import '../main.dart'
    show
        appendLog,
        appendLogRaw,
        installerLog,
        launchArgs,
        showElevationRequiredDialog;
import '../l10n/app_localizations.dart';
import '../models/board_state.dart';
import '../models/download_state.dart';
import '../models/dashboard_messages.dart';
import '../models/install_plan.dart';
import '../models/keycard_master.dart';
import '../l10n/phase_l10n.dart';
import '../models/finish_handover.dart';
import '../models/installer_phase.dart';
import '../models/keycard_capability.dart';
import '../models/phase_attempt.dart';
import '../models/resume_state.dart';
import '../models/wait_plan.dart';
import '../models/mdb_boot_action.dart';
import '../models/region.dart';
import '../models/scooter_health.dart';
import '../models/substep.dart';
import '../models/trampoline_status.dart';
import '../services/artifact_service.dart';
import '../services/critical_operation_coordinator.dart';
import '../services/data_partition_service.dart';
import '../services/finalize_script.dart';
import '../services/install_phase_scripts.dart';
import '../services/serial_polling_loop.dart';
import '../services/services.dart';
import '../services/window_close_coordinator.dart';
import '../widgets/artifact_progress_panel.dart';
import '../widgets/health_check_panel.dart';
import '../widgets/brake_gesture.dart';
import '../widgets/install_plan_panel.dart';
import '../widgets/instruction_step.dart';
import '../widgets/phase_layout.dart';
import '../widgets/notice_card.dart';
import '../widgets/driver_blocked_panel.dart';
import '../widgets/phase_sidebar.dart';
import '../widgets/substep_list.dart';
import '../widgets/wait_overlay.dart';
import '../widgets/action_overlay.dart';
import '../widgets/wait_scaffold.dart';
import '../theme.dart';

class InstallerScreen extends StatefulWidget {
  const InstallerScreen({super.key});

  @override
  State<InstallerScreen> createState() => _InstallerScreenState();
}

class _InstallerScreenState extends State<InstallerScreen> with WindowListener {
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
  /// EHOSTUNREACH on macOS after the route retries, meaning the link is up
  /// (the board answers pings) but the app is not allowed to reach it.
  bool _mdbConnectNoRoute = false;
  Timer? _noRouteRetry;

  /// The last screen that had content, kept so a wait can dim it instead of
  /// replacing it with an empty frame. It is the built widget, not a rebuild:
  /// the phase builders start work as a side effect, and none of that may run
  /// again just because something is waiting in front of it.
  Widget? _frozenBackdrop;

  /// The steps of the wait currently running, and where it has got to.
  List<WaitStep> _waitSteps = const [];
  int _waitStep = 0;
  DateTime? _waitStartedAt;
  DateTime? _waitStepStartedAt;
  final List<String> _waitLog = [];

  /// Which physical-prep step is open. Three photo pairs at once made that
  /// screen nearly two windows tall; one at a time is what someone with a
  /// screwdriver in hand is actually working on.
  bool _healthCheckStarted = false;
  final PhaseAttempt _mdbToUmsAttempt = PhaseAttempt();
  bool _mdbFlashStarted = false;

  /// Set when the flash stopped for a reason retrying on its own cannot clear
  /// (failed safety check, no device path, retries exhausted). It keeps the
  /// build from auto-starting the flash again and shows the manual controls.
  bool _mdbFlashBlocked = false;
  final PhaseAttempt _mdbBootAttempt = PhaseAttempt();
  final PhaseAttempt _reconnectAttempt = PhaseAttempt();
  bool _dbcPrepStarted = false;
  bool _dbcUploadReady = false; // upload done, waiting for "Begin flashing DBC"

  /// Set when the CBB phase is left. The poll below sits in a wait loop for up
  /// to three minutes, and the widget it belongs to is never unmounted, so
  /// without this it keeps writing status over whatever screen replaced it and
  /// applies its verdict long after the user has moved on.
  bool _cbbPollAbandoned = false;

  /// True while the laptop-to-MDB dashboard upload runs ahead of its own
  /// phase. It stands in for [_isProcessing] there, which other phases read to
  /// decide whether to start their own work.
  bool _dbcStageInFlight = false;

  /// The transfer running behind another phase's steps, and how far it is.
  /// Kept apart from [_statusMessage] so the phase's own status is not
  /// overwritten by work the user is not waiting on yet.
  String? _bgTaskLabel;
  double? _bgTaskProgress;
  bool _reconnectStarted = false;
  final bool _showElevatedHandoff = false;
  bool _dbcFlashSimulateError = false;

  /// Set when the user opens the manual power-cut section rather than using
  /// the brake gesture. The installer cannot tell the two restarts apart from
  /// the outside (both look like the USB gadget going away), so this is the
  /// only signal for whether anything was actually unplugged, and therefore
  /// whether the later screens should ask for it back.
  bool _manualPowerCut = false;

  /// True once the main pack is confirmed off, which is the precondition for
  /// telling anyone to plug the CBB back in.
  bool _mainPackOffForCbb = false;

  /// The MDB artifact upload and mender run, tracked while they happen behind
  /// the pairing and keycard screens. The gate at mdbArtifact waits on these
  /// rather than starting the work itself.
  bool _mdbStageStarted = false;
  bool _mdbStageDone = false;
  double _mdbStageProgress = 0;
  String? _mdbStageError;

  /// True while the nRF52 is restarting its radio after the no-whitelisting
  /// advertising command, i.e. while a pairing attempt would fail.
  bool _btAdvertisingSettling = false;

  /// True once a trampoline was started that carries the finish with it.
  /// The laptop must then not redo the settings restore, the cleanup or the
  /// reboot: on the happy path it is not even connected, and after a
  /// reconnect the device has already done all three.
  bool _deviceFinishArmed = false;

  final String _installRunId = createInstallRunId();
  Future<void> _installStateWriteQueue = Future.value();
  int _installStateSequence = 0;
  DeviceInfo? _mdbInfo;

  /// What the user chose on the install-plan screen. Null until the health
  /// check has probed both boards; every route into the flash phases sets it
  /// first, except the shortcut that finds the MDB already in mass storage.
  /// What the last on-device finish recorded, when there was one. Read at
  /// connect so a run nobody watched can still say what it did.
  String? _previousRunRecord;

  /// The record's `finished` and `mdb` lines, when both are present. Null when
  /// there is no record or it predates those fields.
  ({String when, String version})? get _previousRun {
    final raw = _previousRunRecord;
    if (raw == null) return null;
    String? field(String key) {
      for (final line in raw.split('\n')) {
        final t = line.trim();
        if (t.startsWith('$key: ')) {
          final v = t.substring(key.length + 2).trim();
          return v.isEmpty ? null : v;
        }
      }
      return null;
    }

    final when = field('finished');
    final version = field('mdb');
    if (when == null || version == null) return null;
    return (when: when, version: version);
  }

  InstallPlan? _plan;
  BoardState _mdbState = const BoardState(
    board: Board.mdb,
    isLibrescoot: false,
    provenance: StateProvenance.unknown,
  );
  BoardState _dbcState = const BoardState(
    board: Board.dbc,
    isLibrescoot: false,
    provenance: StateProvenance.unknown,
  );

  /// True between a stage-0 write and the artifact's reboot. Without it the
  /// no-redis check in _autoConnectMdb would read the bootstrap image we just
  /// wrote on purpose as a broken install and send the user back to flashing.
  bool _expectMinimalMdb = false;

  /// mender's stderr from a failed artifact install, null while it is going
  /// well. Drives the retry / fall-back controls on the artifact screen.
  String? _artifactError;
  bool _artifactStarted = false;
  String? _radioGagaBackupPath;
  bool _flashConfirmed = false;
  final Map<String, int> _retryCounts = {};
  bool _btPairingActive = false;
  String? _blePinCode;
  bool _bleConnected = false;

  /// Rising edges on the link seen since the pairing window opened.
  ///
  /// The radio holds one central at a time, and every advertising restart in
  /// the firmware is guarded on there being no connection, so a device already
  /// on the link prevents the next one from pairing. Presence alone therefore
  /// says nothing: a bonded phone reconnects by itself. An edge after the
  /// window opened is the closest the vehicle gets to reporting a pairing.
  int _blePairedCount = 0;
  String? _bleMac;
  final SerialPollingLoop _blePinPolling = SerialPollingLoop();

  /// Re-arms the open pairing window. The nRF advertises in bounded cycles and
  /// puts the whitelist back when one ends, so a single command gives the user
  /// less than a minute: long enough to miss while they are still hunting
  /// through their phone's Bluetooth settings, and it fails silently when they
  /// do. Re-sending well inside the cycle keeps the window open for as long as
  /// the panel is.
  final SerialPollingLoop _bleAdvRearming = SerialPollingLoop();
  final ScrollController _phaseScrollController = ScrollController();
  bool _keycardLearning = false;
  bool _keycardMasterLearning = false;
  String? _keycardMasterStartError;
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
  /// Null until the counts have been read. A zero meant both "none
  /// registered" and "not asked yet", and the screen showed the second as the
  /// first while it was still looking.
  int? _keycardMasterCount;
  int? _keycardAuthorizedCount;
  Future<void> Function()? _keycardEventsStop;
  StreamSubscription<String>? _keycardEventsSub;
  String? _keycardToastMessage;
  Color _keycardToastColor = Colors.green;
  Timer? _keycardToastTimer;
  String?
  _awaitingUnlockState; // null when not awaiting; current vehicle state otherwise
  String?
  _resumePreviousError; // first error line from a leftover trampoline-status, if any
  String? _resumeCleanupError;
  String? _resumeStage; // stage the previous run reached, from the run state
  String? _resumeActor; // who wrote that state last: installer or trampoline
  String _resumeLogTail = ''; // last lines of the previous run's own log
  bool _resumeStillRunning = false; // the board is mid-run, leave it alone
  // MDB answered SSH but has no Librescoot stack -> recover by re-flashing.
  // Stock boards also lack it and are healthy, so the routing reads
  // _mdbLacksLibrescootStack and only the rendering reads this.
  bool _mdbStackMissing = false;
  ServiceStack? _mdbStack;

  /// No Librescoot units under any name: stock and minimal both. Every
  /// redis-backed step here is written against Librescoot's schema, so both
  /// route around them.
  bool get _mdbLacksLibrescootStack =>
      _mdbStackMissing || _mdbStack == ServiceStack.stock;
  Completer<bool>? _unlockCompleter;
  bool _keepCache = false;
  late final CriticalOperationCoordinator _criticalOperations;
  bool get _isCriticalOperation => _criticalOperations.isCritical;
  bool _windowClosing = false;
  bool _awaitingFinishHandover = false;
  Process? _caffeinateProcess; // macOS sleep prevention
  int _caffeinateGeneration = 0;
  final WindowCloseCoordinator _windowCloseCoordinator =
      WindowCloseCoordinator();

  StreamSubscription<UsbDevice?>? _deviceSub;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _criticalOperations = CriticalOperationCoordinator(
      onChanged: _criticalOperationChanged,
    );
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
    final entered = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _ManualPasswordDialog(
        version: version,
        previousAttempts: previousAttempts,
        maxAttempts: SshService.maxManualPasswordAttempts,
      ),
    );
    if (entered == _ManualPasswordDialog.unknown) {
      // Not knowing it is the common case and it has an answer, so the run
      // ends on where to find one rather than on a failed connection.
      if (mounted) setState(() => _rootPasswordUnknown = true);
      return null;
    }
    return entered;
  }

  /// The user said they do not know the root password, so the connect screen
  /// explains where to get it instead of reporting a login failure.
  bool _rootPasswordUnknown = false;

  /// Set when the RNDIS driver could not be put on the device, because
  /// something else on the machine holds it or because Windows wants a
  /// restart to finish. Carries the diagnosis so the screen can name what
  /// took the port instead of showing a connection error.
  DriverInstallResult? _driverBlocked;

  /// The laptop owed the finish and could not reach the board. On a run with
  /// no trampoline that means the install never happened, so the screen says
  /// so instead of congratulating the owner.
  bool _finishBlocked = false;

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
        _downloadState.selectedRegion = regions
            .where((r) => r.slug == selected.slug)
            .firstOrNull;
      }
    });
  }

  static const _regionHeaderPrefix = '__country__';

  /// Build dropdown items grouped by country: a disabled bold header per
  /// country, followed by its (indented) regions. Relies on [_availableRegions]
  /// already being ordered so each country's regions are contiguous.
  /// Countries as disabled headers, their regions indented under them. The
  /// grouping is the only thing that says there is more here than one
  /// country's worth of states.
  List<DropdownMenuEntry<Region>> _regionMenuEntries(List<Region> regions) {
    final entries = <DropdownMenuEntry<Region>>[];
    String? currentCountry;
    for (final region in regions) {
      if (region.country != currentCountry) {
        currentCountry = region.country;
        entries.add(
          DropdownMenuEntry<Region>(
            value: Region(
              name: region.country,
              slug: '$_regionHeaderPrefix${region.country}',
            ),
            label: region.country.toUpperCase(),
            enabled: false,
            style: MenuItemButton.styleFrom(
              foregroundColor: kAccent.withValues(alpha: 0.75),
              textStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                height: 2.0,
              ),
            ),
          ),
        );
      }
      entries.add(
        DropdownMenuEntry<Region>(
          value: region,
          label: region.name,
          style: MenuItemButton.styleFrom(
            padding: const EdgeInsets.only(left: 28, right: 16),
          ),
        ),
      );
    }
    return entries;
  }

  Future<void> _detectRegionFromIp() async {
    if (_downloadState.selectedRegion != null) {
      return; // already set (e.g. from launch args)
    }
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
      final ch = DownloadChannel.values
          .where((c) => c.name == args.channel)
          .firstOrNull;
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
    windowManager.removeListener(this);
    _downloadCancellationToken?.cancel();
    _deviceSub?.cancel();
    _usbDetector.stopMonitoring();
    unawaited(_blePinPolling.stop());
    unawaited(_bleAdvRearming.stop());
    _keycardToastTimer?.cancel();
    _noRouteRetry?.cancel();
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

  @override
  void onWindowClose() {
    unawaited(_handleWindowClose());
  }

  Future<void> _handleWindowClose() async {
    final isCritical = _isCriticalOperation;
    if (!isCritical) _windowClosing = true;
    final closed = await _windowCloseCoordinator.requestClose(
      isCritical: isCritical,
      cleanup: _cleanupBeforeClose,
      closeWindow: windowManager.destroy,
    );
    if (!closed && mounted) {
      _windowClosing = false;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.cannotQuitWhileFlashing),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _cleanupBeforeClose() async {
    await runBoundedCleanupActions([
      DriverService.restoreAutoPlay,
      DiskArbitrationService.disarmWatch,
      if (_btPairingActive ||
          _bleWhitelistDisabled ||
          _pairingVehicleStateChanged)
        () => _stopBluetoothPairing(advance: false),
      if (_keycardLearning || _keycardMasterLearning) _stopActiveKeycardModes,
    ]);
    await _keycardTearDown().timeout(
      const Duration(seconds: 2),
      onTimeout: () {},
    );
    _allowSleep();
  }

  /// Returns true if the operation should be retried, false if max retries exceeded.
  /// Handles backoff delay and retry counting.
  Future<bool> _shouldRetry(
    String key, {
    int maxRetries = 5,
    int delaySecs = 5,
  }) async {
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
      if (phase == InstallerPhase.mdbToUms && leaving != phase) {
        _mdbToUmsAttempt.reset();
      }
      if (phase == InstallerPhase.mdbBoot && leaving != phase) {
        _mdbBootAttempt.reset();
      }
      _completedPhases.add(_currentPhase);
      _currentPhase = phase;
      _statusMessage = '';
      _progress = 0.0;
      _isProcessing = false;
    });
    _queueInstallPhaseRecord(phase);
    if (leaving == InstallerPhase.keycardSetup &&
        phase != InstallerPhase.keycardSetup) {
      unawaited(_cleanupKeycardPhase());
    }
    if (leaving == InstallerPhase.bluetoothPairing &&
        phase != InstallerPhase.bluetoothPairing &&
        (_blePinPolling.isRunning ||
            _bleAdvRearming.isRunning ||
            _btPairingActive ||
            _bleWhitelistDisabled ||
            _pairingVehicleStateChanged)) {
      unawaited(_stopBluetoothPairing(advance: false));
    }
    if (phase == InstallerPhase.cbbReconnect) {
      _cbbPollAbandoned = false;
    } else if (leaving == InstallerPhase.cbbReconnect) {
      _cbbPollAbandoned = true;
    }
    if (phase == InstallerPhase.keycardSetup) {
      _onEnterKeycardSetup();
    }
    if (phase == InstallerPhase.finish) {
      _onEnterFinish();
    }
    if (phase == InstallerPhase.dbcFlash) {
      _dbcFlashWatchStarted = false;
      _dbcUsbDisconnected = false;
    }
    if (phase == InstallerPhase.bluetoothPairing) {
      _fetchBleMac();
    }
    if (phase == InstallerPhase.mdbToUms && leaving != phase) {
      Future.microtask(_startMdbToUms);
    }
    if (phase == InstallerPhase.mdbBoot && leaving != phase) {
      Future.microtask(_startMdbBoot);
    }
  }

  void _queueInstallPhaseRecord(InstallerPhase phase) {
    if (_isDryRun || _deviceFinishArmed || !_sshService.isConnected) return;
    final sequence = ++_installStateSequence;
    final content = serializeInstallRunState(
      runId: _installRunId,
      actor: 'installer',
      stage: phase.name,
      sequence: sequence,
    );
    _installStateWriteQueue = _installStateWriteQueue
        .then((_) async {
          if (_deviceFinishArmed || !_sshService.isConnected) return;
          await _sshService.writeInstallRunState(
            runId: _installRunId,
            content: content,
          );
        })
        .catchError((Object error) {
          debugPrint(
            'UI: could not record installer phase ${phase.name}: $error',
          );
        });
  }

  /// Read the scooter's BLE MAC from the MDB so the user can match it against
  /// the device they're pairing to. Best-effort; leaves _bleMac null on error.
  Future<void> _fetchBleMac() async {
    if (_isDryRun || !_sshService.isConnected) return;
    try {
      final out =
          (await _sshService
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
  /// settings-service, so [_onEnterFinish] undoes them before we reapply the
  /// user's actual choices: see [_resetPersistedSettings], which restores the
  /// copy [_backupPersistedSettings] took on the routes that keep /data.
  /// Best-effort: older images may not know these keys.
  Future<void> _disableInstallerHazards({required String label}) async {
    if (_isDryRun || !_sshService.isConnected) return;
    try {
      await _sshService.runCommand('lsc set scooter.auto-standby-seconds 0');
      debugPrint('UI: scooter.auto-standby-seconds=0 ($label)');
    } catch (e) {
      debugPrint(
        'UI: failed to set scooter.auto-standby-seconds=0 at $label (ok): $e',
      );
    }
    try {
      await _sshService.runCommand('lsc set alarm.enabled false');
      debugPrint('UI: alarm.enabled=false ($label)');
    } catch (e) {
      debugPrint('UI: failed to set alarm.enabled=false at $label (ok): $e');
    }
    await _disarmAlarm(label: label);
  }

  /// The runtime half of disabling the alarm, which is the half that works on
  /// a board with no settings-service.
  ///
  /// `alarm.enabled` propagates via a publish, and if alarm-service is
  /// mid-restart, was already armed when the flag was set, or the publish gets
  /// dropped, the FSM can stay in an armed state. Pushing a disarm onto the
  /// command queue drops it to Disarmed regardless of how the setting
  /// propagated. The stage-0 image ships valkey, so this lands there too.
  Future<void> _disarmAlarm({required String label}) async {
    if (_isDryRun || !_sshService.isConnected) return;
    try {
      await _sshService.redisLpush('scooter:alarm', 'disarm');
      debugPrint('UI: scooter:alarm disarm ($label)');
    } catch (e) {
      debugPrint('UI: failed to push scooter:alarm disarm at $label (ok): $e');
    }
  }

  /// Where the pre-install copy of the persisted settings lives. Top level
  /// of /data rather than /data/installer so it does not depend on that
  /// directory surviving the run. Only the restore removes it: generic
  /// cleanup used to, and a run that died between the park and the restore
  /// then left the parked values looking like the user's own settings for
  /// the next run to back up and faithfully put back.
  static const _settingsBackupPath = '/data/settings.toml.preinstall';

  /// Write-once snapshot of the settings as the first installer run ever
  /// found them. Never overwritten, never deleted. It is the fallback when
  /// an upgrade reaches the restore with no [_settingsBackupPath] to put
  /// back: the user's settings from their last install beat the shipped
  /// defaults as a guess, and both beat leaving ours in place.
  static const _settingsDefaultPath = '/data/settings.toml.default';

  /// Copy the persisted settings aside before the installer parks any of
  /// them. Runs at connect time, before the first `lsc set`, so the copy is
  /// the user's own state rather than ours. Idempotent: a second connect in
  /// the same session must not overwrite the first copy with one that
  /// already has our overrides baked in.
  ///
  /// A clean install reformats /data and takes this with it, which is
  /// correct: there is nothing to restore on a board that was erased.
  Future<void> _backupPersistedSettings() async {
    if (_isDryRun || !_sshService.isConnected) return;
    try {
      await _sshService.runCommand(
        'if [ -f /data/settings.toml ]; then '
        'if [ ! -f $_settingsBackupPath ]; then '
        'cp /data/settings.toml $_settingsBackupPath; fi; '
        'if [ ! -f $_settingsDefaultPath ]; then '
        'cp /data/settings.toml $_settingsDefaultPath; fi; '
        'fi',
      );
      debugPrint('UI: settings backed up to $_settingsBackupPath');
    } catch (e) {
      debugPrint('UI: failed to back up persisted settings (ok): $e');
    }
  }


  /// Persist the user's installer choices on the MDB: dashboard language
  /// (so the UI matches what they used here) and OTA channel (so future
  /// updates pull from the same track they just installed). Both are
  /// best-effort — failure is harmless, the user can fix from the dashboard.
  Future<void> _onEnterFinish() async {
    // Read before the first await: reaching for the context after one is how
    // a disposed widget turns a best-effort settings write into a crash.
    final lang = Localizations.localeOf(context).languageCode;
    final handoverL10n = AppLocalizations.of(context)!;

    if (_isDryRun) {
      if (mounted) setState(() => _awaitingFinishHandover = false);
      return;
    }
    // A dropped link used to return here too, which is right only when a
    // trampoline is carrying the finish. Without one the laptop owes the whole
    // install, so finishHandover decides rather than this.


    // Connected, but the device may have closed the install out itself while
    // we were unplugged, in which case redoing any of it is wrong: the
    // settings backup is already consumed, so a second restore would put
    // back the first-install snapshot, and a second handover is pure delay.
    // The completion record is the device's own proof, not our assumption —
    // an armed trampoline that failed never writes one, and that run does
    // still need the laptop-side finish.
    //
    // No answer at all is the third case, and the ordinary one once the
    // trampoline is running: by then the cable is on the dashboard, so the
    // session this would run over is gone even though the client still thinks
    // it is up. Everything below needs that link, so there is nothing to do
    // but show the finish screen and let the device close itself out, which
    // is what it was armed to do.
    var reported = await _deviceReportedFinished();
    var todo = finishHandover(
      dryRun: _isDryRun,
      linkUp: _sshService.isConnected,
      deviceArmed: _deviceFinishArmed,
      deviceReported: reported,
    );

    // Owed but unreachable. The link is the only way to hand it over and a
    // dropped session is usually momentary, so ask once more before treating
    // it as lost.
    if (todo == FinishHandover.blocked) {
      try {
        await _sshService.ensureConnected('finish');
        reported = await _deviceReportedFinished();
        todo = finishHandover(
          dryRun: _isDryRun,
          linkUp: _sshService.isConnected,
          deviceArmed: _deviceFinishArmed,
          deviceReported: reported,
        );
      } catch (e) {
        debugPrint('UI: could not reconnect for the finish: $e');
      }
    }

    if (todo == FinishHandover.blocked) {
      // Never the success screen. On this route the finish IS the install:
      // the artifact is staged, nothing has been queued to install it, and
      // nothing else will.
      debugPrint('UI: the finish is owed and the link is gone');
      if (mounted) {
        setState(() {
          _finishBlocked = true;
          _awaitingFinishHandover = false;
        });
      }
      return;
    }

    if (todo == FinishHandover.none) {
      debugPrint('UI: nothing for the laptop to finish (reported=$reported)');
      if (mounted) setState(() => _awaitingFinishHandover = false);
      return;
    }

    if (mounted) setState(() => _awaitingFinishHandover = true);

    // The plan goes up with the screen. Set later, the overlay spends the
    // restore showing the previous phase's steps and its clock, which is how
    // a fresh wait came to open at four minutes and "longer than usual".
    _beginWait([
      WaitStep(
          label: handoverL10n.finishHandoverRestoring,
          typical: const Duration(seconds: 25)),
      WaitStep(
          label: handoverL10n.finishHandoverTitle,
          typical: const Duration(seconds: 20)),
    ]);
    _setStatus(handoverL10n.finishHandoverRestoring);

    // Kill the green success-blink (and the amber guard) before anything
    // else. The vehicle-service restart below tears down the transient
    // systemd-run units anyway, but if it doesn't fire (or doesn't fire
    // promptly) this is what keeps the scooter from sitting in standby with the LP5562
    // blinking green until someone power-cycles it.
    await _stopBootLedBlink();

    // Everything from here is 90-finalize.sh: the settings restore, the
    // owner's choices, ending service mode, restoring usb0-policy, restarting
    // what the install stopped, the unlock and the completion record. The
    // laptop used to do all of that itself, in a different order from the
    // trampoline's copy of the same work, and the two had drifted.
    //
    // Uploaded before the cleanup below, deliberately. A queued phase makes
    // the coordinator decline to retire, so a detached run that dies takes the
    // scooter's next boot to finish rather than leaving it half handed back.
    try {
      // Before the first upload, not as part of the coordinator install that
      // follows it. uploadFile does not create directories, so without this
      // the first phase fails its chmod and the catch below swallows the rest
      // of the staging with it.
      await _sshService.runCommand('mkdir -p ${SshService.installerScriptsDir}');
      await _sshService.uploadFile(
        Uint8List.fromList(utf8.encode(FinalizeScript.render(
          template: await FinalizeScript.loadTemplate(),
          mdbAction: (_plan?.mdb.action ?? BoardAction.cleanInstall).name,
          runId: _installRunId,
          mode: (_plan?.needsMdbStage0 ?? false) ? 'flash' : 'upgrade',
          language: (lang == 'en' || lang == 'de') ? lang : '',
          channel: _downloadState.channel.name,
          // Only what this run verified. The dashboard is the trampoline's to
          // report, and a run that never handed off has nothing to say.
          dbcVersion: _deviceFinishArmed ? (_dbcState.version ?? '') : '',
          dbcAction: (_plan?.dbc.action ?? BoardAction.leave).name,
          releaseTag: _downloadState.releaseTag ?? '',
          region: _downloadState.selectedRegion?.slug ?? '',
        ))),
        FinalizeScript.remotePath,
      );
      debugPrint('UI: staged ${FinalizeScript.phaseName}');

      // A run that never handed off to the trampoline has nothing queued yet,
      // and its MDB artifact is staged but not installed. Queue the same two
      // phases the trampoline would have, so a dashboard-less plan finishes
      // the same way: install, one reboot, hand back.

      await _sshService.uploadFile(
        Uint8List.fromList(utf8.encode(MdbArtifactScript.render(
          template: await MdbArtifactScript.loadTemplate(),
          runId: _installRunId,
          artifactPath: _stagedMdbArtifactPath(),
        ))),
        MdbArtifactScript.remotePath,
      );
      await _sshService.uploadFile(
        Uint8List.fromList(utf8.encode(RebootPhaseScript.render(
          template: await RebootPhaseScript.loadTemplate(),
          runId: _installRunId,
        ))),
        RebootPhaseScript.remotePath,
      );
      debugPrint('UI: staged ${MdbArtifactScript.phaseName} and '
          '${RebootPhaseScript.phaseName}');
    } catch (e) {
      debugPrint('UI: could not stage the install phases: $e');
    }

    // Wipe installer staging from /data before we hand the vehicle back, so
    // the user doesn't carry a few hundred MB of leftover image/tile files
    // around forever. Selective now: the record and both halves' logs live in
    // there too. Skipped in non-release builds so devs can poke at the
    // trampoline state after a failed run.
    if (kReleaseMode) {
      await _cleanupMdb();
    } else {
      debugPrint('UI: skipping MDB cleanup (non-release build)');
    }

    // After the sweep, which is selective and keeps the history, but before
    // the handover, which takes the link down. The board's half of the run is
    // already in there; this is the laptop's.
    final logPath = LogService.filePath;
    if (logPath != null) {
      await _sshService.keepInstallerLog(
        runId: _installRunId,
        localPath: logPath,
      );
    }
    await _sshService.trimInstallHistory();

    // Hand the rest to the board. The coordinator installs the MDB artifact,
    // reboots once to activate it, and hands the vehicle back on the far
    // side. All three take the link down in turn, which is why it is detached
    // and why nothing below can rely on SSH surviving.
    try {
      await _armInstallPhases();
      await _sshService.startInstallPhasesDetached();
      debugPrint('UI: handed off to the coordinator');
    } catch (e) {
      debugPrint('UI: failed to start the install phases: $e');
    }

    // Nothing to watch for: the board installs, reboots to activate, and only
    // then unlocks, and the reboot takes this link with it. Polling for the
    // unlock reported success minutes before the verdict existed, and the
    // verdict can be failure. The screen already tells the owner to stay until
    // it unlocks itself, and that unlock is theirs to see.
    _setStatus(handoverL10n.finishHandoverTitle);
    // A moment for the detached coordinator to be running before the link is
    // dropped underneath it, then let go rather than waiting to be cut off.
    await Future.delayed(const Duration(seconds: 2));
    _sshService.disconnect();
    if (mounted) setState(() => _awaitingFinishHandover = false);
  }

  /// Whether the device wrote the completion record its autonomous finish
  /// ends with. Null when the question could not be put: the answer then says
  /// nothing about the install, only that there is no link to ask over, and
  /// every step of the laptop-side finish needs that same link.
  Future<bool?> _deviceReportedFinished() async {
    try {
      final out = await _sshService
          .runCommand('cat ${SshService.installerLastInstall} 2>/dev/null || '
              'cat ${SshService.legacyLastInstall} 2>/dev/null; true')
          .timeout(const Duration(seconds: 10));
      return TrampolineStatus.parseCompletionRecord(
        out,
      ).completedFor(_installRunId);
    } catch (e) {
      debugPrint('UI: could not read the completion record ($e)');
      return null;
    }
  }

  /// Progress for the transfer running beside the current phase. It gets the
  /// overlay's second line rather than the status the phase is reporting.
  void _setBackgroundStatus(String? message, {double? progress}) {
    if (!mounted) return;
    setState(() {
      _bgTaskLabel = message;
      _bgTaskProgress = progress;
    });
  }

  void _setStatus(String message, {double? progress}) {
    if (message.isNotEmpty) appendLog(message);
    // A wait's steps are its status messages, so a phase advances itself just
    // by saying what it is doing. No second set of call sites to keep in step
    // with the first.
    if (message.isNotEmpty && _waitSteps.isNotEmpty) {
      final now = DateTime.now();
      _waitLog.add('${now.hour.toString().padLeft(2, '0')}:'
          '${now.minute.toString().padLeft(2, '0')}:'
          '${now.second.toString().padLeft(2, '0')} $message');
      if (_waitLog.length > 60) _waitLog.removeAt(0);
      final at = _waitSteps.indexWhere((step) => step.matches(message));
      if (at > _waitStep) {
        _waitStep = at;
        _waitStepStartedAt = now;
        // The bar belongs to the step that reported it. Carrying it into the
        // next one shows a figure that describes work already finished. Zero
        // reads as indeterminate at every consumer.
        if (progress == null) _progress = 0.0;
      }
    }
    setState(() {
      _statusMessage = message;
      if (progress != null) _progress = progress;
    });
  }

  final _debugController = TextEditingController();

  void _showLogDialog() {
    final l10n = AppLocalizations.of(context)!;
    var debugShellOpen = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> runDebugCommand() async {
            final cmd = _debugController.text;
            if (cmd.trim().isEmpty) return;
            appendLogRaw('> $cmd');
            setDialogState(() {});
            try {
              final result = await Process.run('/bin/sh', ['-c', cmd]);
              final out = result.stdout.toString().trim();
              final err = result.stderr.toString().trim();
              if (out.isNotEmpty) appendLogRaw(out);
              if (err.isNotEmpty) appendLogRaw('stderr: $err');
              appendLogRaw('exit: ${result.exitCode}');
            } catch (e) {
              appendLogRaw('error: $e');
            }
            _debugController.clear();
            setDialogState(() {});
          }

          return AlertDialog(
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
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                  if (LogService.filePath != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SelectableText(
                        l10n.logFilePath(LogService.filePath!),
                        style: TextStyle(
                          fontSize: 11,
                          color: kTextPrimary.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  const Divider(),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () =>
                          setDialogState(() => debugShellOpen = !debugShellOpen),
                      icon: Icon(
                        debugShellOpen
                            ? Icons.expand_less
                            : Icons.expand_more,
                        size: 18,
                      ),
                      label: Text(l10n.debugShell),
                    ),
                  ),
                  if (debugShellOpen)
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _debugController,
                            autofocus: true,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                            decoration: InputDecoration(
                              hintText: l10n.debugCommandHint,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                            ),
                            onSubmitted: (_) => runDebugCommand(),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.play_arrow),
                          onPressed: runDebugCommand,
                        ),
                      ],
                    ),
                ],
              ),
            ),
            actions: [
              if (LogService.filePath != null)
                TextButton.icon(
                  onPressed: () => LogService.revealInFileManager(),
                  icon: const Icon(Icons.folder_open, size: 16),
                  label: Text(l10n.revealLogFile),
                ),
              TextButton(
                onPressed: () async {
                  final text = installerLog.join('\n');
                  if (Platform.isMacOS) {
                    final uid = (await Process.run('stat', [
                      '-f',
                      '%u',
                      '/dev/console',
                    ])).stdout.toString().trim();
                    final (exe, args, env) = LogService.pbcopyCommand(uid);
                    final proc = await Process.start(exe, args,
                        environment: env);
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
          );
        },
      ),
    );
  }

  void _criticalOperationChanged(bool critical) {
    if (!mounted) return;
    setState(() {});
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

  CriticalOperationLease _acquireCriticalOperation() =>
      _criticalOperations.acquire();

  void _preventSleep() {
    if (Platform.isMacOS) {
      final generation = ++_caffeinateGeneration;
      _caffeinateProcess?.kill();
      _caffeinateProcess = null;
      Process.start('caffeinate', ['-s'])
          .then((p) {
            if (generation != _caffeinateGeneration || !_isCriticalOperation) {
              p.kill();
              return;
            }
            _caffeinateProcess = p;
            debugPrint(
              'UI: sleep prevention started (caffeinate pid ${p.pid})',
            );
          })
          .catchError((_) {});
    }
  }

  void _allowSleep() {
    _caffeinateGeneration++;
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
                        upgradingSteps: _upgradingSteps,
                        dbcMapsOnly: _dbcMapsOnly,
                        downloadItems: _downloadState.items,
                        // The last thing the run said is not what is happening
                        // once the run is over. The finish screen is not a
                        // wait, so the footer has nothing to report; only the
                        // handover before it does.
                        statusMessage: _currentPhase == InstallerPhase.finish &&
                                !_awaitingFinishHandover
                            ? null
                            : _statusMessage,
                        isBusy: _isProcessing,
                        progress: _progress,
                        onShowLog: _showLogDialog,),
                      Expanded(
                        child: Column(
                          children: [
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  // A PhaseLayout owns its own title, scrolling
                                  // and action bar, so it needs the height
                                  // rather than a scroll view around it. Phases
                                  // not yet moved over keep the old behaviour:
                                  // one scroll for the whole screen.
                                  final content = _buildPhaseContent(l10n);
                                  if (content is PhaseLayout ||
                                      content is WaitScaffold) {
                                    return content;
                                  }
                                  return Scrollbar(
                                    controller: _phaseScrollController,
                                    thumbVisibility: true,
                                    child: SingleChildScrollView(
                                      controller: _phaseScrollController,
                                      padding: const EdgeInsets.all(32),
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(
                                          minHeight: constraints.maxHeight - 64,
                                        ),
                                        child: Center(child: content),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
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

  Widget _buildPhaseContent(AppLocalizations l10n) {
    if (_showElevatedHandoff) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.open_in_new, size: 48, color: kAccent),
            const SizedBox(height: 16),
            Text(
              l10n.installationContinuesInNewWindow,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.youCanCloseThisWindow,
              style: TextStyle(color: Colors.grey.shade400),
            ),
          ],
        ),
      );
    }
    final content = _phaseContent(l10n);
    // Waits draw over the screen the user just left, so only screens with
    // something to show get remembered.
    if (!_currentPhase.isWait) _frozenBackdrop = content;
    return content;
  }

  Widget _phaseContent(AppLocalizations l10n) {
    return switch (_currentPhase) {
      InstallerPhase.welcome => _buildWelcome(l10n),
      InstallerPhase.notices => _buildNotices(l10n),
      InstallerPhase.physicalPrep => _buildPhysicalPrep(l10n),
      InstallerPhase.mdbConnect => _buildMdbConnect(l10n),
      InstallerPhase.resumeDetected => _buildResumeDetected(l10n),
      InstallerPhase.healthCheck => _buildHealthCheck(l10n),
      InstallerPhase.installPlan => _buildInstallPlan(l10n),
      InstallerPhase.mdbToUms => _buildMdbToUms(l10n),
      InstallerPhase.mdbFlash => _buildMdbFlash(l10n),
      InstallerPhase.scooterPrep => _buildScooterPrep(l10n),
      InstallerPhase.mdbBoot => _buildMdbBoot(l10n),
      InstallerPhase.mdbArtifact => _buildMdbArtifact(l10n),
      InstallerPhase.cbbReconnect => _buildCbbReconnect(l10n),
      InstallerPhase.dbcPrep => _buildDbcPrep(l10n),
      InstallerPhase.dbcFlash => _buildDbcFlash(l10n),
      InstallerPhase.reconnect => _buildReconnect(l10n),
      InstallerPhase.bluetoothPairing => _buildBluetoothPairing(l10n),
      InstallerPhase.keycardSetup => _buildKeycardSetup(l10n),
      InstallerPhase.finish => _buildFinish(l10n),
    };
  }

  /// A wait: the previous screen, dimmed and inert, with the overlay over it.
  /// The sidebar sits outside this and stays lit, so the step list keeps
  /// running while the card explains what the board is doing.
  Widget _waitPhase({
    required String title,
    String? warning,
    double? progress,
    List<Widget> actions = const [],
  }) {
    return WaitScaffold(
      backdrop: _frozenBackdrop,
      overlay: WaitOverlay(
        title: title,
        steps: _waitSteps,
        currentStep: _waitStep,
        startedAt: _waitStartedAt ?? DateTime.now(),
        stepStartedAt: _waitStepStartedAt,
        progress: progress,
        warning: warning,
        logTail: _waitLog,
        actions: actions,
        backgroundLabel: _bgTaskLabel,
        backgroundProgress: _bgTaskProgress,
      ),
    );
  }

  /// Start a wait at its first step. Called where the work begins, not where
  /// the screen is built, so a rebuild cannot restart the clock.
  void _beginWait(List<WaitStep> steps) {
    final now = DateTime.now();
    _waitSteps = steps;
    _waitStep = 0;
    _waitStartedAt = now;
    _waitStepStartedAt = now;
    _waitLog.clear();
  }

  Widget _buildWelcome(AppLocalizations l10n) {
    final prerequisites = [
      l10n.prerequisiteScrewdriverPH2,
      l10n.prerequisiteScrewdriverFlat,
      l10n.prerequisiteUsbCable,
      l10n.prerequisiteTime,
    ];

    return PhaseLayout(
      title: l10n.welcomeHeading,
      subtitle: l10n.welcomeSubheading,
      actions: [
        PhaseAction(
          label: l10n.startInstallation,
          icon: Icons.arrow_forward,
          primary: true,
          onPressed:
              _isProcessing ||
                  _channelsLoading ||
                  (_availableChannels?.isEmpty ?? true) ||
                  (_downloadState.wantsOfflineMaps &&
                      _downloadState.selectedRegion == null)
              ? null
              : _startClickedAdvanceToNotices,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // One per line. Packed onto shared rows they read as a paragraph of
          // fragments, and the window has the height to spare now that the
          // status strip is gone.
          Text(
            l10n.whatYouNeed,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < prerequisites.length; i++)
                _prerequisite(prerequisites[i], i),
            ],
          ),
          const SizedBox(height: 24),

          // Channel selection
          Text(
            l10n.firmwareChannel,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          if (_channelsLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    l10n.loadingChannels,
                    style: TextStyle(color: Colors.grey.shade400),
                  ),
                ],
              ),
            )
          else
            _buildChannelSelector(l10n),
          // The cards look the same whether the list came from the network or
          // from the snapshot compiled into the app, so say which.
          if (_downloadService.manifestIsBundled) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.cloud_off, size: 15, color: Colors.amber.shade300),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.manifestBundledNotice,
                    style: TextStyle(
                        fontSize: 12, color: Colors.amber.shade200),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),

          // Region selection with skip checkbox inline
          Row(
            children: [
              Text(
                l10n.region,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () => _updateDownloadSelection(() {
                  _downloadState.wantsOfflineMaps =
                      !_downloadState.wantsOfflineMaps;
                }),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: !_downloadState.wantsOfflineMaps,
                        onChanged: (v) => _updateDownloadSelection(() {
                          _downloadState.wantsOfflineMaps = !(v ?? false);
                        }),
                      ),
                      Text(
                        l10n.skipOfflineMaps,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.regionHint,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 8),
          if (_downloadState.wantsOfflineMaps)
            // Answer-width, not measure-width: a one-word answer stretched
            // across 960px read as a hairline rectangle. The menu is an M3
            // one because the older dropdown paints its list on the theme's
            // canvas colour, which on this ground is the page colour: no
            // edge, no surface, nothing to say where the list ends. Its
            // surface and border come from the theme.
            Align(
              alignment: Alignment.centerLeft,
              child: DropdownMenu<Region>(
                width: 420,
                menuHeight: 400,
                initialSelection: _downloadState.selectedRegion,
                hintText: l10n.selectRegion,
                enableFilter: false,
                requestFocusOnTap: false,
                leadingIcon: Icon(Icons.place_outlined,
                    size: 20, color: Colors.grey.shade400),
                dropdownMenuEntries: _regionMenuEntries(_availableRegions),
                onSelected: (r) {
                  if (r == null || r.slug.startsWith(_regionHeaderPrefix)) {
                    return;
                  }
                  if (_downloadState.selectedRegion == r) return;
                  _updateDownloadSelection(() {
                    _downloadState.selectedRegion = r;
                  });
                },
              ),
            ),

          const SizedBox(height: 24),

          // Heads-up that clicking Start will trigger the UAC prompt.
          // Windows-only — macOS uses per-call authopen during the flash itself.
          if (!_isElevated && Platform.isWindows) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 18,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.elevationNoticeWelcome,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                  ),
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
        ],
      ),
    );
  }

  Widget _buildNotices(AppLocalizations l10n) {
    // Kick downloads off as soon as the user lands here so the sidebar
    // shows progress while they read the warnings, and the Continue
    // button can gate on _downloadState.allReady. Microtask so we don't
    // mutate state during build.
    if (!_downloadsKicked &&
        _downloadsFailed == null &&
        !launchArgs.hasLocalImages) {
      Future.microtask(_kickoffDownloads);
    }
    final missingAssets = _downloadState.missingRequiredTypes;
    final downloadsReady =
        _downloadState.allReady && _downloadState.items.isNotEmpty;
    final hasItems = _downloadState.items.isNotEmpty;
    final waitingOnDownloads =
        !downloadsReady && hasItems && missingAssets.isEmpty;
    // Nothing resolved at all. An empty queue used to read as "nothing to
    // wait for" rather than "nothing resolved", so Continue stayed enabled
    // and walked the user toward a flash with no firmware behind it. The
    // requiredTypes gate does not catch this either: it is only populated
    // after a successful resolve, so on the exception path it is empty and
    // missingAssets passes.
    final nothingResolved = !hasItems && !launchArgs.hasLocalImages;
    return PhaseLayout(
      title: l10n.noticesHeading,
      subtitle: l10n.noticesSubheading,
      onBack: _isProcessing ? null : () => _setPhase(InstallerPhase.welcome),
      backLabel: l10n.backButton,
      actions: [
        // Offered only while the queue is still running: the user says they
        // will be online later and takes the install without the files.
        if (waitingOnDownloads)
          PhaseAction(
            label: l10n.noticesContinueOfflineAnyway,
            onPressed: _isProcessing
                ? null
                : () => _setPhase(InstallerPhase.physicalPrep),
          ),
        // Custom: the label and the icon both change while downloads run, and
        // the icon becomes a spinner.
        PhaseAction.custom(
          primary: true,
          child: FilledButton.icon(
            onPressed:
                _isProcessing ||
                    waitingOnDownloads ||
                    nothingResolved ||
                    missingAssets.isNotEmpty
                ? null
                : _startDownloadsAndContinue,
            icon: waitingOnDownloads || nothingResolved
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.arrow_forward),
            label: Text(
              waitingOnDownloads || nothingResolved
                  ? l10n.noticesWaitingForDownloads
                  : l10n.noticesAcknowledgeButton,
            ),
          ),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_downloadsFailed != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.shade900.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade700),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.cloud_off, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.downloadsFailedHeading,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.downloadsFailedBody,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade300,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SelectableText(
                          _downloadsFailed!,
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: () => setState(() {
                      _downloadsFailed = null;
                      _downloadsKicked = false;
                    }),
                    icon: const Icon(Icons.refresh),
                    label: Text(l10n.downloadsRetry),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // The one that ruins a scooter, so it is the loud one. Users pull
          // power when they think something is stuck, and that is what bricks
          // a board mid-flash.
          Builder(builder: (context) {
            final (lead, dos, why) =
                NoticeCard.splitBullets(l10n.noPowerCycleWarningBody);
            return NoticeCard(
            severity: NoticeSeverity.danger,
            title: l10n.noPowerCycleWarningTitle,
            body: lead,
            bullets: dos,
            trail: why,
            footer: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _noticeLink(Icons.chat_bubble_outline,
                    l10n.openLibrescootDiscord, discordUrl,
                    Colors.red.shade200),
                _noticeLink(Icons.menu_book_outlined,
                    l10n.gettingStartedLinkHandbook, _handbookUrl,
                    Colors.red.shade200),
              ],
            ),
          );
          }),
          const SizedBox(height: 12),

          // Flash failures are dominated by USB drops and laptop sleep, so
          // this is a checklist rather than prose.
          Builder(builder: (context) {
            final (lead, bullets, _) =
                NoticeCard.splitBullets(l10n.reliabilityWarningBody);
            return NoticeCard(
              severity: NoticeSeverity.warning,
              title: l10n.reliabilityWarningTitle,
              body: lead,
              bullets: bullets,
            );
          }),
          if (missingAssets.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade400),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.report_problem,
                    color: Colors.red.shade300,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.releaseMissingAssetsTitle,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade300,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l10n.releaseMissingAssetsBody(
                            _downloadState.releaseTag ?? '',
                            missingAssets
                                .map((t) => _assetLabel(l10n, t))
                                .join(', '),
                          ),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade200,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  String _assetLabel(AppLocalizations l10n, DownloadItemType type) =>
      switch (type) {
        DownloadItemType.mdbArtifact => l10n.assetMdbArtifact,
        DownloadItemType.dbcArtifact => l10n.assetDbcArtifact,
        DownloadItemType.mdbFirmware => l10n.assetMdbImage,
        DownloadItemType.dbcFirmware => l10n.assetDbcImage,
        _ => type.name,
      };

  Widget _buildChannelSelector(AppLocalizations l10n) {
    final channelInfo = <DownloadChannel, ({String name, String desc})>{
      DownloadChannel.stable: (
        name: l10n.channelStable,
        desc: l10n.channelStableDesc,
      ),
      DownloadChannel.testing: (
        name: l10n.channelTesting,
        desc: l10n.channelTestingDesc,
      ),
      DownloadChannel.nightly: (
        name: l10n.channelNightly,
        desc: l10n.channelNightlyDesc,
      ),
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
      onTap: available
          ? () {
              if (_downloadState.channel == channel) return;
              _updateDownloadSelection(() {
                _downloadState.channel = channel;
              });
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        // A border grows inward from the box edge, so widening it on selection
        // shrinks the content box and reflows everything below the card for
        // the length of the animation. The border stays one width and the
        // selected state is carried by colour; the padding absorbs the second
        // pixel so the card's own size never changes.
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          // Same radius and same border colour as the Cards elsewhere, so a
          // card the user picks and a card that only groups things read as
          // two states of one idiom.
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? kAccent : kOutline,
          ),
          color: selected
              ? kAccent.withValues(alpha: 0.08)
              : available
              ? Colors.transparent
              : kSurfaceLow,
        ),
        child: Opacity(
          opacity: available ? 1.0 : 0.4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: selected ? kAccent : null,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
              ),
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
      onTap: () => setState(
        () => _prerequisiteChecks[index] = !_prerequisiteChecks[index],
      ),
      borderRadius: BorderRadius.circular(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _prerequisiteChecks[index]
                ? Icons.check_box
                : Icons.check_box_outline_blank,
            size: 18,
            color: _prerequisiteChecks[index] ? kAccent : Colors.grey,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: _prerequisiteChecks[index]
                  ? Colors.grey.shade200
                  : Colors.grey.shade400,
            ),
          ),
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
    if (_downloadState.wantsOfflineMaps &&
        _downloadState.selectedRegion == null &&
        !launchArgs.hasLocalImages) {
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
  int _downloadGeneration = 0;
  DownloadCancellationToken? _downloadCancellationToken;

  void _updateDownloadSelection(void Function() update) {
    setState(() {
      update();
      _downloadGeneration++;
      _downloadCancellationToken?.cancel();
      _downloadCancellationToken = null;
      _downloadsKicked = false;
      _downloadsFailed = null;
      _downloadState.releaseTag = null;
      _downloadState.requiredTypes = const {};
      _downloadState.items = [];
      _downloadState.error = null;
    });
  }

  bool _ownsDownloadGeneration(
    int generation,
    DownloadCancellationToken cancellationToken,
  ) =>
      mounted &&
      generation == _downloadGeneration &&
      identical(cancellationToken, _downloadCancellationToken) &&
      !cancellationToken.isCancelled;

  /// Why the last kick failed, or null. Holding the reason here is what stops
  /// the retry: the kick is scheduled from build(), so re-arming
  /// [_downloadsKicked] in the catch turned a failure into a loop that reran
  /// as fast as the failing request resolved. A field log caught it at ~23
  /// requests a second for 156s, which was most of the log.
  String? _downloadsFailed;

  /// Build the download queue and start downloads in the background.
  /// Called when the user enters the Notices phase so the sidebar shows
  /// progress while they read the warnings; the Continue button on
  /// Notices then waits on _downloadState.allReady (or the override).
  Future<void> _kickoffDownloads() async {
    if (_downloadsKicked) return;
    if (!mounted) return;
    _downloadsKicked = true;
    final generation = ++_downloadGeneration;
    _downloadCancellationToken?.cancel();
    final cancellationToken = DownloadCancellationToken(generation);
    _downloadCancellationToken = cancellationToken;
    final channel = _downloadState.channel;
    final region = _downloadState.selectedRegion;
    final wantsOfflineMaps = _downloadState.wantsOfflineMaps;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isProcessing = true;
      _downloadState.error = null;
    });
    try {
      if (launchArgs.hasLocalImages) {
        _setStatus(l10n.usingLocalFirmwareImages);
        final items = <DownloadItem>[];
        // Only the boards whose flag was actually passed: a queue that
        // claims the other board's image is coming is what made
        // --dbc-image alone wait for an MDB download that never starts.
        _downloadState.requiredTypes = {
          if (launchArgs.mdbImage != null) DownloadItemType.mdbFirmware,
          if (launchArgs.dbcImage != null) DownloadItemType.dbcFirmware,
        };
        if (launchArgs.mdbImage != null) {
          items.add(
            DownloadItem(
                type: DownloadItemType.mdbFirmware,
                url: '',
                filename: File(launchArgs.mdbImage!).uri.pathSegments.last,
                expectedSize: await File(launchArgs.mdbImage!).length(),
              )
              ..localPath = launchArgs.mdbImage
              ..bytesDownloaded = await File(launchArgs.mdbImage!).length(),
          );
        }
        if (launchArgs.dbcImage != null) {
          items.add(
            DownloadItem(
                type: DownloadItemType.dbcFirmware,
                url: '',
                filename: File(launchArgs.dbcImage!).uri.pathSegments.last,
                expectedSize: await File(launchArgs.dbcImage!).length(),
              )
              ..localPath = launchArgs.dbcImage
              ..bytesDownloaded = await File(launchArgs.dbcImage!).length(),
          );
        }
        if (!_ownsDownloadGeneration(generation, cancellationToken)) return;
        setState(() => _downloadState.items = items);
      } else {
        _setStatus(l10n.resolvingReleases);
        // The tag is the target version every later check compares a board
        // against, so it has to be recorded, not just used to pick assets.
        // Reads the same in-memory manifest the queue build does.
        final release = await _downloadService.resolveRelease(channel);
        if (!_ownsDownloadGeneration(generation, cancellationToken)) return;
        final items = await _downloadService.buildDownloadQueue(
          channel: channel,
          region: region,
          wantsOfflineMaps: wantsOfflineMaps,
        );
        if (!_ownsDownloadGeneration(generation, cancellationToken)) return;
        setState(() {
          _downloadState.releaseTag = release.tag;
          _downloadState.requiredTypes = DownloadState.defaultRequiredTypes;
          _downloadState.items = items;
        });
        // A release that does not ship what the install needs has to say so
        // here, on a screen with a Back button and a channel picker behind
        // it, not at the artifact install or halfway through the DBC.
        if (_downloadState.missingRequiredTypes.isNotEmpty) {
          debugPrint(
            'Downloads: release ${release.tag} is missing '
            '${_downloadState.missingRequiredTypes}',
          );
          return;
        }
        // Check the disk before starting rather than filling it and failing
        // partway through several hundred MB, which leaves the cache full of
        // half-written files and the user with no idea why.
        final cacheDir = await DownloadService.getCacheDir();
        final shortfall = await DownloadService.shortfallFor(
          _downloadState.items,
          cacheDir,
        );
        if (!_ownsDownloadGeneration(generation, cancellationToken)) return;
        if (shortfall != null) {
          final mb = (shortfall / (1024 * 1024)).ceil();
          debugPrint('Downloads: $mb MB short on ${cacheDir.path}');
          if (mounted) {
            setState(
              () => _downloadsFailed = l10n.notEnoughDiskSpace('$mb MB'),
            );
          }
          return;
        }
        _downloadInBackground(items, generation, cancellationToken);
      }
    } on DownloadCancelled {
      return;
    } catch (e) {
      // Deliberately NOT re-arming _downloadsKicked: the retry is the user's
      // to ask for, via the button this failure puts on screen.
      if (_ownsDownloadGeneration(generation, cancellationToken)) {
        setState(() => _downloadsFailed = e.toString());
      }
    } finally {
      if (_ownsDownloadGeneration(generation, cancellationToken)) {
        // Leave a failure on screen. Clearing unconditionally was why the
        // error only ever flickered: the catch set it and the finally wiped
        // it on the next frame, so the user got a strobing status line and no
        // readable reason.
        if (_downloadsFailed == null) _setStatus('');
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

  void _downloadInBackground(
    List<DownloadItem> items,
    int generation,
    DownloadCancellationToken cancellationToken,
  ) async {
    try {
      await _downloadService.downloadAll(
        items,
        cancellationToken: cancellationToken,
        onProgress: (item, bytes, total) {
          if (_ownsDownloadGeneration(generation, cancellationToken)) {
            setState(() {});
          }
        },
      );
      // The last onProgress fires before localPath is set on the final item,
      // so the UI is stuck in "almost-but-not-done" without this final rebuild.
      if (_ownsDownloadGeneration(generation, cancellationToken)) {
        setState(() {});
      }
    } on DownloadCancelled {
      return;
    } catch (e) {
      if (_ownsDownloadGeneration(generation, cancellationToken)) {
        final message = e.toString();
        setState(() {
          _downloadState.error = message;
          _downloadsFailed = message;
        });
      }
    }
  }

  void _restartFailedDownloads() {
    if (_downloadState.error == null) return;
    var cancellationToken = _downloadCancellationToken;
    if (cancellationToken == null || cancellationToken.isCancelled) {
      final generation = ++_downloadGeneration;
      cancellationToken = DownloadCancellationToken(generation);
      _downloadCancellationToken = cancellationToken;
    }
    setState(() {
      _downloadState.error = null;
      _downloadsFailed = null;
    });
    _downloadInBackground(
      _downloadState.items,
      _downloadGeneration,
      cancellationToken,
    );
  }

  Widget _buildPhysicalPrep(AppLocalizations l10n) {
    return PhaseLayout(
      title: l10n.physicalPrepHeading,
      subtitle: l10n.physicalPrepSubheading,
      onBack: () => _setPhase(InstallerPhase.notices),
      backLabel: l10n.backButton,
      actions: [
        PhaseAction(
          label: l10n.doneDetectDevice,
          icon: Icons.arrow_forward,
          primary: true,
          onPressed: () => _setPhase(InstallerPhase.mdbConnect),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, step) in <({
            String title,
            String description,
            String? before,
            String? after
          })>[
            // First, because it is a precondition for the whole run rather
            // than a step in it: a scooter left locked with no main battery
            // suspends partway through and takes the USB link with it.
            (
              title: l10n.keepScooterAwake,
              description: l10n.keepScooterAwakeDesc,
              before: null,
              after: null,
            ),
            (
              title: l10n.removeFootwellCover,
              description: l10n.removeFootwellCoverDesc,
              before: 'assets/images/lsi-unu_scooter_footwell_closed.jpg',
              after: 'assets/images/lsi-unu_scooter_footwell_open.jpg',
            ),
            (
              title: l10n.unscrewUsbCable,
              description: l10n.unscrewUsbCableDesc,
              before: 'assets/images/lsi-mdb_usb_connected.jpg',
              after: 'assets/images/lsi-mdb_usb_disconnected.jpg',
            ),
            (
              title: l10n.connectLaptopUsb,
              description: l10n.connectLaptopUsbDesc,
              before: null,
              after: null,
            ),
          ].indexed)
            InstructionStep(
              number: i + 1,
              title: step.title,
              description: step.description,
              beforeImageAsset: step.before,
              imageAsset: step.after,
              // All open. As an accordion the closed steps were grey text
              // with no affordance, so nobody read them as openable and the
              // instructions for two of the three were simply invisible. The
              // frame scrolls, which is what the accordion was buying.
              expanded: true,
            ),
        ],
      ),
    );
  }

  /// Re-check the Windows driver binding before leaning on the network again.
  ///
  /// A board that reboots or gets replugged comes back on a fresh device node
  /// and Windows ranks it from scratch, so a binding that was right at connect
  /// time is not still right afterwards. Repairs it in place where it can;
  /// the caller keeps going either way, because the waits and the diagnostic
  /// panel are a better place to stall than a half-finished reconnect.
  Future<bool> _ensureDriverBinding() async {
    if (!Platform.isWindows) return true;

    final diagnosis = await DriverService.diagnoseBinding();
    if (diagnosis.state == DriverBinding.correct ||
        diagnosis.state == DriverBinding.notPresent) {
      return true;
    }

    debugPrint('Driver: binding drifted to ${diagnosis.state.name}, '
        'reinstalling before using the network');
    final result = await DriverService.installDriver();
    if (result.success && !result.rebootRequired) return true;

    debugPrint('Driver: reinstall did not take: ${result.error}');
    if (mounted) setState(() => _driverBlocked = result);
    return false;
  }

  /// Something else on the machine holds the scooter's USB port, or Windows
  /// wants a restart before the driver it just staged goes live.
  Widget _buildDriverBlocked(AppLocalizations l10n, DriverInstallResult r) {
    final diagnosis = r.diagnosis;
    final details = diagnosis == null
        ? (r.error ?? '')
        : DriverService.describeForSupport(diagnosis);

    return DriverBlockedPanel(
      title: r.rebootRequired
          ? l10n.driverNeedsRebootHeading
          : l10n.driverClaimedHeading,
      body: r.rebootRequired
          ? l10n.driverNeedsRebootBody
          : l10n.driverClaimedBody(
              diagnosis == null
                  ? 'another driver'
                  : DriverService.describeHolder(diagnosis),
            ),
      detailsLabel: l10n.driverClaimedDetailsLabel,
      details: details,
      actions: [
        PhaseAction(
          label: l10n.driverRecheck,
          icon: Icons.refresh,
          primary: true,
          onPressed: () {
            setState(() {
              _driverBlocked = null;
              _mdbConnectStarted = true;
            });
            Future.microtask(_autoConnectMdb);
          },
        ),
        if (details.isNotEmpty)
          PhaseAction(
            label: l10n.copyToClipboard,
            icon: Icons.copy,
            onPressed: () => Clipboard.setData(ClipboardData(text: details)),
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

    // A driver we cannot displace is a dead end for this run, but one with an
    // answer, so the screen carries the answer rather than a connection error.
    if (_driverBlocked != null) {
      return _buildDriverBlocked(l10n, _driverBlocked!);
    }

    // While it is running it is a wait; a stall gets the frame back so the
    // retry has somewhere to live.
    if (_isProcessing) {
      return _waitPhase(title: l10n.connectingToMdb);
    }

    // Not knowing the password is a dead end for this run, but it is one with
    // an answer, so the screen carries the answer rather than a login failure.
    if (_rootPasswordUnknown) {
      return PhaseLayout(
        title: l10n.manualPasswordUnknownHeading,
        actions: [
          PhaseAction(
            label: l10n.retryMdbConnect,
            icon: Icons.refresh,
            primary: true,
            onPressed: () {
              setState(() {
                _rootPasswordUnknown = false;
                _mdbConnectStarted = true;
              });
              Future.microtask(_autoConnectMdb);
            },
          ),
        ],
        child: Text(
          l10n.manualPasswordUnknownBody,
          style: TextStyle(
              fontSize: 14, height: 1.5, color: Colors.grey.shade300),
        ),
      );
    }

    if (_mdbConnectNoRoute && !_isProcessing) {
      return PhaseLayout(
        title: l10n.macosNoRouteHeading,
        actions: [
          PhaseAction(
            label: l10n.showLog,
            icon: Icons.article_outlined,
            side: ActionSide.back,
            onPressed: _showLogDialog,
          ),
          PhaseAction(
            label: l10n.macosOpenLocalNetworkSettings,
            icon: Icons.settings,
            primary: true,
            onPressed: _openLocalNetworkSettings,
          ),
        ],
        child: Text(
          l10n.macosNoRouteBody,
          style: TextStyle(
              fontSize: 14, height: 1.5, color: Colors.grey.shade300),
        ),
      );
    }

    return _waitingPhase(
      title: l10n.connectingToMdb,
      status: _statusMessage.isEmpty
          ? l10n.waitingForUsbDevice
          : _statusMessage,
      actions: [
        if (!_isProcessing)
          PhaseAction(
            label: l10n.retryMdbConnect,
            icon: Icons.refresh,
            primary: true,
            onPressed: () {
              setState(() {
                _mdbConnectStarted = true;
                _mdbConnectNoRoute = false;
              });
              Future.microtask(_autoConnectMdb);
            },
          ),
      ],
    );
  }

  Future<void> _openLocalNetworkSettings() async {
    try {
      await launchUrl(Uri.parse(
        'x-apple.systempreferences:com.apple.preference.security'
        '?Privacy_LocalNetwork',
      ));
    } catch (e) {
      debugPrint('UI: could not open Local Network settings: $e');
    }
  }

  /// Local Network access takes effect live, so the install can continue the
  /// moment the user allows it without them touching anything here.
  void _scheduleNoRouteRetry() {
    _noRouteRetry?.cancel();
    _noRouteRetry = Timer(const Duration(seconds: 5), () {
      if (!mounted || _isProcessing) return;
      if (_currentPhase != InstallerPhase.mdbConnect) return;
      _mdbConnectStarted = true;
      unawaited(_autoConnectMdb());
    });
  }

  /// Waiting on the rider, not on the board.
  ///
  /// An overlay, like the waits on the machine, but its own card: steps and
  /// typical durations say nothing about something that ends when a person
  /// acts. What this one carries is the ask, the ways to do it, and the way
  /// out. The screen behind it stays visible, which is where the scooter the
  /// user has to walk over to was last described.
  Widget _buildAwaitingUnlock(AppLocalizations l10n) {
    final isRtd = _awaitingUnlockState == 'ready-to-drive';
    return WaitScaffold(
      backdrop: _frozenBackdrop,
      overlay: ActionOverlay(
        title: isRtd ? l10n.awaitingParkHeading : l10n.awaitingUnlockHeading,
        instruction: isRtd ? l10n.awaitingParkDetail : l10n.awaitingUnlockDetail,
        icon: isRtd ? Icons.local_parking : Icons.lock_open,
        hints: isRtd
            ? const []
            : [l10n.awaitingUnlockHintKeycard, l10n.awaitingUnlockHintPhone],
        watching: isRtd ? l10n.awaitingParkWatching : l10n.awaitingUnlockWatching,
        actions: [
          TextButton(
            onPressed: _userCancelUnlockWait,
            child: Text(l10n.cancelButton),
          ),
          // Only the ready-to-drive case has an override: a scooter that is
          // simply locked has nothing to go on with.
          if (isRtd)
            FilledButton.icon(
              onPressed: _userOverrideRtd,
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: Text(l10n.awaitingParkContinueAnyway),
            ),
        ],
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
        _unlockCompleter != null &&
        !_unlockCompleter!.isCompleted) {
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

  /// Connect, redoing the network setup if the host refuses to route there.
  /// The interface can be published after the configure pass already ran,
  /// which is why restarting the installer fixes it.
  Future<DeviceInfo> _connectToMdbRetryingRoute(AppLocalizations l10n) async {
    for (var attempt = 1;; attempt++) {
      try {
        return await _sshService.connectToMdb();
      } catch (e) {
        if (!NetworkService.isLinkNotReady(e) ||
            attempt >= _routeRecoveryAttempts) {
          rethrow;
        }
        debugPrint(
          'SSH: link not ready ($e), redoing network setup '
          '(attempt $attempt/$_routeRecoveryAttempts)',
        );
        _setStatus(l10n.configuringNetwork);
        await _reconfigureNetworkQuietly();
        _setStatus(l10n.connectingSsh);
      }
    }
  }

  static const int _routeRecoveryAttempts = 3;

  Future<void> _reconfigureNetworkQuietly() async {
    final networkService = NetworkService();
    try {
      final iface = await networkService.findLibrescootInterface();
      if (iface != null) await networkService.configureInterface(iface);
    } catch (e) {
      debugPrint('Network: reconfigure during route recovery failed: $e');
    }
    await Future.delayed(const Duration(seconds: 2));
  }

  Future<void> _autoConnectMdb() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isProcessing = true;
      _mdbConnectNoRoute = false;
    });

    if (_isDryRun) {
      _setStatus('[DRY RUN] Loading auth assets...');
      try {
        await _sshService.loadDeviceConfig('assets');
        _setStatus(
          '[DRY RUN] Auth loaded, simulating MDB v1.15.0 connection...',
        );
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
    // Always run installDriver() rather than gating on what is in the driver
    // store: the driver may be staged from a prior run while the device is
    // currently bound to usbser. installDriver() short-circuits internally
    // when the binding is already correct, and pnputil /add-driver is
    // idempotent.
    if (Platform.isWindows) {
      _setStatus(l10n.checkingRndisDriver);
      final driver = await DriverService.installDriver();
      if (!driver.success || driver.rebootRequired) {
        // Stop here. Carrying on reaches findLibrescootInterface(), which
        // queries Win32_NetworkAdapter and finds nothing for a device sitting
        // in class Ports, so network config is skipped without comment and
        // the run ends on a generic SSH failure with the actual cause,
        // already diagnosed, thrown away.
        debugPrint('Driver: blocked: ${driver.error ?? 'reboot required'}');
        setState(() {
          _driverBlocked = driver;
          _isProcessing = false;
        });
        return;
      }
    }

    _setStatus(l10n.configuringNetwork);
    final networkService = NetworkService();
    final iface = await networkService.findLibrescootInterface();
    if (iface != null) {
      try {
        final configured = await networkService.configureInterface(iface);
        if (!configured && !await networkService.isMdbReachable()) {
          // configureInterface returns false without throwing for two very
          // different reasons, and only one of them is about permission.
          //
          // On macOS `networksetup -setmanual` fails for lack of admin, and
          // the auth dialog is asynchronous, so auto-retrying churns the UI
          // until the user clicks Allow. Stopping is right there.
          //
          // Everywhere else it means the board did not answer in the couple
          // of seconds after the address was set, which is the ordinary state
          // of a board that is still booting. Telling a Linux user that macOS
          // wants permission is nonsense, and stopping on it strands them in
          // front of a retry button for something that fixes itself.
          if (Platform.isMacOS) {
            _setStatus(l10n.networkConfigNeedsPermission);
            setState(() => _isProcessing = false);
            return;
          }
          _setStatus(l10n.waitingForMdb);
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
      final info = await _connectToMdbRetryingRoute(l10n);
      setState(() => _mdbInfo = info);
      debugPrint(
        'SSH: firmware=${info.firmwareVersion}, serial=${info.serialNumber ?? "unknown"}',
      );

      // A scooter accidentally flashed with a minimal/bootstrap image answers
      // SSH but has no redis: the resume screen's Continue, the parked-state
      // gate, and the pre-flash lock all die with `redis-cli: not found`,
      // wedging the installer. Detect that here and route straight to the
      // health screen (which shows a recovery banner) and on to re-flashing
      // the full firmware, bypassing every redis-backed step.
      final stack = await _sshService.detectServiceStack();
      if (stack != null && stack != ServiceStack.librescoot) {
        debugPrint('SSH: MDB has no Librescoot stack (${stack.name})');
        if (!mounted) return;
        setState(() {
          _mdbStack = stack;
          _mdbStackMissing = stack == ServiceStack.none;
          _isProcessing = false;
        });
        if (_expectMinimalMdb) {
          // We put this image here a minute ago. Carry on with the plan and
          // install the artifact rather than offering to re-flash.
          _setPhase(_beginMdbInstall());
          return;
        }
        _setStatus(
          stack == ServiceStack.stock
              ? l10n.stockFirmwareStatus
              : l10n.incompleteImageStatus,
        );
        _setPhase(InstallerPhase.healthCheck);
        return;
      }

      // An install that died mid-flash leaves /data/installer behind with
      // keycard + bluetooth masked (the trampoline masks them pre-flash).
      // After a power cycle such a scooter cannot be unlocked at all: no
      // keycard reader, no BLE, so the parked-state gate below would wait
      // forever. The leftovers prove an earlier session already passed the
      // gate, so skip it and clean up the masked services / error signals
      // before redoing the install.
      //
      // Testing for the files alone is not enough, and got this wrong on real
      // hardware: a SUCCESSFUL run leaves trampoline-status behind too, so a
      // healthy scooter was announced as an interrupted install, with no error
      // to explain it, and the unlock gate was skipped on the strength of that.
      // Read the verdict. Only a run that did not reach a verdict, or reached a
      // failing one, is unfinished. A completion record is proof of the
      // opposite and is reported rather than treated as damage.
      var resumingUnfinished = false;
      var stillRunning = false;
      String? previousRun;
      try {
        final leftover = await _sshService.runCommand(
          'ls /data/installer/trampoline-status '
          '/data/installer/scripts/trampoline.sh '
          '/data/installer/trampoline.sh 2>/dev/null; true',
        );
        final leftoversPresent = leftover.trim().isNotEmpty;
        var written = TrampolineResult.unknown;
        if (leftoversPresent) {
          // The first line is the verdict; anything else is detail.
          final verdict = (await _sshService.runCommand(
            'head -n 1 /data/installer/trampoline-status 2>/dev/null; true',
          )).trim().toLowerCase();
          written = verdict == 'success'
              ? TrampolineResult.success
              : verdict.startsWith('error')
              ? TrampolineResult.error
              : TrampolineResult.running;
        }
        // Ask the board what it is doing before acting on what it wrote. A
        // run that is still going owns the masked services and the error
        // signals this screen would otherwise clear out from under it.
        final verdict = resumeVerdict(
          leftoversPresent: leftoversPresent,
          result: written,
          trampolineAlive:
              leftoversPresent && await _sshService.trampolineAlive(),
        );
        resumingUnfinished = verdict == ResumeVerdict.unfinished;
        stillRunning = verdict == ResumeVerdict.running;
        if (leftoversPresent) {
          debugPrint(
            'SSH: leftovers found, wrote "$written", '
            'verdict=${verdict.name}',
          );
        }
        // Written by a finish that ran on the device, where nobody was here to
        // read the outcome. Surfacing it is the whole point of writing it.
        final record = (await _sshService.runCommand(
          'cat ${SshService.installerLastInstall} 2>/dev/null || '
          'cat ${SshService.legacyLastInstall} 2>/dev/null; true',
        )).trim();
        if (record.isNotEmpty) {
          previousRun = record;
          debugPrint(
            'SSH: previous run completed on the device: '
            '${record.replaceAll('\n', ', ')}',
          );
        }
      } catch (e) {
        debugPrint('SSH: unfinished-install check failed (ok): $e');
      }
      if (mounted && previousRun != null) {
        setState(() => _previousRunRecord = previousRun);
      }

      if (stillRunning) {
        debugPrint('SSH: a trampoline is running, leaving the board alone');
        await _loadResumeEvidence();
        if (!mounted) return;
        setState(() {
          _resumeStillRunning = true;
          _isProcessing = false;
        });
        _setPhase(InstallerPhase.resumeDetected);
        _watchRunningTrampoline();
        return;
      }

      if (resumingUnfinished) {
        debugPrint('SSH: unfinished install detected, skipping unlock gate');
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
            'systemctl unmask librescoot-keycard '
            'librescoot-bluetooth librescoot-ums 2>/dev/null; '
            'systemctl start librescoot-bluetooth librescoot-ums 2>/dev/null; true',
          );
        } catch (e) {
          debugPrint('SSH: service unmask on resume failed (ok): $e');
        }
        // Surface what the previous run recorded, if anything, then let
        // the user acknowledge before continuing.
        String? prevError;
        try {
          final firstLine = await _sshService.runCommand(
            'head -1 /data/installer/trampoline-status 2>/dev/null; true',
          );
          final trimmed = firstLine.trim();
          if (trimmed.startsWith('error:')) {
            prevError = trimmed.substring('error:'.length).trim();
          }
        } catch (_) {}
        await _loadResumeEvidence();
        if (!mounted) return;
        setState(() {
          _resumePreviousError = prevError;
          _resumeStillRunning = false;
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
          setState(() {
            _isProcessing = false;
            _mdbConnectStarted = false;
          });
        }
        return;
      }
      debugPrint('SSH: scooter is parked (or overridden), locking...');

      await _completeConnectionSetup(l10n);
    } catch (e) {
      final noRoute = NetworkService.isNoRouteToHost(e);
      if (noRoute) {
        final iface = await NetworkService().findLibrescootInterface();
        debugPrint(await NetworkService().gatherMacOSDiagnostics(iface?.name));
      }
      _setStatus(l10n.sshConnectionFailed(e.toString()));
      // No auto-retry here: SSH failure means the previous network config
      // didn't actually deliver a reachable MDB. Repeating the same dance
      // every second flickers the UI. The retry button below explicitly
      // re-arms _mdbConnectStarted and re-invokes us.
      setState(() {
        _isProcessing = false;
        _mdbConnectNoRoute = noRoute && Platform.isMacOS;
      });
      if (_mdbConnectNoRoute) _scheduleNoRouteRetry();
    }
  }

  /// Shared tail of the connect phase: runs after the unlock gate (normal
  /// flow) or after the user confirms the resume screen. Pins the USB
  /// gadget, disables alarm/auto-standby, locks the scooter, and moves on
  /// to the health check.
  Future<void> _completeConnectionSetup(
    AppLocalizations l10n, {
    bool servicesRecovered = false,
  }) async {
    // A run that died between masking these and its own cleanup leaves them
    // masked, and the consequence is not subtle: with bluetooth-service masked
    // the main processor never reports boot to the nRF, whose watchdog then
    // power-cycles the whole scooter about every two minutes. The board comes
    // back with a new gadget MAC each time, so the host sees a fresh
    // unconfigured interface, and every symptom points at the network rather
    // than at a service that was never restarted. Clearing them costs nothing
    // when they were already fine.
    if (!servicesRecovered) {
      try {
        await _sshService.reviveInstallerServices();
        debugPrint('UI: cleared any leftover service masks');
      } catch (e) {
        debugPrint('UI: could not clear service masks (ok): $e');
      }
    }

    // Before the first `lsc set` below, so the copy is the user's own
    // settings and not ours. An upgrade puts it back at finish.
    await _backupPersistedSettings();

    // Hand the overrides to settings-service if this board has somewhere to
    // put them. What follows is then a no-op on the keys the overlay covers:
    // it forces the same values, so settings-service reads those writes as its
    // own and leaves its captured base alone.
    await _sshService.enableServiceMode();

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

    // Lock the scooter for safe flashing. Best-effort: an image without the
    // redis stack (minimal/broken) can't be locked and can't move anyway, so
    // a `redis-cli: not found` here must not abort the whole connect flow.
    _setStatus(l10n.lockingScooter);
    try {
      await _sshService.redisLpush('scooter:state', 'lock');
      final locked = await _sshService.waitForVehicleState(
        'stand-by',
        timeout: const Duration(seconds: 30),
      );
      if (!locked) {
        debugPrint('SSH: lock did not reach stand-by, continuing anyway');
      }
      debugPrint('SSH: scooter locked');
    } catch (e) {
      debugPrint('SSH: lock failed (continuing, likely incomplete image): $e');
    }

    _setStatus(l10n.connected);
    setState(() => _isProcessing = false);
    _setPhase(InstallerPhase.healthCheck);
  }

  /// Continue button on the resume screen.
  Future<void> _continueFromResume() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isProcessing = true;
      _resumeCleanupError = null;
    });
    try {
      // The screen promises the leftovers are dealt with, so deal with them:
      // an abandoned trampoline is still armed for the next MDB reboot, and
      // the services it masked are still masked.
      _setStatus(l10n.resumeClearingLeftovers);
      await _sshService.disarmTrampolineOnboot();
      await _sshService.reviveInstallerServices();
      debugPrint('UI: disarmed the previous trampoline and revived services');
    } catch (e) {
      final message = l10n.resumeCleanupFailed(e.toString());
      debugPrint('UI: could not safely clear the previous run: $e');
      _setStatus(message);
      if (mounted) {
        setState(() {
          _resumeCleanupError = e.toString();
          _isProcessing = false;
        });
      }
      return;
    }
    try {
      await _completeConnectionSetup(l10n, servicesRecovered: true);
    } catch (e) {
      _setStatus(l10n.sshConnectionFailed(e.toString()));
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  /// What the previous run got as far as, for the screen that reports it.
  /// Best-effort: a board that cannot answer still gets a usable screen.
  Future<void> _loadResumeEvidence() async {
    final state = await _sshService.readInstallRunState();
    final tail = await _sshService.readTrampolineLogTail();
    // The log goes into this session's own log file as well. That file is
    // what the user sends when they ask what went wrong, and the screen it
    // is shown on is gone by then.
    if (tail.isNotEmpty) {
      appendLogRaw('--- previous run, last lines of its log ---');
      appendLogRaw(tail);
      appendLogRaw('--- end previous run log ---');
    }
    if (!mounted) return;
    setState(() {
      _resumeStage = state?.stage;
      _resumeActor = state?.actor;
      _resumeLogTail = tail;
    });
  }

  /// Follow a run that is still going, and re-read the board once it stops
  /// rather than acting on what it said minutes ago.
  Future<void> _watchRunningTrampoline() async {
    while (mounted &&
        _resumeStillRunning &&
        _currentPhase == InstallerPhase.resumeDetected) {
      await Future.delayed(const Duration(seconds: 5));
      if (!mounted || _currentPhase != InstallerPhase.resumeDetected) return;
      if (!_sshService.isConnected) return;
      if (await _sshService.trampolineAlive()) {
        await _loadResumeEvidence();
        continue;
      }
      if (!mounted) return;
      setState(() {
        _resumeStillRunning = false;
        _mdbConnectStarted = false;
      });
      _setPhase(InstallerPhase.mdbConnect);
      return;
    }
  }

  /// The phase name the previous run wrote down, in the user's language.
  ///
  /// Both sides record the stage as the enum's own name, so the stored value
  /// is an identifier like `dbcPrep`. The sidebar already has a title for
  /// every phase; this is the same title. An unrecognised value is shown as
  /// stored rather than dropped, because a stage nobody can name is still the
  /// one fact about where the run stopped.
  String _localizedStage(String stage, AppLocalizations l10n) {
    for (final phase in InstallerPhase.values) {
      if (phase.name == stage) return phase.localizedTitle(l10n);
    }
    return stage;
  }

  Widget _buildResumeDetected(AppLocalizations l10n) {
    final running = _resumeStillRunning;
    final actor = switch (_resumeActor) {
      'trampoline' => l10n.resumeActorScooter,
      'installer' => l10n.resumeActorInstaller,
      _ => null,
    };
    return PhaseLayout(
      title: running ? l10n.resumeRunningHeading : l10n.resumeFoundHeading,
      subtitle: running ? l10n.resumeRunningBody : l10n.resumeFoundBody,
      actions: [
        // A run that is still going has nothing for the user to decide: the
        // only honest control is none, until it stops.
        if (!running)
          PhaseAction(
            label: _resumeCleanupError == null
                ? l10n.continueButton
                : l10n.retryButton,
            icon: Icons.arrow_forward,
            primary: true,
            onPressed: _isProcessing ? null : _continueFromResume,
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isProcessing && !running) ...[
            Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(l10n.resumeClearingLeftovers)),
              ],
            ),
            const SizedBox(height: 16),
          ],
          if (_resumeCleanupError != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: SelectableText(
                l10n.resumeCleanupFailed(_resumeCleanupError!),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Colors.redAccent,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (running) ...[
            Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.resumeRunningWait,
                    style: TextStyle(color: Colors.grey.shade300),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          // Without an error or a trampoline log this screen had a paragraph
          // and one line on an otherwise empty frame, while being one of the
          // more alarming ones to land on. The paragraph said what the
          // installer would do internally; this says what it means for the
          // scooter, which is what someone in this state is actually asking.
          if (!running) ...[
            Text(
              l10n.resumeWhatHappensHeading,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            for (final line in [
              l10n.resumeWhatHappensCleanup,
              l10n.resumeWhatHappensRestart,
              l10n.resumeWhatHappensKeep,
              l10n.resumeTakesAsLong,
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 16,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        line,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: Colors.grey.shade300,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
          ],
          // Which step it reached is the first thing anyone asks, and it is
          // the one fact both sides of the install write down.
          if (_resumeStage != null)
            Row(
              children: [
                Icon(
                  Icons.flag_outlined,
                  size: 18,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    l10n.resumeStageLabel(
                      _localizedStage(_resumeStage!, l10n),
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                if (actor != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    actor,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ],
            ),
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
                  Text(
                    l10n.resumeFoundLastError,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    _resumePreviousError!,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
          // The trampoline runs with nobody watching, so its log is the only
          // account of the part of the install this installer did not see.
          if (_resumeLogTail.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              l10n.resumeLogHeading,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              height: 220,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: SingleChildScrollView(
                reverse: true,
                child: SelectableText(
                  _resumeLogTail,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11.5,
                    height: 1.35,
                    color: Colors.grey.shade300,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool get _isDryRun => launchArgs.dryRun;

  Future<bool> _waitForDevice(
    DeviceMode mode, {
    Duration timeout = const Duration(seconds: 120),
  }) async {
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
  /// deadline that surfaces the reconnect diagnostic panel, and a hard one
  /// that gives up. Returns true once the device shows up, false if the user
  /// navigated away, or if [timeout] passed. Updates the [setStep] callback's
  /// detail with elapsed time so the substep row shows a live counter.
  ///
  /// The hard deadline matches the status poll running alongside it. Without
  /// one this loop ran forever, and the thing it waits for can fail
  /// permanently: a board that comes back held by another driver never
  /// reaches ethernet mode no matter how long anyone waits.
  Future<bool> _waitForRndisWithTimeout(
    AppLocalizations l10n,
    void Function(String, SubstepState, {String? detail}) setStep,
    int generation, {
    Duration timeout = const Duration(minutes: 15),
  }) async {
    if (_isDryRun) {
      await Future.delayed(const Duration(seconds: 1));
      return true;
    }
    final start = DateTime.now();
    var repairAttempted = false;
    while (_device?.mode != DeviceMode.ethernet) {
      // Covers a retry superseding this run as well as the user leaving: the
      // phase stays reconnect across a retry, so phase alone would leave the
      // older run waiting here forever.
      if (!_ownsReconnect(generation)) return false;

      final elapsed = DateTime.now().difference(start);
      if (elapsed >= timeout) {
        debugPrint('Reconnect: RNDIS never came back within '
            '${timeout.inMinutes} minutes');
        setStep(
          'rndis',
          SubstepState.failed,
          detail: l10n.elapsedSeconds(elapsed.inSeconds),
        );
        await _surfaceReconnectDiagnostics(l10n);
        return false;
      }

      setStep(
        'rndis',
        SubstepState.active,
        detail: l10n.elapsedSeconds(elapsed.inSeconds),
      );

      // The board is back but something else on the machine holds it. Waiting
      // cannot resolve that, so put our driver back once and keep watching.
      if (!repairAttempted && _device?.mode == DeviceMode.hijacked) {
        repairAttempted = true;
        debugPrint('Reconnect: device returned held by another driver');
        await _ensureDriverBinding();
      }

      if (elapsed.inSeconds >= 300 && !_reconnectShowDiagnostics) {
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
        // macOS 26 renamed SPUSBDataType to SPUSBHostDataType; the legacy
        // name still exits 0 there but reports nothing, so fall through on an
        // empty snapshot rather than showing the user a blank panel.
        snapshot = '';
        for (final dataType in const ['SPUSBHostDataType', 'SPUSBDataType']) {
          final r = await Process.run('/usr/sbin/system_profiler', [
            dataType,
          ]).timeout(const Duration(seconds: 8));
          if (r.exitCode == 0 && r.stdout.toString().trim().isNotEmpty) {
            snapshot = r.stdout.toString();
            break;
          }
        }
        // ioreg always resolves the USB->disk mapping, which system_profiler
        // no longer exposes on macOS 26. Append it so the panel stays useful
        // for diagnosing target-selection failures.
        try {
          final io = await Process.run('/usr/sbin/ioreg', [
            '-r',
            '-c',
            'IOUSBHostDevice',
            '-l',
            '-w',
            '0',
          ]).timeout(const Duration(seconds: 8));
          if (io.exitCode == 0) {
            final bsd = RegExp(
              r'"BSD Name"\s*=\s*"(disk\d+)"',
            ).allMatches(io.stdout.toString()).map((m) => m.group(1)!).toSet();
            if (bsd.isNotEmpty) {
              snapshot =
                  '$snapshot\n\nUSB block devices (ioreg): ${bsd.join(", ")}';
            }
          }
        } catch (_) {}
      } else if (Platform.isLinux) {
        final r = await Process.run(
          'lsusb',
          [],
        ).timeout(const Duration(seconds: 5));
        snapshot = r.stdout.toString();
      } else if (Platform.isWindows) {
        final r = await Process.run('powershell', [
          '-NoProfile',
          '-Command',
          "Get-PnpDevice -PresentOnly | Where-Object { \$_.InstanceId -like '*VID_0525*' -or \$_.InstanceId -like '*VID_15A2*' } | Format-List Name,Status,Class,InstanceId",
        ]).timeout(const Duration(seconds: 8));
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

  /// What is on the board, named. A bare version number does not say which
  /// distribution it belongs to, and the two use overlapping numbering.
  String _installedVersionLabel(AppLocalizations l10n) {
    final version = _mdbInfo?.firmwareVersion ?? '';
    final distro =
        _isLibrescootFirmware ? l10n.distroLibrescoot : l10n.distroStock;
    return version.isEmpty ? distro : '$distro $version';
  }

  /// What the run intends to put there, with the channel it came from, since
  /// stable and nightly of the same version are different artifacts.
  String? _targetVersionLabel(AppLocalizations l10n) {
    final tag = _downloadState.releaseTag;
    if (tag == null || tag.isEmpty) return null;
    // The channel is part of what identifies the artifact, so it stays as it
    // is written everywhere else: stable, testing, nightly. The localised
    // labels belong on the cards where the user is choosing between them.
    return '${l10n.distroLibrescoot} ${_downloadState.channel.name} $tag';
  }

  bool get _isLibrescootFirmware {
    // /etc/os-release ID= is the authoritative discriminator. Stable
    // Librescoot ships VERSION_ID=1.0.1, indistinguishable from stock by
    // version alone: the channel-tag heuristic only catches nightly /
    // testing builds. Fall back to the heuristic if osId wasn't readable.
    final id = _mdbInfo?.osId ?? '';
    if (id.startsWith('librescoot')) return true;
    final v = _mdbInfo?.firmwareVersion ?? '';
    return v.contains('librescoot') ||
        v.contains('nightly') ||
        v.contains('testing') ||
        v.contains('stable');
  }

  /// Read what the MDB is running. `mender-update show-artifact` is what
  /// separates a bootstrap image from a full one: both report the same
  /// os-release ID, but only the full image brings up a service stack, and
  /// the artifact name carries the image recipe.
  Future<BoardState> _detectMdbState() async {
    final osRelease = await _sshService.readOsRelease();
    final version = osRelease['VERSION_ID'] ?? _mdbInfo?.firmwareVersion;
    // Probe the stack instead of trusting _mdbStackMissing. After the
    // artifact's reboot that field still holds the answer the stage-0 board
    // gave before the install, which would make every clean install look as
    // if it had never left the bootstrap image.
    //
    // Before mender, not after: the probe retries for as long as a minute on
    // a board that is still starting, and the artifact name only becomes
    // current when update-service commits, which is one of the things that
    // board is still starting. Asking mender first read a name from before
    // the install on every run that got here quickly.
    final stack = await _sshService.detectServiceStack();
    final hasMender = await _sshService.hasMenderUpdate();
    final artifact = hasMender ? await _sshService.menderArtifactName() : null;
    final minimal = looksLikeBootstrapImage(
      artifactName: artifact,
      serviceStack: stack,
      runningVersion: version,
    );
    // The inputs to the verdict, in the log, next to the verdict. Without them
    // a false "still on the bootstrap image" is undiagnosable from a report.
    // Including which input was discarded: an artifact name in the log that
    // did not decide anything reads as the reason for the verdict otherwise.
    final stale = artifact != null && artifactNameIsStale(artifact, version);
    debugPrint(
      'State: mdb artifact=${artifact ?? "none"}${stale ? " (stale)" : ""} '
      'stack=${stack?.name ?? "unanswered"} '
      'version=${version ?? "unknown"} -> minimal=$minimal',
    );

    return BoardState(
      board: Board.mdb,
      isLibrescoot: _isLibrescootFirmware,
      provenance: StateProvenance.live,
      version: version,
      artifactName: artifact,
      hasMender: hasMender,
      isMinimalImage: minimal,
    );
  }

  /// The DBC cannot be reached while the laptop occupies the MDB's only OTG
  /// port, so its version is whatever the MDB last saw. Valkey on the MDB is
  /// memory-only, so an MDB that rebooted since the DBC was last powered
  /// reports nothing at all, which is indistinguishable from a stock DBC.
  /// hasMender is assumed rather than probed; the trampoline finds out for
  /// real and falls back to stage 0 on the spot.
  Future<BoardState> _detectDbcState() async {
    String? version;
    try {
      final hash = await _sshService.redisHgetall('version:dbc');
      version = hash['version_id'];
      final id = hash['id'] ?? '';
      if (version != null &&
          version.isNotEmpty &&
          id.startsWith('librescoot')) {
        return BoardState(
          board: Board.dbc,
          isLibrescoot: true,
          provenance: StateProvenance.lastSeen,
          version: version,
          hasMender: true,
        );
      }
    } catch (e) {
      debugPrint('SSH: version:dbc read failed: $e');
    }
    return const BoardState(
      board: Board.dbc,
      isLibrescoot: false,
      provenance: StateProvenance.unknown,
    );
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

    Future<void> proceed() async {
      // Two SSH round trips: without the guard a double click fires both
      // probes twice and lands on the plan screen twice.
      if (_isProcessing) return;
      // Local images leave the plan screen nothing to choose between, so
      // skip it and let _startPlan seed the full-image plan itself.
      if (launchArgs.hasLocalImages) {
        _startPlan();
        return;
      }
      setState(() => _isProcessing = true);
      final target = _downloadState.releaseTag;
      final BoardState mdb;
      final BoardState dbc;
      try {
        mdb = await _detectMdbState();
        dbc = await _detectDbcState();
      } catch (e) {
        // Both probes swallow their own SSH errors, so this is belt and
        // braces: leaving _isProcessing set would disable the only buttons
        // on this screen and strand the user here.
        if (!mounted) return;
        _setStatus(l10n.errorPrefix(e.toString()));
        setState(() => _isProcessing = false);
        return;
      }
      if (!mounted) return;
      setState(() {
        _mdbState = mdb;
        _dbcState = dbc;
        _plan = InstallPlan.defaults(
          mdb: mdb,
          dbc: dbc,
          targetVersion: target,
          installTiles: _downloadState.wantsOfflineMaps,
        );
      });
      // _setPhase clears _isProcessing.
      _setPhase(InstallerPhase.installPlan);
    }

    final health = _scooterHealth;
    Widget warning(IconData icon, Widget content) => Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.amber),
          const SizedBox(width: 12),
          Expanded(child: content),
        ],
      ),
    );

    return PhaseLayout(
      title: l10n.healthCheckHeading,
      subtitle: l10n.verifyingReadiness,
      actions: [
        if (_mdbStackMissing)
          PhaseAction(
            label: l10n.reflashToRecover,
            icon: Icons.build,
            primary: true,
            onPressed: _isProcessing ? null : () => proceed(),
          )
        else if (health != null && health.allOk)
          PhaseAction(
            label: l10n.continueButton,
            icon: Icons.arrow_forward,
            primary: true,
            onPressed: _isProcessing ? null : () => proceed(),
          )
        else if (health != null) ...[
          // Going on despite a failed check still goes forward, so it sits
          // with the primary rather than opposite it. Retrying is the one
          // worth pressing, so it gets the weight.
          PhaseAction(
            label: l10n.proceedAtOwnRisk,
            danger: true,
            onPressed: _isProcessing ? null : () => proceed(),
          ),
          PhaseAction(
            label: l10n.retryButton,
            icon: Icons.refresh,
            primary: true,
            onPressed: () {
              setState(() {
                _scooterHealth = null;
                _healthCheckStarted = false;
              });
            },
          ),
        ],
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // The current version alone does not say whether this run is an
          // upgrade, a reinstall or a downgrade, which is the question someone
          // reads this screen to answer. Both sides name their distribution,
          // since a bare version number does not say which one it belongs to.
          if (_mdbInfo != null)
            Text(
              _downloadState.releaseTag == null
                  ? l10n.firmwareVersionDisplay(_installedVersionLabel(l10n))
                  : l10n.healthVersionPlan(
                      _installedVersionLabel(l10n),
                      _targetVersionLabel(l10n) ?? _downloadState.releaseTag!,
                    ),
              style: TextStyle(color: Colors.grey.shade400),
            ),
          // A run that finished on the device had nobody watching it. This is
          // the only place its outcome reaches a human.
          if (_previousRun != null) ...[
            const SizedBox(height: 4),
            Text(
              l10n.previousRunSummary(
                _previousRun!.when,
                _previousRun!.version,
              ),
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ],
          if (_mdbLacksLibrescootStack) ...[
            const SizedBox(height: 16),
            warning(
              _mdbStackMissing ? Icons.healing : Icons.info_outline,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _mdbStackMissing
                        ? l10n.incompleteImageHeading
                        : l10n.stockFirmwareHeading,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _mdbStackMissing
                        ? l10n.incompleteImageBody
                        : l10n.stockFirmwareBody,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade300),
                  ),
                ],
              ),
            ),
          ],
          if (_isUntestedStockFirmware) ...[
            const SizedBox(height: 16),
            warning(
              Icons.warning_amber,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.untestedFirmwareHeading,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.untestedFirmwareBody(_mdbInfo?.firmwareVersion ?? ''),
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade300),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () =>
                        _openExternalUrl(discordUrl),
                    icon: const Icon(
                      Icons.chat_bubble_outline,
                      size: 16,
                      color: Colors.amber,
                    ),
                    label: Text(
                      l10n.openLibrescootDiscord,
                      style: const TextStyle(color: Colors.amber),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (health != null) ...[
            const SizedBox(height: 24),
            HealthCheckPanel(health: health),
          ],
          if (health != null && _radioGagaBackupPath != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.configBackedUp,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _runHealthCheck() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isProcessing = true);
    if (_isDryRun) {
      setState(
        () => _scooterHealth = ScooterHealth()
          ..auxCharge = 75
          ..cbbStateOfHealth = 100
          ..cbbCharge = 92
          ..batteryPresent = true,
      );
      setState(() => _isProcessing = false);
      return;
    }
    if (_mdbStackMissing) {
      // The bootstrap image has no vehicle stack, but it does run valkey and
      // bluetooth-service, and bluetooth-service is what writes aux-battery
      // and cb-battery from the nRF52. So AUX and the CBB read here; only the
      // main pack does not, since battery-service is not on this image.
      //
      // Read once rather than polling: nothing is warming up that would make a
      // second look different, and a board that answers nothing should not
      // cost the user the full battery-data wait on the way to a re-flash.
      try {
        final health = await _sshService.queryHealth();
        if (!mounted) return;
        setState(() => _scooterHealth = health);
      } catch (e) {
        debugPrint('Health: bootstrap image answered nothing: $e');
        if (!mounted) return;
        setState(() => _scooterHealth = ScooterHealth());
      }
      if (mounted) setState(() => _isProcessing = false);
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
      // A CBB that reports itself absent has nothing to wait for; its charge
      // and state-of-health never arrive.
      bool stillWaiting(ScooterHealth h) =>
          h.auxCharge == null ||
          (h.cbbPresent != false &&
              (h.cbbCharge == null || h.cbbStateOfHealth == null));
      while (stillWaiting(health) && DateTime.now().isBefore(deadline)) {
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

  Widget _buildInstallPlan(AppLocalizations l10n) {
    final blocked = _plan!.isNoOp || _plan!.dbcWorkStrandedOn(_mdbState);
    return PhaseLayout(
      title: l10n.installPlanHeading,
      subtitle: l10n.installPlanIntro(_downloadState.releaseTag ?? ''),
      onBack: () => _setPhase(InstallerPhase.healthCheck),
      backLabel: l10n.backButton,
      actions: [
        PhaseAction(
          label: l10n.continueButton,
          primary: true,
          onPressed: blocked ? null : _startPlan,
        ),
      ],
      child: InstallPlanPanel(
        plan: _plan!,
        mdbState: _mdbState,
        dbcState: _dbcState,
        targetVersion: _downloadState.releaseTag ?? '',
        tilesAvailable: _downloadState.wantsOfflineMaps,
        onChanged: (p) => setState(() => _plan = p),
      ),
    );
  }

  /// Turn the chosen plan into a route through the phases. Every branch has
  /// to leave the wizard somewhere it can continue from: a board left alone
  /// skips its phases outright, an upgrade skips only the sdimg write, and a
  /// plan that does nothing at all cannot get here (the panel disables
  /// Continue for it).
  /// Put the coordinator on the board and tell it what this plan owes it.
  ///
  /// Immediately before the phases are run, not when they are staged. A
  /// coordinator is what makes queued phases run at boot, so installing it
  /// early opens a window where an unattended MDB reboot would install the
  /// artifact, reboot and unlock a scooter whose dashboard was never touched.
  /// Queued phases with no coordinator are inert, which is the state to be in
  /// while the user is still being asked to swap the cable.
  ///
  /// Also after the bootstrap flash rather than at plan time: a clean install
  /// reformats /data, and on the stock image the write fails outright.
  ///
  /// 20-dbc.sh is the trampoline's to write and only exists when there is
  /// dashboard work. The other three are expected on every plan, including one
  /// that leaves the MDB alone, because 80-reboot.sh joins on a verdict that
  /// has to come from somewhere.
  Future<void> _armInstallPhases() async {
    try {
      await _sshService.installOnbootShim();
      await _sshService.declareExpectedPhases([
        MdbArtifactScript.phaseName,
        if (_plan?.needsHandoff ?? false) '20-dbc.sh',
        RebootPhaseScript.phaseName,
        FinalizeScript.phaseName,
      ]);
    } catch (e) {
      debugPrint('UI: could not arm the install phases: $e');
    }
  }

  /// The MDB artifact this run actually staged, or empty when it staged none.
  ///
  /// The download queue always carries one, so it cannot answer this. A
  /// dashboard-only plan handed that path would reboot a board it promised to
  /// leave alone, or stop the reboot the dashboard still needs.
  String _stagedMdbArtifactPath() {
    if (!(_plan?.needsMdbArtifact ?? false)) return '';
    final item = _downloadState.artifactFor(Board.mdb);
    if (item == null) return '';
    return artifactSeedPath(Board.mdb, item.filename);
  }

  Future<void> _startPlan() async {
    // --mdb-image / --dbc-image supply full sdimgs and no artifacts, so the
    // only thing a plan can mean there is the legacy full-image path.
    if (launchArgs.hasLocalImages) {
      // One action per flag, not both for either. Seeding fullImage for the
      // board whose image was never passed dead-ends: --mdb-image alone hit
      // the DBC asset guard, --dbc-image alone waited forever for an MDB
      // firmware download that was never queued. Tiles are off because the
      // local-image queue holds no tile items either.
      _plan = InstallPlan(
        mdb: BoardPlan(
          board: Board.mdb,
          action: launchArgs.mdbImage != null
              ? BoardAction.fullImage
              : BoardAction.leave,
        ),
        dbc: BoardPlan(
          board: Board.dbc,
          action: launchArgs.dbcImage != null
              ? BoardAction.fullImage
              : BoardAction.leave,
        ),
        installTiles: false,
      );
    }
    final plan = _plan!;
    _skippedPhases.clear();

    if (!plan.needsMdbWork) {
      _skippedPhases.addAll(MajorStep.mdbFlash.phases);
    } else if (!plan.needsMdbStage0) {
      // An upgrade skips everything the sdimg write needs: no u-boot UMS,
      // no CBB dance.
      _skippedPhases.addAll([
        InstallerPhase.mdbToUms,
        InstallerPhase.mdbFlash,
        InstallerPhase.scooterPrep,
        InstallerPhase.mdbBoot,
      ]);
    }
    if (!plan.needsHandoff) {
      _skippedPhases.addAll(MajorStep.dbcFlash.phases);
    }

    if (plan.needsMdbStage0) {
      _expectMinimalMdb = plan.mdb.action == BoardAction.cleanInstall;
      _setPhase(InstallerPhase.mdbToUms);
    } else if (plan.needsMdbWork) {
      _setPhase(_beginMdbInstall());
    } else if (plan.needsHandoff) {
      _beginBackgroundUploads();
      _setPhase(InstallerPhase.bluetoothPairing);
    } else {
      _setPhase(InstallerPhase.bluetoothPairing);
    }
  }

  /// A phase with nothing for the user to do but watch: one line of status
  /// under a spinner, and whatever they can reach for if it stalls.
  Widget _waitingPhase({
    required String title,
    String? subtitle,
    required String status,
    List<PhaseAction> actions = const [],
    List<Widget> extra = const [],
  }) {
    return PhaseLayout(
      title: title,
      subtitle: subtitle,
      actions: actions,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isProcessing)
            const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(),
            ),
          const SizedBox(height: 20),
          Text(
            status,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade400),
          ),
          ...extra,
        ],
      ),
    );
  }

  Widget _buildMdbToUms(AppLocalizations l10n) {
    final stalled = _mdbToUmsAttempt.isFailed;
    // While it is going, it is a wait: the overlay over the screen the user
    // just left. A failure gets the whole frame back, because that is where
    // the log and the retry live.
    if (!stalled) {
      return _waitPhase(
        title: l10n.configuringMdbBootloader,
        // The claim should keep the dialog away, but it can lose to a helper
        // that failed to start, and Eject there aborts the install.
        warning: Platform.isMacOS
            ? '${l10n.dbcFlashDoNotDisconnect}\n\n${l10n.macosDiskNotReadable}'
            : l10n.dbcFlashDoNotDisconnect,
      );
    }
    return _waitingPhase(
      title: l10n.configuringMdbBootloader,
      status: _statusMessage.isEmpty ? l10n.preparing : _statusMessage,
      actions: [
        if (stalled) ...[
          // Reading the log is neither going on nor going back, so it sits
          // away from the action that moves the install.
          PhaseAction(
            label: l10n.showLog,
            icon: Icons.article_outlined,
            side: ActionSide.back,
            onPressed: _showLogDialog,
          ),
          PhaseAction(
            label: l10n.retryMdbToUms,
            icon: Icons.refresh,
            primary: true,
            onPressed: _startMdbToUms,
          ),
        ],
      ],
    );
  }

  /// Best-effort: the reboot moments later deactivates the pack regardless,
  /// so a board that will not answer is not a reason to stop the install.
  Future<void> _deactivateMainBattery() async {
    if (_isDryRun) return;
    // A minimal image has no redis, so every call here fails. Catching that
    // is not enough: a failure inside executeWithReplayPolicy can invalidate
    // the connection, and the mandatory step after this one needs it.
    if (_mdbLacksLibrescootStack) {
      debugPrint('Battery: no Librescoot stack, skipping main-pack deactivation');
      return;
    }
    try {
      await _sshService.deactivateMainBattery();
      final deadline = DateTime.now().add(const Duration(seconds: 30));
      while (DateTime.now().isBefore(deadline)) {
        if (!await _sshService.isMainBatteryActive()) {
          debugPrint('Battery: main pack deactivated via seatbox-open');
          await _sshService.logScooterStats('main-battery-deactivated');
          return;
        }
        await Future.delayed(const Duration(seconds: 1));
      }
      debugPrint('Battery: still active after 30s, the UMS reboot will do it');
    } catch (e) {
      debugPrint('Battery: could not deactivate the main pack (ok): $e');
    }
  }

  void _startMdbToUms() {
    if (!mounted || _currentPhase != InstallerPhase.mdbToUms) return;
    final generation = _mdbToUmsAttempt.begin();
    if (generation == null) return;
    setState(() => _isProcessing = true);
    unawaited(_configureMdbUms(generation));
  }

  bool _ownsMdbToUmsAttempt(int generation) {
    return mounted &&
        _currentPhase == InstallerPhase.mdbToUms &&
        _mdbToUmsAttempt.isCurrent(generation);
  }

  Future<void> _configureMdbUms(int generation) async {
    final l10n = AppLocalizations.of(context)!;
    // reboot() disconnects on purpose and clears the stored credential with
    // it, so nothing can reconnect on its own. A retry therefore arrives here
    // with no session and has to rebuild one before the first SSH step.
    final resuming = !_isDryRun && !_sshService.isConnected;
    // Timings from real runs on a healthy board; the reboot is the long pole.
    _beginWait([
      if (resuming)
        WaitStep(
            label: l10n.waitingForMdb, typical: const Duration(seconds: 45)),
      WaitStep(
          label: l10n.deactivatingMainBattery,
          typical: const Duration(seconds: 15)),
      WaitStep(
          label: l10n.uploadingBootloaderTools,
          typical: const Duration(seconds: 20)),
      WaitStep(
          label: l10n.rebootingMdbUms, typical: const Duration(seconds: 60)),
      WaitStep(
          label: l10n.waitingForUmsDevice,
          typical: const Duration(seconds: 25)),
    ]);
    if (_isDryRun) {
      _setStatus('[DRY RUN] Simulating UMS mode...');
      await Future.delayed(const Duration(seconds: 1));
      if (!_ownsMdbToUmsAttempt(generation)) return;
      _mdbToUmsAttempt.complete(generation);
      _setPhase(InstallerPhase.mdbFlash);
      return;
    }
    var autoPlayHandedToFlash = false;
    String? failureStatus;
    try {
      if (resuming) {
        // The board rebooted out from under the previous attempt. Either it
        // came back in ethernet mode, or it is not coming back at all.
        _setStatus(l10n.waitingForMdb);
        if (!await _waitForDevice(
          DeviceMode.ethernet,
          timeout: const Duration(seconds: 90),
        )) {
          throw _LocalizedInstallException(l10n.umsNotDetectedTimeout);
        }
        if (!_ownsMdbToUmsAttempt(generation)) return;
        _setStatus(l10n.reconnectingSsh);
        await _sshService.connectToMdb();
      }

      // Turn the main pack off before the board goes away. The UMS reboot
      // deactivates it either way, but only by the pack noticing the MDB has
      // stopped talking and timing out, which takes as long as it takes and
      // leaves the contactors closed until it does. Saying so explicitly is
      // both faster and the same outcome the old battery-removal step bought
      // with a seatbox that cannot be closed again from software.
      _setStatus(l10n.deactivatingMainBattery);
      await _deactivateMainBattery();

      _setStatus(l10n.uploadingBootloaderTools);
      await _sshService.configureMassStorageMode();

      // Verify the bootcmd was actually set.
      // fw_setenv behaves as fw_printenv when invoked under that name.
      _setStatus(l10n.verifyingBootloaderConfig);
      try {
        await _sshService.runCommand('ln -sf /tmp/fw_setenv /tmp/fw_printenv');
        final bootcmd = await _sshService.runCommand(
          'fw_printenv bootcmd 2>/dev/null || /tmp/fw_printenv -c /tmp/fw_env.config bootcmd',
        );
        debugPrint('SSH: verified bootcmd = $bootcmd');
        if (!bootcmd.contains('ums')) {
          failureStatus =
              'fw_setenv failed: bootcmd is still: ${bootcmd.trim()}';
        }
      } catch (e) {
        debugPrint('SSH: bootcmd verification failed ($e), proceeding');
      }

      if (failureStatus == null) {
        // Suppress Windows "format this disk" popup before UMS mode
        if (_windowClosing) return;
        await DriverService.suppressAutoPlay();
        await DiskArbitrationService.armWatch();
        if (_windowClosing) return;

        _setStatus(l10n.rebootingMdbUms);
        await _sshService.reboot();
        _setStatus(l10n.waitingForUmsDevice);
        final found = await _waitForDevice(
          DeviceMode.massStorage,
          timeout: const Duration(seconds: 60),
        );
        if (found) {
          if (!_ownsMdbToUmsAttempt(generation)) return;
          autoPlayHandedToFlash = true;
          _mdbToUmsAttempt.complete(generation);
          _setPhase(InstallerPhase.mdbFlash);
          return;
        }

        failureStatus = l10n.umsNotDetectedTimeout;
      }
    } catch (e) {
      failureStatus = 'Error: $e';
    } finally {
      if (!autoPlayHandedToFlash) {
        await DriverService.restoreAutoPlay();
        await DiskArbitrationService.disarmWatch();
      }
    }
    if (!_ownsMdbToUmsAttempt(generation)) return;
    _setStatus(failureStatus);
    setState(() {
      _isProcessing = false;
      _mdbToUmsAttempt.fail(generation, failureStatus);
    });
  }

  /// One labelled fact about the write, with an optional second line for the
  /// thing worth being able to select and paste, such as the device path.
  Widget _flashFact(String label, String value,
      {String? detail, required IconData icon}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade500),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 14)),
              if (detail != null) ...[
                const SizedBox(height: 2),
                SelectableText(
                  detail,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _flashNote(IconData icon, String text, {bool danger = false}) {
    final color = danger ? Colors.orange : Colors.grey.shade400;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 13, height: 1.4, color: color),
          ),
        ),
      ],
    );
  }

  Widget _buildMdbFlash(AppLocalizations l10n) {
    if (!_flashConfirmed) {
      final target = _device;
      final image = _downloadState.itemOfType(DownloadItemType.mdbFirmware);
      // The last screen before a destructive write says what is about to be
      // written and where. The confirmation dialog shows the same facts, but
      // only when the system-disk probe came back unknown, so a healthy host
      // was told less about the target than a host whose probe failed.
      return PhaseLayout(
        title: l10n.readyToFlash,
        subtitle: l10n.readyToFlashHint,
        actions: [
          PhaseAction(
            label: l10n.beginFlashing,
            icon: Icons.flash_on,
            primary: true,
            onPressed: () {
              _resetRetries('mdbFlash');
              setState(() => _flashConfirmed = true);
            },
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _flashFact(
              l10n.readyToFlashTargetLabel,
              target == null
                  ? l10n.readyToFlashNoTarget
                  : '${target.name}  ${target.sizeFormatted}',
              detail: (target?.path.isNotEmpty ?? false) ? target!.path : null,
              icon: Icons.storage,
            ),
            if (image != null) ...[
              const SizedBox(height: 12),
              _flashFact(
                l10n.readyToFlashImageLabel,
                image.filename,
                icon: Icons.system_update_alt,
              ),
            ],
            const SizedBox(height: 16),
            _flashNote(Icons.delete_forever, l10n.readyToFlashErases,
                danger: true),
            const SizedBox(height: 8),
            _flashNote(Icons.schedule, l10n.readyToFlashDuration),
            if (Platform.isMacOS) ...[
              const SizedBox(height: 8),
              _flashNote(Icons.info_outline, l10n.macosDiskNotReadable),
            ],
          ],
        ),
      );
    }

    if (!_mdbFlashStarted && !_isProcessing && !_mdbFlashBlocked) {
      _mdbFlashStarted = true;
      Future.microtask(_flashMdb);
    }
    // The longest wait in the install, so it follows the same rule as the
    // others: the overlay while it runs, the whole frame back on a failure,
    // where the log and the retry live.
    if (!_mdbFlashBlocked) {
      // The writer asks macOS for privilege and blocks on a modal until a
      // human answers it, so before the first byte the true state is "waiting
      // for you", not "writing". Telling someone not to disconnect while
      // nothing is happening is how a stalled dialog becomes a pulled cable.
      final awaitingAuth = Platform.isMacOS && _progress <= 0;
      return _waitPhase(
        title: l10n.flashingMdb,
        warning: awaitingAuth
            ? l10n.flashAwaitingAuthorisation
            : l10n.dbcFlashDoNotDisconnect,
        progress: _progress > 0 ? _progress : null,
      );
    }
    return PhaseLayout(
      title: l10n.flashingMdb,
      subtitle: l10n.flashingMdbSubheading,
      actions: [
        if (_mdbFlashBlocked) ...[
          PhaseAction(
            label: l10n.showLog,
            icon: Icons.article_outlined,
            side: ActionSide.back,
            onPressed: _showLogDialog,
          ),
          PhaseAction(
            label: l10n.retryMdbFlash,
            icon: Icons.refresh,
            primary: true,
            onPressed: () {
              _resetRetries('mdbFlash');
              _restartFailedDownloads();
              setState(() {
                _mdbFlashBlocked = false;
                _mdbFlashStarted = true;
              });
              Future.microtask(_flashMdb);
            },
          ),
        ],
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(value: _progress, minHeight: 8),
          const SizedBox(height: 8),
          Text(
            _statusMessage,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  /// Ask the user to confirm the target before writing, for the case where
  /// Windows could not tell us whether that disk carries boot or system.
  ///
  /// Only the detected disk can be accepted. The other USB disks are shown so
  /// the user has something to compare against, and internal disks are left
  /// out entirely so nothing they could mistake for their own drive appears.
  Future<bool> _confirmFlashTarget(UsbDevice target, String devicePath) async {
    final l10n = AppLocalizations.of(context)!;
    final others = (await _usbDetector.listUsbDisks(
      detectedPath: devicePath,
    )).where((disk) => !disk.isDetectedTarget).toList();
    if (!mounted) return false;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.confirmFlashTargetTitle),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.confirmFlashTargetBody),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: kAccent),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${target.name}  ${target.sizeFormatted}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        devicePath,
                        style: TextStyle(
                          fontSize: 12,
                          color: kTextPrimary.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.confirmFlashTargetDetected,
                        style: const TextStyle(fontSize: 12, color: kAccent),
                      ),
                    ],
                  ),
                ),
                if (others.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    l10n.confirmFlashTargetOthers,
                    style: TextStyle(
                      color: kTextPrimary.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 4),
                  for (final disk in others)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${disk.model}  ${disk.sizeFormatted}  ${disk.path}',
                        style: TextStyle(
                          fontSize: 12,
                          color: kTextPrimary.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 16),
                Text(
                  l10n.confirmFlashTargetInternalHidden,
                  style: TextStyle(
                    fontSize: 12,
                    color: kTextPrimary.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancelButton),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.confirmFlashTargetAccept),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  /// Stop the flash and hand control back to the user.
  ///
  /// The build path starts the flash whenever it is neither running nor
  /// already started, so a failure that only clears those two flags is picked
  /// up again on the very next frame and spins. Blocking is what turns a
  /// failure the code cannot resolve by itself into a manual retry.
  void _blockMdbFlash() {
    if (!mounted) return;
    setState(() {
      _isProcessing = false;
      _mdbFlashStarted = false;
      _mdbFlashBlocked = true;
    });
  }

  Future<void> _flashMdb() async {
    if (_windowClosing || !mounted) return;
    final l10n = AppLocalizations.of(context)!;
    // Timings from real runs: the path resolves in seconds, the bmap write of
    // a stage-0 image takes about a minute and a half. The flasher's own
    // per-phase messages carry the detail and land in the log tail.
    _beginWait([
      WaitStep(
          label: l10n.waitingForDevicePath,
          typical: const Duration(seconds: 15)),
      WaitStep(
          label: l10n.flashingMdb, typical: const Duration(seconds: 90)),
    ]);
    setState(() => _isProcessing = true);
    final criticalOperation = _acquireCriticalOperation();

    if (_isDryRun) {
      try {
        for (var i = 0; i <= 10; i++) {
          _setStatus(
            '[DRY RUN] Simulating flash... ${i * 10}%',
            progress: i / 10,
          );
          await Future.delayed(const Duration(milliseconds: 200));
          if (!mounted) return;
        }
        _setPhase(InstallerPhase.scooterPrep);
        return;
      } finally {
        criticalOperation.release();
      }
    }

    await DriverService.suppressAutoPlay();
    await DiskArbitrationService.armWatch();
    try {
      bool mdbDownloadsReady() {
        final image = _downloadState.itemOfType(DownloadItemType.mdbFirmware);
        final bmap = _downloadState.itemOfType(DownloadItemType.mdbBmap);
        return image != null &&
            image.isComplete &&
            (bmap == null || bmap.isComplete);
      }

      if (!mdbDownloadsReady()) {
        _setStatus(l10n.waitingForMdbFirmware);
        await waitForDownloads(
          isReady: mdbDownloadsReady,
          currentError: () => _downloadState.error,
          isCancelled: () => !mounted,
        );
      }
      final mdbItem = _downloadState.itemOfType(DownloadItemType.mdbFirmware)!;

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
        criticalOperation.release();
        _setStatus(l10n.noDevicePathFound);
        _blockMdbFlash();
        return;
      }
      debugPrint('Flash: device path resolved: $devicePath');

      final flashService = FlashService()..l10n = l10n;

      // Fall back to the detector's own last-known device: _device is set
      // from the poll stream via setState, so it can lag a frame behind the
      // path we just resolved. Without the fallback that lag would present
      // as vendorId 0 and block a perfectly good flash. If both are null we
      // genuinely cannot confirm what we are about to write to, and the
      // guard below refuses -- which is the outcome we want.
      final target = _device ?? _usbDetector.currentDevice;

      // Windows could not say whether this disk carries boot or system. The
      // detector already matched it by vendor and product, so put that to the
      // user rather than guessing in either direction.
      // Only a mass-storage target is worth confirming; anything else is
      // refused by the product-ID guard regardless of the answer.
      if (target != null &&
          target.mode == DeviceMode.massStorage &&
          target.systemDiskVerdict == SystemDiskVerdict.unknown) {
        final confirmed = await _confirmFlashTarget(target, devicePath);
        if (!mounted) return;
        if (!confirmed) {
          debugPrint('Flash: user did not confirm $devicePath as the target');
          criticalOperation.release();
          _setStatus(l10n.flashTargetNotConfirmed);
          _blockMdbFlash();
          return;
        }
        debugPrint('Flash: user confirmed $devicePath as the target');
      }

      // Linux has no verdict from the enumeration itself, so ask now, with the
      // resolved path in hand. Anything mounted on the disk answers this
      // without needing to know which disk is which.
      final linuxVerdict = Platform.isLinux
          ? await _usbDetector.linuxSystemDiskVerdict(devicePath)
          : null;
      if (linuxVerdict != null) {
        debugPrint(
          'Flash: linux system-disk verdict for $devicePath: '
          '${linuxVerdict.name}',
        );
      }
      final safetyCheck = flashService.validateDevice(
        devicePath: devicePath,
        sizeBytes: target?.sizeBytes,
        isRemovable: target?.isRemovable ?? false,
        isSystemDisk: target?.isSystemDisk ?? false,
        vendorId: target?.vendorId ?? 0,
        productId: target?.productId ?? 0,
        // Inert in validateDevice off Linux, but passed so a rule added
        // there later reads the real verdict rather than a constant unknown.
        systemDiskVerdict:
            linuxVerdict ?? target?.systemDiskVerdict ?? SystemDiskVerdict.unknown,
        detectedPath: target?.path,
      );
      if (!safetyCheck.passed) {
        debugPrint(
          'Flash: safety check failed: ${safetyCheck.errors.join('; ')}',
        );
        criticalOperation.release();
        _setStatus(
          '${l10n.safetyCheckFailed}: ${l10n.cannotFlashSafety}\n${safetyCheck.errors.join('\n')}',
        );
        _blockMdbFlash();
        return;
      }

      final bmapPath = _downloadState.bmapPathFor(DownloadItemType.mdbFirmware);
      _setStatus(l10n.flashingMdb);
      await flashService.writeTwoPhase(
        mdbItem.localPath!,
        devicePath,
        bmapPath: bmapPath,
        onProgress: (progress, message) {
          _setStatus(message, progress: progress);
        },
      );

      criticalOperation.release();
      _setStatus(l10n.mdbFlashComplete);
      await Future.delayed(const Duration(seconds: 1));
      _setPhase(InstallerPhase.scooterPrep);
    } on DownloadWaitCancelled {
      return;
    } catch (e, stackTrace) {
      debugPrint('Flash ERROR: $e');
      debugPrint('Flash STACKTRACE: $stackTrace');
      criticalOperation.release();

      final errText = e.toString();
      final downloadFailure = e is DownloadWaitFailure;
      final midWrite = RegExp(r'write at offset (\d+)').firstMatch(errText);
      final pathGone =
          errText.contains('No such file or directory') ||
          errText.contains('authopen') ||
          errText.contains('device not configured');

      String diagnosis = errText;
      if (downloadFailure) {
        diagnosis = errText;
      } else if (midWrite != null) {
        final offset = int.tryParse(midWrite.group(1)!);
        final mb = offset == null
            ? '?'
            : (offset / (1024 * 1024)).toStringAsFixed(1);
        diagnosis +=
            '\n\nDevice stopped responding mid-write at $mb MB. '
            'This is almost always the USB cable or port. '
            'Unplug and replug the USB cable (try a different cable or port), then retry. '
            'Only power-cycle the MDB if the device does not reappear.';
      } else if (pathGone || _device == null) {
        diagnosis +=
            '\n\nDevice is no longer present. '
            'Unplug and replug the USB cable, then retry. '
            'Only power-cycle the MDB if the device does not reappear.';
      } else if (_device!.mode != DeviceMode.massStorage) {
        diagnosis +=
            '\n\nDevice is in ${_device!.mode.name} mode, not mass storage. '
            'Power-cycle the board so u-boot re-enters UMS mode.';
      } else {
        diagnosis += '\n\nDevice is still visible: you can retry.';
      }
      _setStatus(diagnosis);
      setState(() => _isProcessing = false);

      if (!await _shouldRetry('mdbFlash')) {
        _blockMdbFlash();
        return;
      }

      // Wait for the device to come back before re-running the flash —
      // otherwise we burn retries against a stale path that can't be
      // opened. Detector was resumed by releasing our lease above.
      _setStatus('$diagnosis\n\nWaiting for the device to be re-detected...');
      final back = await _waitForMassStorageDevice(
        timeout: const Duration(seconds: 60),
      );

      // A board that comes back as a network device booted the image, which
      // means the write that "failed" had already finished. Retrying then
      // waits forever for a mass-storage device that is never coming, and the
      // user is stuck in front of a flash screen for a flash that is done.
      //
      // _mdbFlashStarted stays set, as on the success path above. Clearing it
      // satisfies the build path's start conditions again and launches a
      // second flash before the phase change lands.
      if (!back && _device?.mode == DeviceMode.ethernet) {
        debugPrint('Flash: board booted the image, treating the flash as done');
        _setStatus(l10n.mdbFlashComplete);
        await Future.delayed(const Duration(seconds: 1));
        _setPhase(InstallerPhase.scooterPrep);
        return;
      }

      if (!back) {
        _setStatus(
          '$diagnosis\n\nDevice did not come back within 60s. '
          'Replug the USB (or, as a last resort, power-cycle the MDB) '
          'and use the manual retry button.',
        );
        _blockMdbFlash();
        return;
      }
      setState(() => _mdbFlashStarted = false);
    } finally {
      try {
        await DriverService.restoreAutoPlay();
        await DiskArbitrationService.disarmWatch();
      } finally {
        criticalOperation.release();
      }
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
    return PhaseLayout(
      title: l10n.scooterPrepHeading,
      subtitle: l10n.scooterPrepSubheading,
      actions: [
        PhaseAction(
          // The two routes leave the scooter in different states. Only the
          // brake gesture restarts it; the manual route ends with AUX off and
          // the next screen asking for it back.
          label: _manualPowerCut
              ? l10n.doneAuxDisconnected
              : l10n.doneCbbAuxDisconnected,
          icon: Icons.arrow_forward,
          primary: true,
          onPressed: () => _setPhase(InstallerPhase.mdbBoot),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The brake gesture is the primary route because it reaches the same
          // outcome without the seatbox: no main battery to lift out, no CBB to
          // unplug, no pole to unbolt, and so none of the ways those go wrong.
          // The nRF52 sees the brake line directly, which is why it still works
          // with the main processor parked in the bootloader.
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.cyan.shade900.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.cyan.shade800),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.brakeResetHeading,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.brakeResetIntro,
                  style: TextStyle(color: Colors.grey.shade300, height: 1.4),
                ),
                const SizedBox(height: 18),
                const BrakeGesturePacer(),
                const SizedBox(height: 14),
                Text(
                  l10n.brakeResetAfterNote,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Kept, not replaced: a scooter whose levers are already apart for
          // other work, or one where the gesture does not take, still needs the
          // route that always works.
          ExpansionTile(
            // Grey caption text read as a label, and opening this is what
            // tells the rest of the flow the user took the manual route, so
            // it has to look like the control it is.
            leading: const Icon(Icons.build_outlined, size: 20, color: kAccent),
            title: Text(
              l10n.scooterPrepManualFallback,
              style: const TextStyle(
                fontSize: 14,
                color: kAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
            // Opening it is the signal. A false positive costs a step the user
            // can ignore; a false negative hides the one instruction they
            // needed, so err toward remembering.
            onExpansionChanged: (open) {
              if (open && !_manualPowerCut) {
                setState(() => _manualPowerCut = true);
              }
            },
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InstructionStep(
                number: 1,
                title: l10n.disconnectCbb,
                description: l10n.disconnectCbbDesc,
                isWarning: true,
                beforeImageAsset:
                    'assets/images/lsi-unu_scooter_cbb_connected.jpg',
                imageAsset:
                    'assets/images/lsi-unu_scooter_cbb_disconnected.jpg',
              ),
              InstructionStep(
                number: 2,
                title: l10n.disconnectAuxPole,
                description: l10n.disconnectAuxPoleDesc,
                isWarning: true,
                beforeImageAsset:
                    'assets/images/lsi-unu_scooter_aux_connected.jpg',
                imageAsset:
                    'assets/images/lsi-unu_scooter_aux_pos_disconnected.jpg',
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
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMdbBoot(AppLocalizations l10n) {
    // The manual route has something to do on this screen - the AUX pole goes
    // back on - so it keeps the whole frame. The brake-gesture route is pure
    // waiting, and a failure gets the frame back for the retry.
    if (!_manualPowerCut && !_mdbBootAttempt.isFailed) {
      return _waitPhase(
        title: l10n.waitingForMdbBoot,
        warning: l10n.dbcFlashDoNotDisconnect,
      );
    }
    return _waitingPhase(
      title: l10n.waitingForMdbBoot,
      status: _statusMessage.isEmpty
          ? l10n.waitingForUsbDevice
          : _statusMessage,
      actions: [
        if (_mdbBootAttempt.isFailed)
          PhaseAction(
            label: l10n.retryMdbBoot,
            icon: Icons.refresh,
            primary: true,
            onPressed: _startMdbBoot,
          ),
      ],
      extra: [
        const SizedBox(height: 20),
        // Only the manual route unplugs anything, and the installer cannot
        // tell the two restarts apart from outside, so this follows what the
        // user actually chose. Asking for an AUX pole back from someone who
        // used the brake gesture sends them looking for a screw they never
        // undid.
        if (_manualPowerCut)
          InstructionStep(
            number: 1,
            title: l10n.reconnectAuxPole,
            description: l10n.reconnectAuxPoleDesc,
            imageAsset: 'assets/images/lsi-unu_scooter_aux_connected.jpg',
          )
        else
          Text(
            l10n.mdbBootRestartingNote,
            style: TextStyle(color: Colors.grey.shade400),
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: 16),
        Text(
          l10n.dbcLedHint,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
        ),
      ],
    );
  }

  void _startMdbBoot() {
    if (!mounted || _currentPhase != InstallerPhase.mdbBoot) return;
    final generation = _mdbBootAttempt.begin();
    if (generation == null) return;
    setState(() => _isProcessing = true);
    unawaited(_waitForMdbBoot(generation));
  }

  /// Whether this reconnect run is still the live one.
  ///
  /// Retrying supersedes rather than queues: the newer run owns _isProcessing
  /// and the substep list, so a superseded run returns without touching
  /// either. Without this, offering a retry during the wait would let two
  /// runs write the same substeps and share one SSH session.
  bool _ownsReconnect(int generation) {
    return mounted &&
        _currentPhase == InstallerPhase.reconnect &&
        _reconnectAttempt.isCurrent(generation);
  }

  bool _ownsMdbBootAttempt(int generation) {
    return mounted &&
        _currentPhase == InstallerPhase.mdbBoot &&
        _mdbBootAttempt.isCurrent(generation);
  }

  void _failMdbBoot(int generation, String message) {
    if (!_ownsMdbBootAttempt(generation)) return;
    _setStatus(message);
    setState(() {
      _isProcessing = false;
      _mdbBootAttempt.fail(generation, message);
    });
  }

  Future<void> _waitForMdbBoot(int generation) async {
    final l10n = AppLocalizations.of(context)!;
    // The board is off for most of this; two minutes is normal, and saying so
    // is the difference between waiting and reaching for the cable. Measured
    // on a healthy board: gadget back on the bus at +10s, network up at
    // ~+114s, ten stable pings at ~+132s. A typical under that marks every
    // good boot as running long, which is how an overdue mark stops meaning
    // anything.
    _beginWait([
      WaitStep(
          label: l10n.waitingStableConnection,
          typical: stableConnectionTypical),
      WaitStep(
          label: l10n.reconnectingSsh, typical: const Duration(seconds: 25)),
    ]);

    if (_isDryRun) {
      _setStatus('[DRY RUN] Simulating MDB boot...');
      await Future.delayed(const Duration(seconds: 2));
      if (!_ownsMdbBootAttempt(generation)) return;
      _mdbBootAttempt.complete(generation);
      _setPhase(_beginMdbInstall());
      return;
    }

    // A board still in mass storage has not been restarted yet: that is the
    // state a successful flash leaves it in, and the restart is what ends it.
    // Only a board that goes away and comes BACK as mass storage failed to
    // take the image, so wait for it to leave before judging the mode, or a
    // correctly written board gets re-written at the moment its power is
    // pulled.
    //
    // A board that is already anything else has restarted, whether or not this
    // screen saw it happen. Waiting for it to disappear then would be waiting
    // for something that is already done.
    var sawRestart = false;
    while (true) {
      final action = mdbBootActionFor(
        mode: _device?.mode,
        sawRestart: sawRestart,
      );
      if (action == MdbBootAction.proceed || action == MdbBootAction.reflash) {
        break;
      }
      _setStatus(switch (action) {
        MdbBootAction.waitForRestart => l10n.waitingForMdbRestart,
        // The board is announcing this on the bus under the boot ROM's own
        // identity. Saying nothing leaves an operator watching a wait that
        // looks identical to a slow boot, and the one thing that would cost
        // them the board here is deciding to intervene.
        MdbBootAction.waitForRecovery => l10n.waitingForBoardRecovery,
        _ => l10n.waitingForUsbDevice,
      });
      // Leaving mass storage, or leaving the bus at all, is the restart.
      if (_device?.mode != DeviceMode.massStorage) sawRestart = true;
      await Future.delayed(const Duration(seconds: 1));
      if (!_ownsMdbBootAttempt(generation)) return;
    }

    if (mdbBootActionFor(mode: _device?.mode, sawRestart: sawRestart) ==
        MdbBootAction.reflash) {
      if (!_ownsMdbBootAttempt(generation)) return;
      _mdbBootAttempt.complete(generation);
      _setStatus(l10n.mdbStillUms);
      setState(() {
        _isProcessing = false;
        _mdbFlashStarted = false;
        _mdbFlashBlocked = false;
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
    //
    // The board came back on a fresh device node, so Windows ranked its
    // drivers again from scratch and anything that outranks ours has just
    // won. Put the binding back before assuming there is an interface.
    await _ensureDriverBinding();
    if (!_ownsMdbBootAttempt(generation)) return;

    final networkService = NetworkService();
    final iface = await networkService.findLibrescootInterface();
    if (!_ownsMdbBootAttempt(generation)) return;
    if (iface != null) {
      try {
        await networkService.configureInterface(iface);
      } on NetworkPrivilegeException catch (e) {
        _failMdbBoot(generation, l10n.errorPrefix(e.toString()));
        return;
      }
      if (!_ownsMdbBootAttempt(generation)) return;
    }

    // A board that has just been written boots stage 0 from scratch, which
    // takes a couple of minutes. Until that is up, pings failing is what a
    // healthy install looks like, so the hint about the host's network stack
    // has to stay off the screen for longer than the boot takes. It used to
    // count loop iterations rather than seconds, and each iteration is a ping
    // plus a delay, so "15" arrived after about 27 seconds and accused
    // NetworkManager while the scooter was still starting up.
    const stallHintAfter = stableConnectionStallAfter;
    var stableCount = 0;
    DateTime? failingSince;
    var diagnosticsLogged = false;
    while (stableCount < 10) {
      final reachable = await _pingMdb();
      if (!_ownsMdbBootAttempt(generation)) return;
      if (reachable) {
        stableCount++;
        failingSince = null;
        _setStatus(l10n.pingStable(stableCount));
      } else {
        stableCount = 0;
        failingSince ??= DateTime.now();
        final failedFor = DateTime.now().difference(failingSince);
        if (failedFor >= stallHintAfter &&
            !diagnosticsLogged &&
            Platform.isLinux &&
            iface != null) {
          diagnosticsLogged = true;
          final diag = await networkService.gatherLinuxDiagnostics(iface.name);
          if (!_ownsMdbBootAttempt(generation)) return;
          debugPrint(
            'Network: stable-ping stalled ${failedFor.inSeconds}s '
            'on ${iface.name}.\n$diag',
          );
          _setStatus(l10n.stableConnectionStallHint);
        } else if (!diagnosticsLogged) {
          _setStatus(l10n.waitingStableConnection);
        }
      }
      await Future.delayed(const Duration(seconds: 1));
      if (!_ownsMdbBootAttempt(generation)) return;
    }

    _setStatus(l10n.reconnectingSsh);
    try {
      await _sshService.connectToMdb();
      if (!_ownsMdbBootAttempt(generation)) return;

      // Disable keycard-service for the rest of the install. A freshly flashed
      // MDB boots into auto-master-learn mode; any tap before the explicit
      // keycard-setup phase would silently teach in a master card. We re-start
      // the service on entry to that phase, after disengaging master mode.
      try {
        await _sshService.runCommand(
          'systemctl stop librescoot-keycard 2>/dev/null; true',
        );
        debugPrint(
          'SSH: stopped librescoot-keycard to prevent accidental master teach-in',
        );
      } catch (_) {}

      // Reapply the install-time scooter config on the freshly-flashed image:
      // usb0 must stay up while the scooter is locked (so we keep RNDIS for
      // the rest of the install), auto-standby and the alarm must be off so
      // the next 10–20 minutes of DBC flash + BT pairing + keycard setup
      // don't put the MDB into suspend or honk the alarm at the workshop.
      // All three get reset at finish — see _resetPersistedSettings.
      //
      // All of them are redis writes, and the image running right now is the
      // stage-0 bootstrap one whenever the artifact phase is what comes next,
      // which has no redis for them to reach. Skip them in that case and let
      // the artifact phase run them after its reboot. Note this is not the
      // same test as _expectMinimalMdb: the shortcut that finds the board
      // already in mass storage also writes a stage-0 image without ever
      // setting that flag.
      if (!_mdbArtifactPending) {
        try {
          await _sshService.runCommand('lsc set scooter.usb0-policy always-on');
          debugPrint('UI: scooter.usb0-policy=always-on (mdb-boot)');
        } catch (e) {
          debugPrint(
            'UI: failed to set scooter.usb0-policy=always-on at mdb-boot (ok): $e',
          );
        }
        await _disableInstallerHazards(label: 'mdb-boot');
      }

      // Restore radio-gaga config if we backed it up. It lands in /data, and
      // a board that just took a stage-0 image is still resizing and mounting
      // that: restoreRadioGagaConfig would mkdir -p and upload into the
      // rootfs directory the real partition is about to shadow, then report
      // success. Wait for the mount first.
      if (_radioGagaBackupPath != null) {
        _setStatus(l10n.restoringConfig);
        if (!await _waitForDataPartition()) return;
        if (!_ownsMdbBootAttempt(generation)) return;
        final restored = await _sshService.restoreRadioGagaConfig(
          _radioGagaBackupPath!,
        );
        if (restored) {
          debugPrint('UI: radio-gaga config restored to /data/radio-gaga/');
        }
      }

      if (!_ownsMdbBootAttempt(generation)) return;
      _mdbBootAttempt.complete(generation);
      _setPhase(_beginMdbInstall());
    } on DataPartitionWaitException catch (e) {
      _failMdbBoot(generation, l10n.errorPrefix(e.toString()));
    } catch (e) {
      _failMdbBoot(generation, l10n.sshReconnectionFailed(e.toString()));
    }
  }

  /// What the dashboard says while the trampoline works, in the language this
  /// installer is running in.
  ///
  /// The operator reading the dashboard is the one who started the run, so the
  /// UI language is the right one. Separate from [DeviceFinish.language],
  /// which is the owner's dashboard language afterwards.
  DashboardMessages _buildDashboardMessages() {
    final l10n = AppLocalizations.of(context)!;
    return DashboardMessages(
      banner: l10n.dbcSayBanner,
      installing: l10n.dbcSayInstalling,
      installed: l10n.dbcSayInstalled,
      // The version is not ours to fill: the script reads it off the board
      // after the reboot, long after this string is written.
      running: l10n.dbcSayRunning(DashboardMessages.versionToken),
      maps: l10n.dbcSayMaps,
      routing: l10n.dbcSayRouting,
      failed: l10n.dbcSayFailed,
      swap1: l10n.dbcSaySwap1,
      swap2: l10n.dbcSaySwap2,
      done: l10n.dbcSayDone,
      failOnboot: l10n.dbcSayFailOnboot,
      failDbc: l10n.dbcSayFailDbc,
      failTiles: l10n.dbcSayFailTiles(DashboardMessages.tileErrorsToken),
    );
  }

  /// What the trampoline needs to close the install out without the laptop.
  /// Everything here is settled by the time the dashboard files are staged:
  /// the plan on the plan screen, the language on the welcome screen, the
  /// channel with the download queue, and the keycards two phases ago.
  DeviceFinish _buildDeviceFinish() {
    final lang = Localizations.localeOf(context).languageCode;
    final artifact = _downloadState.artifactFor(Board.mdb);
    return DeviceFinish(
      onDevice: true,
      // No plan means the mass-storage shortcut, which writes a full image
      // and so erases /data. That is the non-upgrade branch, same as a clean
      // install: there are no settings left worth restoring.
      mdbAction: _plan?.mdb.action ?? BoardAction.fullImage,
      mdbTargetVersion: artifact == null
          ? ''
          : _downloadState.releaseTag ??
                _versionFromArtifactFilename(artifact.filename) ??
                '',
      // Anything outside the two the dashboard ships would be a settings key
      // it cannot honour, so leave it unset and let the default stand.
      language: (lang == 'en' || lang == 'de') ? lang : '',
      otaChannel: _downloadState.channel.name,
    );
  }

  /// Where the CBB step hands off. There are two ways into it and they arrive
  /// from opposite sides of the pairing block: after the artifact gate, where
  /// pairing is already behind us, and straight from the plan screen when
  /// there is no MDB work at all, where it has not happened yet. Sending the
  /// second case onward would skip pairing and keycards for a dashboard-only
  /// install.
  InstallerPhase get _phaseAfterCbbReconnect => (_plan?.needsHandoff ?? true)
      ? InstallerPhase.dbcPrep
      : InstallerPhase.finish;

  /// Where the artifact gate hands off once the board is on the new version.
  InstallerPhase get _phaseAfterMdbInstall => _phaseBeforeDbcWork;

  /// The dashboard work, or the CBB step first when there is a disconnection
  /// to undo.
  ///
  /// Only the manual power cut asks the user to unplug the CBB, and only that
  /// route has anything to check afterwards. On every other route the CBB has
  /// not been touched since the health check said it was fine, so the screen
  /// has nothing to say and stands between the user and the upload progress.
  InstallerPhase get _phaseBeforeDbcWork {
    if (!(_plan?.needsHandoff ?? true)) return InstallerPhase.finish;
    return _manualPowerCut
        ? InstallerPhase.cbbReconnect
        : InstallerPhase.dbcPrep;
  }

  /// Where the pairing block hands off. Bluetooth and keycards run before
  /// the dashboard is flashed, because the trampoline stops and masks
  /// librescoot-bluetooth and librescoot-keycard for the whole of its run
  /// and the laptop is unplugged by then: a pairing window opened after
  /// TrampolineService.start() has no services behind it. With no dashboard
  /// work in the plan there is no trampoline either, so the laptop-side
  /// finish takes over directly.
  InstallerPhase get _phaseAfterKeycardSetup {
    // The gate first, whenever there is artifact work to collect. It is where
    // the background install is waited on and the single reboot happens.
    if (_mdbArtifactPending || _mdbStageStarted) {
      return InstallerPhase.mdbArtifact;
    }
    return _phaseBeforeDbcWork;
  }

  /// Where a freshly flashed MDB goes next. Stage 0 writes a bootstrap image
  /// that still needs the artifact on top; the full sdimg of the fall-back
  /// path already carries the firmware, so it goes straight on. With no plan
  /// at all (the shortcut that finds the board already in mass storage) the
  /// image written was the stage-0 one, so the artifact is still due.
  /// Whether the board still needs the firmware artifact on top. No plan at
  /// all means the mass storage shortcut, which writes a stage-0 image and so
  /// still needs one.
  bool get _mdbArtifactPending => _plan?.needsMdbArtifact ?? true;

  /// Send the user to the interactive work and start the machine work behind
  /// it. Everything the artifact install needs is known by now, and nothing it
  /// does requires anyone to be watching.
  InstallerPhase _beginMdbInstall() {
    _beginBackgroundUploads();
    return InstallerPhase.bluetoothPairing;
  }

  /// Start every laptop-to-MDB transfer behind whatever screen the user is on.
  ///
  /// Everything these need is settled once the plan is confirmed and none of
  /// it requires anyone watching, so they run under the pairing and keycard
  /// screens. The artifact goes first and the dashboard files follow, one
  /// transfer at a time: they share a single SSH session. The dashboard files
  /// land in /data, which survives the reboot the artifact gate performs.
  ///
  /// Only laptop-to-MDB transfers belong here. Moving anything on to the
  /// dashboard is the trampoline's work and cannot begin until the cable has
  /// been swapped.
  void _beginBackgroundUploads() {
    if (_mdbArtifactPending) {
      unawaited(_stageMdbArtifact().whenComplete(_beginBackgroundDbcUpload));
    } else {
      _beginBackgroundDbcUpload();
    }
  }

  void _beginBackgroundDbcUpload() {
    if (!mounted) return;
    if (!(_plan?.needsHandoff ?? true)) return;
    if (_dbcPrepStarted) return;
    _dbcPrepStarted = true;
    _dbcStageInFlight = true;
    // The line goes away with the transfer, however it ends.
    unawaited(_uploadDbcFiles(background: true)
        .whenComplete(() => _setBackgroundStatus(null)));
  }

  Future<bool> _pingMdb() async {
    try {
      final result = await Process.run('ping', [
        if (Platform.isWindows) ...[
          '-n',
          '1',
          '-w',
          '1000',
        ] else ...[
          '-c',
          '1',
          '-W',
          '1',
        ],
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
      if (!mounted || _cbbPollAbandoned) {
        debugPrint('CBB: poll dropped, the phase moved on');
        return false;
      }
      if (await _sshService.isCbbPresent()) {
        debugPrint('CBB: insert detected on cb-battery');
        return true;
      }
      if (!mounted || _cbbPollAbandoned) return false;
      if (i + 1 == _cbbNoticeAfterIterations && !_cbbWaitNoticeShown) {
        setState(() => _cbbWaitNoticeShown = true);
      }
      _setStatus(l10n.waitingForCbb(i + 1));
      await Future.delayed(const Duration(seconds: 2));
    }
    debugPrint('CBB: poll timed out (no insert seen)');
    return false;
  }

  Widget _buildMdbArtifact(AppLocalizations l10n) {
    if (!_artifactStarted && !_isProcessing) {
      _artifactStarted = true;
      Future.microtask(_runMdbArtifactInstall);
    }
    // While the background work is still going this panel is the only thing
    // the user is waiting on, so show its progress rather than an idle bar.
    final staging =
        _mdbStageStarted && !_mdbStageDone && _mdbStageError == null;
    final error = _artifactError ?? _mdbStageError;
    if (error == null) {
      return _waitPhase(
        title: l10n.phaseMdbArtifactTitle,
        progress: staging
            ? (_mdbStageProgress > 0 ? _mdbStageProgress : null)
            : (_progress > 0 ? _progress : null),
        warning: l10n.dbcFlashDoNotDisconnect,
      );
    }
    // Only the failed case reaches here; the running one is an overlay.
    return PhaseLayout(
      title: l10n.phaseMdbArtifactTitle,
      actions: [
        ...[
          // Writing the whole image instead is a different install, not a
          // second go at this one, so it is kept apart from the retry.
          PhaseAction(
            label: l10n.artifactFallBackToFullImage,
            side: ActionSide.back,
            onPressed: _fallBackToFullImage,
          ),
          PhaseAction(
            label: l10n.artifactRetry,
            primary: true,
            onPressed: () {
              setState(() {
                _artifactError = null;
                _artifactStarted = false;
                _mdbStageError = null;
                _mdbStageStarted = false;
                _mdbStageDone = false;
                _mdbStageProgress = 0;
              });
            },
          ),
        ],
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ArtifactProgressPanel(
            // The run has stopped, so the last live status is not what is
            // happening any more. Leaving it there had the screen saying it
            // was reconnecting directly above saying it had given up.
            status: '',
            progress: 0,
            error: error,
          ),
          if (error == l10n.artifactRebootTimeout) ...[
            const SizedBox(height: 12),
            Text(
              l10n.artifactRebootTimeoutHint,
              style: TextStyle(
                  fontSize: 13, height: 1.4, color: Colors.grey.shade400),
            ),
          ],
          const SizedBox(height: 20),
          // Both buttons are offered together and one of them erases the
          // board, so each says what it costs rather than leaving the user to
          // infer it from the label.
          _flashNote(Icons.refresh, l10n.artifactRetryDetail),
          const SizedBox(height: 8),
          _flashNote(Icons.delete_forever, l10n.artifactFullImageDetail,
              danger: true),
        ],
      ),
    );
  }

  /// Wait for /data to be mounted and grown. A board that has just taken a
  /// stage-0 image resizes its data partition on first boot, and until
  /// data.mount has run, `df /data` answers for the root filesystem instead,
  /// which would make the free-space preflight meaningless.
  Future<bool> _waitForDataPartition() async {
    final result = await waitForMdbDataPartition(
      runCommand: (command) => _sshService.runCommand(command),
      isCancelled: () => !mounted,
    );
    return result == DataPartitionWaitResult.ready;
  }

  /// Wait for the board to come back after a reboot we issued, and
  /// re-establish SSH. Unlike _waitForMdbBoot this does not set a phase: the
  /// caller is mid-install and decides where to go next.
  Future<void> _reconnectAfterReboot(
    AppLocalizations l10n, {
    Duration settle = const Duration(seconds: 15),
  }) async {
    // Let the board actually go down first. reboot() returns as soon as the
    // command is accepted, so connecting immediately would land on the system
    // that is about to disappear. A caller that is not following a reboot of
    // its own passes zero: there is nothing to wait out.
    if (settle > Duration.zero) await Future.delayed(settle);

    // Only log a status line when it changes: this loop runs for up to five
    // minutes and _setStatus appends to the installer log every time.
    String? shown;
    void status(String message) {
      if (shown == message) return;
      shown = message;
      _setStatus(message);
    }

    status(l10n.configuringNetwork);
    final networkService = NetworkService();
    final deadline = DateTime.now().add(const Duration(minutes: 5));
    NetworkPrivilegeException? privilegeError;
    while (DateTime.now().isBefore(deadline)) {
      if (!mounted) return;

      // Reconfigure on every pass rather than once on a timer. The reboot
      // tears down the USB ethernet interface, so at any single early moment
      // the interface is either the dying pre-reboot one or not there at all,
      // and on Linux+NetworkManager the replacement comes back as a fresh
      // enxXXXX carrying neither our unmanaged flag nor 192.168.7.50. A
      // one-shot call therefore configures nothing that survives, and nothing
      // would ever configure the interface the board actually comes back on.
      // configureInterface no-ops once the board answers, so repeating it is
      // cheap.
      final iface = await networkService.findLibrescootInterface();
      if (iface != null) {
        try {
          await networkService.configureInterface(iface);
          privilegeError = null;
        } on NetworkPrivilegeException catch (e) {
          // Not fatal on the spot: the macOS auth dialog is asynchronous, so
          // a later pass often succeeds. Held on to so a loop that runs out
          // reports the real reason instead of a bare timeout.
          privilegeError = e;
          debugPrint('Network: post-reboot configure needs privileges: $e');
        }
      }

      // The connection attempt is not gated on the USB detector.
      // _setCritical paused it for the duration of the install, so _device is
      // frozen at whatever the last poll left there, and a frozen null would
      // suppress every attempt for the full five minutes on a board that came
      // back fine.
      status(iface == null ? l10n.waitingForUsbDevice : l10n.reconnectingSsh);
      try {
        final info = await _sshService.connectToMdb();
        if (!mounted) return;
        setState(() => _mdbInfo = info);
        return;
      } catch (e) {
        debugPrint('SSH: post-reboot connect not ready: $e');
      }

      await Future.delayed(const Duration(seconds: 5));
    }
    if (privilegeError != null) {
      throw _LocalizedInstallException(
        l10n.errorPrefix(privilegeError.toString()),
      );
    }
    throw _LocalizedInstallException(l10n.artifactRebootTimeout);
  }

  /// The version component of a release asset name, e.g.
  /// `librescoot-unu-mdb-1.2.1.mender` -> `1.2.1`. The image recipes build
  /// the asset name and the board's VERSION_ID from the same variable, so
  /// this is what a board has to report once the artifact is actually
  /// running. Only a fallback: the release tag says the same thing and is
  /// what the rest of the flow compares against.
  static String? _versionFromArtifactFilename(String filename) => RegExp(
    r'^librescoot-unu-(?:mdb|dbc)-(.+)\.mender$',
  ).firstMatch(filename)?.group(1);

  /// Upload the artifact and run mender, without rebooting. Kicked off as soon
  /// as the board is up and left to run while the user pairs a phone and
  /// enrols keycards, because those are the only two things in the flow that
  /// need a human and this is the longest thing that does not.
  ///
  /// The reboot is deliberately not here: it belongs to the gate, after both
  /// the machine work and the human work are done, so the board goes down once
  /// and at a moment nobody is mid-tap.
  Future<void> _stageMdbArtifact() async {
    if (_mdbStageStarted) return;
    _mdbStageStarted = true;
    final l10n = AppLocalizations.of(context)!;

    if (_isDryRun) {
      for (var pct = 0; pct <= 100; pct += 20) {
        if (!mounted) return;
        setState(() => _mdbStageProgress = pct / 100);
        await Future.delayed(const Duration(milliseconds: 120));
      }
      if (mounted) setState(() => _mdbStageDone = true);
      return;
    }

    final item = _downloadState.artifactFor(Board.mdb);
    if (item == null) {
      if (mounted) setState(() => _mdbStageError = l10n.artifactNoneDownloaded);
      return;
    }

    try {
      if (item.localPath == null) {
        while (item.localPath == null) {
          await Future.delayed(const Duration(seconds: 1));
          if (!mounted) return;
          if (_downloadState.error != null) {
            throw Exception(_downloadState.error);
          }
        }
      }

      final artifacts = ArtifactService(
        _sshService,
        TrampolineService(_sshService),
      );
      if (!await _waitForDataPartition()) return;
      if (!mounted) return;

      final preflight = await artifacts.preflight(
        board: Board.mdb,
        artifactBytes: item.expectedSize,
        assetName: item.filename,
      );
      if (!preflight.ok) {
        throw _LocalizedInstallException(_preflightMessage(l10n, preflight));
      }

      // Upload only. mender runs on the far side of the cable swap, as
      // 10-mdb-artifact.sh, so the upload is the whole of this bar.
      await artifacts.stage(
        board: Board.mdb,
        localPath: item.localPath!,
        onProgress: (sent, total) {
          if (mounted && total > 0) {
            setState(() => _mdbStageProgress = sent / total);
          }
        },
      );
      if (!mounted) return;
      if (mounted) {
        setState(() {
          _mdbStageDone = true;
          _mdbStageProgress = 1;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _mdbStageError = e.toString());
    }
  }

  Future<void> _runMdbArtifactInstall() async {
    final l10n = AppLocalizations.of(context)!;
    // Staging is a minute of upload, the install about two, and the reboot
    // and the version check together about two more.
    // The status line carries a live percentage. The step NAME must not, or
    // the list shows the figure it was built with for the whole install.
    final installing = l10n.artifactInstalling(0).split('(').first.trimRight();
    // A retry arrives here with the session gone, and the first SSH call
    // reconnects lazily inside the upload. Without a step for that, the
    // transfer was shown as active and its clock running while there was no
    // connection to transfer over, so the elapsed figure measured the wait for
    // a reconnect and the estimate derived from it meant nothing.
    final reconnecting = !_isDryRun && !_sshService.isConnected;
    _beginWait([
      if (reconnecting)
        WaitStep(
            label: l10n.reconnectingSsh, typical: const Duration(seconds: 20)),
      WaitStep(
          label: l10n.artifactStaging, typical: const Duration(seconds: 60)),
      WaitStep(
        label: installing,
        matchPrefix: installing,
        typical: const Duration(minutes: 2),
      ),
      // The dashboard transfer runs behind this phase and the reboot waits on
      // it, so it is a step of this wait, not something happening elsewhere.
      WaitStep(
          label: l10n.waitingForDbcUpload,
          typical: const Duration(minutes: 3)),
      WaitStep(
          label: l10n.waitingForMdbRestart,
          typical: const Duration(minutes: 2)),
      WaitStep(
          label: l10n.artifactVerifying, typical: const Duration(minutes: 2)),
    ]);

    if (_isDryRun) {
      setState(() {
        _isProcessing = true;
        _artifactError = null;
      });
      for (var pct = 0; pct <= 100; pct += 10) {
        _setStatus(
          '[DRY RUN] ${l10n.artifactInstalling(pct)}',
          progress: pct / 100,
        );
        await Future.delayed(const Duration(milliseconds: 150));
        if (!mounted) return;
      }
      _expectMinimalMdb = false;
      _setPhase(_phaseAfterMdbInstall);
      return;
    }

    final item = _downloadState.artifactFor(Board.mdb);
    if (item == null) {
      setState(() {
        _artifactError = l10n.artifactNoneDownloaded;
        _isProcessing = false;
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _artifactError = null;
    });
    CriticalOperationLease? criticalOperation;
    try {
      // A retry after the post-reboot reconnect gave up starts here with no
      // session: reboot() disconnects on purpose and clears the stored
      // credential with it, so nothing below can re-establish one lazily.
      // Every probe then failed with "no stored credential", which
      // _waitForDataPartition reported as a verdict about /data, and no
      // amount of retrying could have changed it. Reconnect first, through
      // the same wait the reboot uses because the board may still be on its
      // way up, and let that report honestly when it cannot.
      if (!_sshService.isConnected) {
        debugPrint('UI: artifact install has no SSH session, reconnecting');
        await _reconnectAfterReboot(l10n, settle: Duration.zero);
        if (!mounted) return;
      }

      // Collect the work that has been running behind the pairing screens.
      // Nothing on the vehicle is written after this point except the reboot,
      // so this is the last moment where waiting costs the user anything.
      var alreadyInstalled = false;
      if (_mdbStageStarted) {
        criticalOperation ??= _acquireCriticalOperation();
        // The background job reports through _mdbStageProgress and emits no
        // status, so the wait plan has nothing to match and would sit on its
        // first step for the whole install. Mirror the job into the same
        // messages the foreground path uses, only when the text changes: this
        // loop runs for minutes and _setStatus appends to the log each time.
        String? shown;
        while (!_mdbStageDone && _mdbStageError == null) {
          // The job spends the first half staging and the second installing.
          final done = _mdbStageProgress;
          final staging = done < 0.5;
          final stepDone = staging ? done * 2 : (done - 0.5) * 2;
          final message = staging
              ? l10n.artifactStaging
              : l10n.artifactInstalling((stepDone * 100).round());
          if (message != shown) {
            shown = message;
            _setStatus(message, progress: stepDone);
          }
          await Future.delayed(const Duration(milliseconds: 500));
          if (!mounted) return;
        }
        if (_mdbStageError != null) {
          throw _LocalizedInstallException(_mdbStageError!);
        }
        alreadyInstalled = true;
      }
      // The artifact is first in the download queue, but an upgrade reaches
      // this phase without flashing anything, so it can still be in flight.
      // Waiting beats failing with "nothing was downloaded" at 90%.
      if (item.localPath == null) {
        _setStatus(l10n.waitingForDownloads);
        while (item.localPath == null) {
          await Future.delayed(const Duration(seconds: 1));
          if (!mounted) return;
          if (_downloadState.error != null) {
            throw Exception(_downloadState.error);
          }
        }
      }

      // From here on it is several hundred megabytes over the wire and then a
      // mender run with a 30 minute ceiling. On the clean-install route the
      // slot currently running is the stage-0 bootstrap image, so a window
      // close or a laptop sleep in the middle leaves a vehicle with no
      // service stack. The download wait above is deliberately outside this:
      // nothing on the vehicle is being written yet.
      criticalOperation ??= _acquireCriticalOperation();

      // Everything from here to the reboot is what the background job has
      // already done. Repeating it is not merely wasteful: mender refuses an
      // install while one is pending, so clearing that first would commit an
      // update that has never booted, which is the one thing an A/B scheme
      // exists to prevent.
      if (!alreadyInstalled) {
        final artifacts = ArtifactService(
          _sshService,
          TrampolineService(_sshService),
        );

        if (!await _waitForDataPartition()) return;
        if (!mounted) return;

        // preflight takes assetName so it can discount an artifact already at
        // the seed path: after a dropped link the file is often already there,
        // and counting its full size as space still needed would refuse a retry
        // that would in fact succeed.
        final preflight = await artifacts.preflight(
          board: Board.mdb,
          artifactBytes: item.expectedSize,
          assetName: item.filename,
        );
        if (!preflight.ok) {
          throw _LocalizedInstallException(_preflightMessage(l10n, preflight));
        }

        if (reconnecting) {
          // Explicitly, so the step is active while it actually happens.
          _setStatus(l10n.reconnectingSsh);
          await _sshService.ensureConnected('artifact retry');
        }
        _setStatus(l10n.artifactStaging, progress: 0);
        await artifacts.stage(
          board: Board.mdb,
          localPath: item.localPath!,
          onProgress: (sent, total) => _setStatus(
            l10n.artifactStaging,
            progress: total > 0 ? sent / total : 0,
          ),
        );

      }

      // The dashboard image and the map tiles upload in the background behind
      // the pairing screens, and they run after this artifact in the same
      // chain, so they are usually still transferring when the user finishes
      // enrolling cards. Rebooting underneath them kills the transfer and the
      // SSH session carrying it, which on any plan with tiles is not a race
      // that is sometimes lost but the ordinary case.
      if (_dbcStageInFlight) {
        _setStatus(l10n.waitingForDbcUpload);
        while (_dbcStageInFlight) {
          await Future.delayed(const Duration(seconds: 1));
          if (!mounted) return;
        }
      }

      // The reboot is ours: a rootfs that comes back and answers SSH has
      // proven itself, u-boot has already rolled back if it did not, and any
      // DBC work should run from the version the user asked for.
      _setStatus(l10n.waitingForMdbRestart);
      // The breadcrumb write is queued and the reboot below tears the session
      // down on purpose, so an unflushed write races a closing channel and the
      // record of where this run reached is the thing lost. It is also the
      // breadcrumb most worth having: it marks the moment before a reboot,
      // which is when a run is most likely to be interrupted.
      //
      // Bounded, because the write is queued rather than awaited so that a
      // slow one cannot stall the install, and draining it without a limit
      // would hand that back. A few hundred bytes over a local link needs far
      // less than this.
      try {
        await _installStateWriteQueue.timeout(const Duration(seconds: 3));
      } catch (e) {
        debugPrint('UI: install state write did not settle before reboot: $e');
      }
      // No reboot here any more, and so no verification against a running
      // version: the board stays on the bootstrap image until 80-reboot.sh,
      // and staying there is what lets the user leave at the cable swap.
      // mender-update exiting 0 is the verdict, checksum included.
      //
      // Nothing arms service mode either. That existed because the image on
      // the far side of this reboot runs vehicle-service, which takes usb0
      // down with the dashboard. The bootstrap image has no vehicle-service,
      // so the gate never closes while anything is talking to the board.
      _setPhase(_phaseAfterMdbInstall);
    } catch (e) {
      if (!mounted) return;
      // The panel is on screen and the log says nothing: an install that
      // stopped here left a silent gap between the last status line and
      // whatever the user did next, which is the one moment in a run that
      // most needs a line in the log we ask them to send.
      debugPrint('UI: MDB artifact install failed: $e');
      setState(() {
        _artifactError = e.toString();
        _isProcessing = false;
      });
    } finally {
      criticalOperation?.release();
    }
  }

  String _preflightMessage(
    AppLocalizations l10n,
    ArtifactPreflight preflight,
  ) => switch (preflight.problem) {
    ArtifactPreflightProblem.noMender => l10n.artifactPreflightNoMender,
    ArtifactPreflightProblem.notEnoughSpace => l10n.artifactPreflightNoSpace(
      preflight.freeMiB,
      preflight.neededMiB,
    ),
    ArtifactPreflightProblem.otaInProgress => l10n.artifactPreflightOtaBusy(
      preflight.otaStatus ?? '',
    ),
    null => '',
  };

  /// The one action that needs a download the plan did not queue. Offered
  /// only after a failure.
  Future<void> _fallBackToFullImage() async {
    final l10n = AppLocalizations.of(context)!;

    // An upgrade is the one action that keeps /data. The full image erases
    // it, so this button silently trades away the settings, keycards,
    // offline maps and trip history the upgrade route exists to preserve.
    // Say so before doing it. A clean install was going to wipe /data
    // anyway, so it gets no dialog.
    if (_plan?.mdb.action == BoardAction.upgrade) {
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.fallBackWipeTitle),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(child: Text(l10n.fallBackWipeBody)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.cancelButton),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.fallBackWipeConfirm),
            ),
          ],
        ),
      );
      // Cancelling leaves _artifactError set, so the user lands back on the
      // error panel with Retry still on offer.
      if (confirmed != true || !mounted) return;
    }

    // The shortcut that finds the board already in mass storage never passes
    // the plan screen, so there may be no plan to amend. Seed one from what
    // we know: without it _phaseAfterMdbFlash would not see the fullImage
    // action, route back into the artifact phase, and loop through the same
    // failure forever.
    final plan =
        _plan ??
        InstallPlan.defaults(
          mdb: _mdbState,
          dbc: _dbcState,
          targetVersion: _downloadState.releaseTag,
          installTiles: _downloadState.wantsOfflineMaps,
        );
    setState(() {
      _plan = plan.withMdb(plan.mdb.withAction(BoardAction.fullImage));
      _artifactError = null;
      _artifactStarted = false;
      _expectMinimalMdb = false;
      _isProcessing = true;
      // An upgrade marked these skipped on the way in; we are about to walk
      // through all of them after all.
      _skippedPhases.removeAll(MajorStep.mdbFlash.phases);
    });
    _setStatus(l10n.waitingForDownloads, progress: 0);
    try {
      // Only the MDB. Promoting the DBC too would swap its 54 MiB stage-0
      // image for a 424 MiB one over the slow link and then install the
      // artifact on top regardless, which is about an extra hour of work
      // nobody asked for.
      final items = await _downloadService.buildDownloadQueue(
        channel: _downloadState.channel,
        region: _downloadState.selectedRegion,
        wantsOfflineMaps: _downloadState.wantsOfflineMaps,
        fullImageBoards: const {Board.mdb},
      );
      if (!mounted) return;
      setState(() {
        _downloadState.requiredTypes = DownloadState.defaultRequiredTypes;
        _downloadState.items = items;
      });
      await _downloadService.downloadAll(
        _downloadState.items,
        onProgress: (item, bytes, total) {
          if (mounted) setState(() {});
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _artifactError = e.toString();
        _isProcessing = false;
      });
      return;
    }
    if (!mounted) return;
    setState(() => _isProcessing = false);
    _setPhase(InstallerPhase.mdbToUms);
  }

  Widget _buildCbbReconnect(AppLocalizations l10n) {
    // Auto-check CBB on enter: poll for up to 3 minutes
    if (!_cbbAutoCheckStarted && !_isProcessing) {
      _cbbAutoCheckStarted = true;
      Future.microtask(() async {
        if (mounted) setState(() => _isProcessing = true);

        // Nobody gets told to reconnect the CBB while the main pack is live.
        // That is the same ordering the disconnect step warns about, run
        // backwards, and the new flow walks straight into it: the pack is
        // deactivated before the UMS reboot, and vehicle-service switches it
        // back on when the full image comes up.
        if (_manualPowerCut && !_isDryRun) {
          _setStatus(l10n.turningMainBatteryOff);
          await _deactivateMainBattery();
        }
        if (mounted) setState(() => _mainPackOffForCbb = true);

        _setStatus(l10n.checkingCbb);
        final detected = await _pollForCbb(l10n);
        // Proceeding without the CBB is a decision the user can make while
        // this is still waiting, and it moves the phase on. The verdict is
        // stale in that case and would put _cbbDetected back to false.
        if (!mounted || _cbbPollAbandoned) return;
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
          // The pack goes back on before we leave: the dashboard flash wants
          // the vehicle whole, and vehicle-service is what the trampoline
          // drives the dashboard through.
          if (_manualPowerCut && !_isDryRun) {
            _setStatus(l10n.turningMainBatteryOn);
            try {
              await _sshService.reactivateMainBattery();
            } catch (e) {
              debugPrint(
                'Battery: could not reactivate the main pack (ok): $e',
              );
            }
          }
          if (mounted) {
            setState(() => _batteryDetected = bat);
            if (bat) _setPhase(_phaseAfterCbbReconnect);
          }
        }
      });
    }

    // Only the manual power cut unplugs the CBB, so only that route is told to
    // plug it back in. The battery step then carries whichever number is left.
    final showCbbStep = _manualPowerCut && _mainPackOffForCbb;

    final verifyCbb = PhaseAction(
      label: l10n.verifyCbbConnection,
      primary: true,
      onPressed: () async {
        setState(() => _isProcessing = true);
        _setStatus(l10n.checkingCbb);
        final detected = await _pollForCbb(l10n);
        if (!mounted || _cbbPollAbandoned) return;
        if (detected) {
          setState(() {
            _cbbDetected = true;
            _isProcessing = false;
          });
          _setStatus('');
        } else {
          _setStatus(l10n.cbbNotDetected);
          setState(() {
            _isProcessing = false;
            _cbbDetected = false;
          });
        }
      },
    );

    final verifyBattery = PhaseAction(
      label: l10n.verifyBatteryPresence,
      primary: true,
      onPressed: () async {
        setState(() => _isProcessing = true);
        _setStatus(l10n.checkingCbbAndBattery);
        final bat = _isDryRun ? true : await _sshService.isBatteryPresent();
        if (bat) {
          debugPrint('Battery: insert detected on battery:0 (manual verify)');
          await _sshService.logScooterStats('cbb-and-battery-reconnected');
          setState(() {
            _batteryDetected = true;
            _isProcessing = false;
          });
          await Future.delayed(const Duration(seconds: 1));
          if (mounted) _setPhase(_phaseAfterCbbReconnect);
        } else {
          _setStatus(l10n.cbbNotDetected);
          setState(() => _isProcessing = false);
        }
      },
    );

    // Going on without the CBB is still going on, so it keeps the company of
    // the check rather than sitting where an abort would.
    final proceedAnyway = PhaseAction(
      label: l10n.proceedWithoutCbb,
      danger: true,
      onPressed: _cbbDetected
          ? () => _setPhase(_phaseAfterCbbReconnect)
          : () => setState(() => _cbbDetected = true),
    );

    Widget detected(String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle, size: 16, color: kAccent),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(color: kAccent, fontSize: 13)),
      ],
    );

    return PhaseLayout(
      title: _manualPowerCut
          ? l10n.reconnectCbbHeading
          : l10n.checkingCbbAndBattery,
      actions: [
        if (!_isProcessing) ...[
          proceedAnyway,
          if (!_cbbDetected)
            verifyCbb
          else if (!_batteryDetected)
            verifyBattery,
        ],
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The check below runs either way: a CBB missing for some other
          // reason still matters before the dashboard flash.
          if (showCbbStep)
            InstructionStep(
              number: 1,
              title: l10n.reconnectCbbStep,
              description: l10n.reconnectCbbStepDesc,
              imageAsset: 'assets/images/lsi-unu_scooter_cbb_connected.jpg',
            ),
          if (_cbbDetected)
            detected(l10n.cbbDetected)
          else if (_cbbWaitNoticeShown)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
              child: Text(
                l10n.cbbDetectionMayTakeMinutes,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          const SizedBox(height: 16),
          // Nothing in this install takes the main pack out, so there is no
          // step to give here. The pack is only reported, and only spoken
          // about when it is missing, which does block the dashboard flash.
          if (_cbbDetected && _batteryDetected)
            detected(l10n.batteryDetected)
          else if (_cbbDetected)
            Container(
              width: 400,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.orangeAccent.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.battery_alert,
                    size: 28,
                    color: Colors.orangeAccent,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l10n.mainBatteryMissingHeading,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orangeAccent,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.mainBatteryMissingHint,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _sshService.isConnected
                        ? () async {
                            try {
                              await _sshService.runCommand('lsc open');
                            } catch (_) {}
                          }
                        : null,
                    icon: const Icon(Icons.lock_open, size: 18),
                    label: Text(l10n.openSeatboxButton),
                  ),
                ],
              ),
            ),
          if (_isProcessing) ...[
            const SizedBox(height: 20),
            const CircularProgressIndicator(),
            const SizedBox(height: 8),
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade400),
            ),
          ],
        ],
      ),
    );
  }

  bool _dbcPrepBlocked = false;

  Widget _buildDbcPrep(AppLocalizations l10n) {
    // The upload usually started while the user was pairing, so this phase
    // mostly displays work already in flight rather than kicking it off.
    final busy = _isProcessing || _dbcStageInFlight;
    // needsHandoff is true for tiles alone, so this step runs for a plan that
    // leaves the dashboard untouched. What it does then is copy maps, and a
    // screen titled for a firmware flash promises something else entirely.
    final mapsOnly = !(_plan?.needsDbcWork ?? true);
    if (!_dbcPrepStarted && !busy) {
      _dbcPrepStarted = true;
      Future.microtask(_uploadDbcFiles);
    }
    return PhaseLayout(
      title: mapsOnly ? l10n.preparingMapTransfer : l10n.preparingDbcFlash,
      subtitle: mapsOnly
          ? l10n.preparingMapTransferSubtitle
          : l10n.preparingDbcFlashSubtitle,
      actions: [
        if (_dbcUploadReady) ...[
          // The plan decided there was dashboard work, and nothing between
          // there and here re-examines it: the laptop occupies the MDB's only
          // OTG port, so the dashboard cannot be probed and its presence is
          // assumed the whole way. On a board that turns out not to have one,
          // starting the trampoline arms a run that fails an hour later with a
          // red LED, so leaving has to be an option here and not only after a
          // failure.
          PhaseAction(
            // Skipping a firmware write is an escape hatch and should read
            // like one. Skipping a map copy costs stale offline maps, which
            // is recoverable and repeatable, so it reads as an ordinary
            // choice.
            label: mapsOnly ? l10n.skipMapTransfer : l10n.skipToFinish,
            side: ActionSide.back,
            onPressed: busy ? null : () => _setPhase(InstallerPhase.finish),
          ),
          PhaseAction(
            label: mapsOnly ? l10n.dbcReadyButtonMaps : l10n.dbcReadyButton,
            icon: Icons.bolt,
            primary: true,
            onPressed: busy ? null : _startTrampoline,
          ),
        ]
        else if (!busy) ...[
          if (_dbcPrepBlocked)
            PhaseAction(
              label: l10n.skipToFinish,
              onPressed: () {
                setState(() => _dbcPrepBlocked = false);
                _setPhase(InstallerPhase.finish);
              },
            ),
          PhaseAction(
            label: l10n.retryDbcPrep,
            icon: Icons.refresh,
            primary: true,
            onPressed: () {
              _restartFailedDownloads();
              setState(() {
                _dbcPrepStarted = false;
                _dbcStageInFlight = false;
                _dbcPrepBlocked = false;
                _dbcPrepSubsteps = const [];
              });
              Future.microtask(() {
                setState(() => _dbcPrepStarted = true);
                _uploadDbcFiles();
              });
            },
          ),
        ],
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // A long stage with a progress bar and nothing else looks like the
          // installer talking to itself. What it is doing, and why the DBC is
          // not on the other end of the cable, belongs on the screen.
          Text(
            mapsOnly
                ? l10n.preparingMapTransferExplainer
                : l10n.preparingDbcFlashExplainer,
            style: TextStyle(
                fontSize: 14, height: 1.5, color: Colors.grey.shade300),
          ),
          const SizedBox(height: 20),
          LinearProgressIndicator(value: _progress, minHeight: 6),
          const SizedBox(height: 16),
          if (_dbcPrepSubsteps.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade800),
              ),
              child: SubstepList(substeps: _dbcPrepSubsteps),
            )
          else
            Text(
              _statusMessage,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }

  /// [background] when this runs behind another phase's screen: its progress
  /// then belongs on the overlay's second line, not in the status the phase
  /// is reporting for itself.
  Future<void> _uploadDbcFiles({bool background = false}) async {
    final l10n = AppLocalizations.of(context)!;
    if (!_dbcStageInFlight) setState(() => _isProcessing = true);
    final criticalOperation = _acquireCriticalOperation();

    setState(() {
      _dbcUploadReady = false;
      _dbcPrepBlocked = false;
    });

    if (_isDryRun) {
      _setStatus('[DRY RUN] Simulating DBC upload...');
      await Future.delayed(const Duration(seconds: 1));
      criticalOperation.release();
      setState(() {
        _isProcessing = false;
        _dbcStageInFlight = false;
        _dbcUploadReady = true;
      });
      return;
    }

    try {
      if (!_downloadState.allReady) {
        _setStatus(l10n.waitingForDownloads);
        await waitForDownloads(
          isReady: () => _downloadState.allReady,
          currentError: () => _downloadState.error,
          isCancelled: () => !mounted,
        );
      }

      final trampolineService = TrampolineService(_sshService);
      final dbcImage = _downloadState.imageFor(Board.dbc);
      final dbcArtifact = _downloadState.artifactFor(Board.dbc);
      final osmItem = _downloadState.itemOfType(DownloadItemType.osmTiles);
      final valhallaItem = _downloadState.itemOfType(
        DownloadItemType.valhallaTiles,
      );
      final installTiles =
          _plan?.installTiles ?? _downloadState.wantsOfflineMaps;

      final dbcBmapItem = _downloadState.itemOfType(DownloadItemType.dbcBmap);

      // No plan means the shortcut that found the board already in mass
      // storage: it never passes the plan screen and writes a stage-0 image,
      // so the DBC gets what a clean install gets, image then artifact.
      final needsDbcStage0 = _plan?.needsDbcStage0 ?? true;
      // A full sdimg already carries its firmware, so that one action wants
      // no artifact on top. Upgrade and clean install both do.
      final dbcAction = _plan?.dbc.action;
      final needsDbcArtifact =
          dbcAction == null ||
          dbcAction == BoardAction.upgrade ||
          dbcAction == BoardAction.cleanInstall;

      // uploadAll reads the mode off the stage-0 image: an image means flash,
      // no image means upgrade. Passing one for an upgrade would silently
      // turn a job that keeps /data into a full re-flash, so the path goes in
      // only when the plan asked for stage 0.
      final dbcImagePath = needsDbcStage0 ? dbcImage?.localPath : null;
      final dbcArtifactPath = needsDbcArtifact ? dbcArtifact?.localPath : null;

      // A file the plan needs and the queue never produced would otherwise
      // decide the mode by accident: a missing image reads as "upgrade", and
      // a missing artifact as "tiles only". Both would report success having
      // left the board alone.
      final missing = needsDbcStage0 && dbcImagePath == null
          ? l10n.dbcImageMissing
          : needsDbcArtifact && dbcArtifactPath == null
          ? l10n.artifactNoneDownloaded
          : null;
      if (missing != null) {
        criticalOperation.release();
        _setStatus(missing);
        // Retry re-runs the same check against the same queue, so on its own
        // it is a loop. The main board is already done by this point, so
        // finishing without the dashboard is a real outcome rather than a
        // failure, and the finish screen offers redoing the rest.
        setState(() {
          _isProcessing = false;
          _dbcStageInFlight = false;
          _dbcPrepBlocked = true;
        });
        return;
      }

      await trampolineService.uploadAll(
        runId: _installRunId,
        releaseTag: _downloadState.releaseTag ?? '',
        dbcImageLocalPath: dbcImagePath,
        dbcBmapLocalPath: needsDbcStage0 ? dbcBmapItem?.localPath : null,
        dbcArtifactLocalPath: dbcArtifactPath,
        // What the trampoline checks the DBC against after its reboot: the
        // installer cannot see that board, so this is the only thing
        // standing between a rolled-back install and a success report.
        dbcTargetVersion: dbcArtifact == null
            ? null
            : _downloadState.releaseTag ??
                  _versionFromArtifactFilename(dbcArtifact.filename),
        osmTilesLocalPath: installTiles ? osmItem?.localPath : null,
        valhallaTilesLocalPath: installTiles ? valhallaItem?.localPath : null,
        region: installTiles ? _downloadState.selectedRegion : null,
        mdbArtifactPath: _stagedMdbArtifactPath(),
        finish: _buildDeviceFinish(),
        messages: _buildDashboardMessages(),
        onProgress: (status, progress) {
          if (background) {
            _setBackgroundStatus(status, progress: progress);
          } else {
            _setStatus(status, progress: progress);
          }
        },
        onSubsteps: (steps) {
          if (mounted) setState(() => _dbcPrepSubsteps = steps);
        },
        labels: SubstepLabels(
          checkExisting: l10n.substepCheckExisting,
          uploadFlasher: l10n.substepUploadFlasher,
          uploadFwTools: l10n.substepUploadFwTools,
          uploadScript: l10n.substepUploadScript,
          uploadFile: l10n.substepUploadFile,
          verifying: l10n.substepVerifying,
          imageName: l10n.substepFileImage,
          imageMapName: l10n.substepFileImageMap,
          firmwareName: l10n.substepFileFirmware,
          mapsName: l10n.substepFileMaps,
          routingName: l10n.substepFileRouting,
          alreadyThere: l10n.substepAlreadyThere,
          starting: l10n.substepUploadStarting,
          complete: l10n.substepUploadComplete,
          nothingToDo: l10n.substepUploadNothingToDo,
          remaining: l10n.substepRemaining,
        ),
      );

      // Upload is done, but DON'T start the trampoline yet. The trampoline's
      // first act is to wait for the laptop to disconnect, after which the
      // install runs autonomously and we lose SSH. Stay on this page and
      // surface the "Ready to flash DBC" button instead, so the user
      // explicitly confirms before that point of no return. The cable-swap
      // instructions only appear on the next screen, after the trampoline
      // has started, so nobody can swap the cable before start() runs.
      criticalOperation.release();
      setState(() {
        _isProcessing = false;
        _dbcStageInFlight = false;
        _dbcUploadReady = true;
      });
    } on DownloadWaitCancelled {
      return;
    } catch (e) {
      criticalOperation.release();
      _setStatus(l10n.uploadError(e.toString()));
      debugPrint('DBC prep error: $e');
      setState(() {
        _isProcessing = false;
        _dbcStageInFlight = false;
      });
      // Don't reset _dbcPrepStarted: retry button handles that
    } finally {
      criticalOperation.release();
    }
  }

  /// Confirm handler for the "Ready to flash DBC" button on the prep page:
  /// fire the trampoline (the last thing we do over SSH) and hand off to the
  /// swap-cables screen, which is the first place the user is told to touch
  /// the cable.
  Future<void> _startTrampoline() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isProcessing = true;
      _dbcUploadReady = false;
    });
    final criticalOperation = _acquireCriticalOperation();

    if (_isDryRun) {
      _setStatus('[DRY RUN] Simulating trampoline start...');
      await Future.delayed(const Duration(seconds: 1));
      criticalOperation.release();
      setState(() => _isProcessing = false);
      _setPhase(InstallerPhase.dbcFlash);
      return;
    }

    try {
      _setStatus(l10n.startingTrampoline);
      await _installStateWriteQueue;
      await _armInstallPhases();
      await TrampolineService(_sshService).start(runId: _installRunId);
      _deviceFinishArmed = true;
      criticalOperation.release();
      setState(() => _isProcessing = false);
      await Future.delayed(const Duration(seconds: 1));
      _setPhase(InstallerPhase.dbcFlash);
    } catch (e) {
      criticalOperation.release();
      _setStatus(l10n.uploadError(e.toString()));
      debugPrint('Trampoline start error: $e');
      // The upload is still intact; re-offer the begin button instead of
      // demoting the user to a full prep retry over a transient SSH error.
      setState(() {
        _isProcessing = false;
        _dbcUploadReady = true;
      });
    } finally {
      criticalOperation.release();
    }
  }

  bool _dbcFlashWatchStarted = false;
  bool _dbcUsbDisconnected = false;
  List<Substep> _dbcPrepSubsteps = const [];
  List<Substep> _reconnectSubsteps = const [];
  DateTime? _reconnectRndisWaitStart;
  DateTime? _reconnectStatusWaitStart;

  /// How long the reconnect phase waits for a verdict before saying it does
  /// not have one. The slowest thing on the far side is a dashboard first
  /// boot resizing its filesystem, which is minutes, not tens of them.
  static const _reconnectStatusCeiling = Duration(minutes: 15);

  bool _reconnectShowDiagnostics = false;
  String? _reconnectDiagnostics;

  Widget _buildDbcFlash(AppLocalizations l10n) {
    // Start watching for USB disconnect and MDB reconnect
    if (!_dbcFlashWatchStarted) {
      _dbcFlashWatchStarted = true;
      _watchDbcFlash();
    }

    if (!_dbcUsbDisconnected) {
      // Step 1: waiting for user to swap cables. The trampoline is already
      // running and waiting for the laptop to disconnect, so this is the
      // first place we tell the user to touch the cable.
      return PhaseLayout(
        title: l10n.dbcFlashSwapCablesTitle,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The scooter is already counting. It waits a few minutes for
            // the dashboard to answer on the cable the user is about to
            // plug in, and then gives up: worth saying, because the screen
            // otherwise reads as untimed and the plug is a screw-lock
            // mini-B in a footwell.
            Text(
              l10n.dbcFlashSwapCablesDeadline,
              style: TextStyle(fontSize: 13, color: Colors.orange.shade200),
              textAlign: TextAlign.center,
            ),
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
                      child: Image.asset(
                        'assets/images/lsi-mdb_usb_laptop.jpg',
                        fit: BoxFit.cover,
                      ),
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
                      child: Image.asset(
                        'assets/images/lsi-mdb_usb_dbc.jpg',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // No numbered steps under the photos: they repeated what the
            // photos already show, and the pair is captioned Laptop and DBC
            // with an arrow between them.
            const SizedBox(height: 16),
            Text(
              l10n.waitingForUsbDisconnect,
              style: TextStyle(color: Colors.grey.shade400),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Center(child: CircularProgressIndicator()),
          ],
        ),
      );
    }

    // Step 2: USB disconnected: MDB is flashing autonomously.
    //
    // Once the cable is unplugged we have NO link to the MDB until it
    // comes back as RNDIS. So this screen is purely informational:
    // it tells the user what's happening on the scooter lights and
    // gives them a "I see X" button to advance when the boot LED
    // settles on green or red.
    return PhaseLayout(
      title: l10n.dbcFlashInProgress,
      subtitle: l10n.dbcFlashDurationHeadline,
      actions: [
        // Both lead onwards: one to the last step, one to the diagnosis. The
        // failing branch is still the way out of this screen, so it sits with
        // the other rather than where an abort would.
        PhaseAction(
          label: l10n.dbcFlashSomethingWrong,
          danger: true,
          onPressed: () {
            _dbcFlashSimulateError = true;
            _setPhase(InstallerPhase.reconnect);
          },
        ),
        PhaseAction(
          label: l10n.dbcFlashAllDone,
          icon: Icons.arrow_forward,
          primary: true,
          onPressed: () {
            _dbcFlashSimulateError = false;
            _setPhase(InstallerPhase.finish);
          },
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // One instruction, then the two things that can end it. The LED
          // legend and the blinker diagram that used to sit here said the
          // same things a third time, and the dashboard now shows its own
          // progress, so the only thing left worth saying is what to wait
          // for and what each outcome looks like.
          Text(
            l10n.dbcFlashSequence,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade300,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),

          // A key for reading the scooter, not a status display: the
          // laptop is unplugged and knows nothing about the blinkers. It
          // stays because the blinkers are the one progress indicator still
          // visible while the dashboard reboots and its own screen is dark,
          // and the user needs to know what the four of them mean.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade800),
            ),
            child: _blinkerPhases(l10n),
          ),
          const SizedBox(height: 18),
          // Once the laptop is unplugged the dashboard LED is the only
          // thing that can report a failure, so name it above the outcomes
          // instead of leaving it buried in one of them.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.lightbulb_outline,
                size: 20,
                color: Colors.grey.shade400,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.dbcFlashLedIsTheSignal,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade300,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _outcomeRow(
            icon: Icons.lock_open,
            colour: Colors.greenAccent,
            text: l10n.dbcFlashDoneSignal,
          ),
          const SizedBox(height: 12),
          _outcomeRow(
            icon: Icons.warning_amber_rounded,
            colour: Colors.redAccent,
            text: l10n.dbcFlashFailSignal,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Icon(Icons.power_off, size: 18, color: Colors.orange.shade300),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.dbcFlashDoNotDisconnect,
                  style: TextStyle(fontSize: 13, color: Colors.orange.shade200),
                ),
              ),
            ],
          ),
        ],
      ),
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
    while (mounted &&
        _device == null &&
        DateTime.now().isBefore(presentDeadline)) {
      await Future.delayed(const Duration(milliseconds: 500));
    }
    while (mounted && _device != null) {
      await Future.delayed(const Duration(seconds: 1));
    }
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _dbcUsbDisconnected = true);
    _setStatus(l10n.mdbDisconnectedFlashingDbc);

    // Poll for MDB reconnect every 10s: only while still on dbcFlash phase
    while (mounted && _currentPhase == InstallerPhase.dbcFlash) {
      await Future.delayed(const Duration(seconds: 10));
      if (_currentPhase != InstallerPhase.dbcFlash) return;
      if (_device != null && _device!.mode == DeviceMode.ethernet) {
        _setStatus(l10n.mdbReconnectedVerifying);
        await Future.delayed(const Duration(seconds: 2));
        if (mounted && _currentPhase == InstallerPhase.dbcFlash) {
          _setPhase(InstallerPhase.reconnect);
        }
        return;
      }
    }
  }

  /// One of the two ways the install can end, stated the way the user will
  /// see it happen rather than as an LED colour to decode.
  Widget _outcomeRow({
    required IconData icon,
    required Color colour,
    required String text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: colour),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 14, color: colour, height: 1.4),
          ),
        ),
      ],
    );
  }

  // The four turn-signal LEDs fill in sequence (FL -> FR -> BR -> BL), one per
  // trampoline phase. Label each position with the step it represents so the
  // user can read progress off the scooter itself.
  Widget _blinkerPhases(AppLocalizations l10n) {
    Widget phase(int n, String pos, String step) {
      return Padding(
        padding: const EdgeInsets.only(left: 24, bottom: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 14,
              child: Text(
                '$n',
                style: const TextStyle(
                  fontSize: 12,
                  color: kAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: Text(
                pos,
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: Text(step, style: const TextStyle(fontSize: 12.5)),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(width: 8),
                const Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: Icon(Icons.circle, size: 8, color: kAccent),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.ledBlinkerProgress,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          phase(1, l10n.blinkerPosFL, l10n.blinkerStepPrep),
          phase(2, l10n.blinkerPosFR, l10n.blinkerStepFlash),
          phase(3, l10n.blinkerPosBR, l10n.blinkerStepRestart),
          phase(4, l10n.blinkerPosBL, l10n.blinkerStepMaps),
        ],
      ),
    );
  }

  Widget _buildReconnect(AppLocalizations l10n) {
    if (!_reconnectStarted && !_isProcessing) {
      _reconnectStarted = true;
      Future.microtask(_verifyDbcFlash);
    }
    return PhaseLayout(
      title: l10n.verifyingDbcInstallation,
      actions: [
        // Hidden while a run is going normally, so nobody interrupts a working
        // reconnect. Once the diagnostic panel is up the wait has already
        // failed to explain itself, and the comment further down promising the
        // user can keep waiting, retry or skip has to become true.
        if (!_isProcessing || _reconnectShowDiagnostics) ...[
          // Redoing the dashboard install means going back through the prep
          // phase, so it belongs on the leaving side; the checks and the way
          // out of this screen stay on the right.
          PhaseAction(
            label: l10n.retryDbcFlash,
            icon: Icons.replay,
            side: ActionSide.back,
            onPressed: () => _returnToDbcPrep(),
          ),
          // The DBC's version is a last-seen guess, so a plan that said
          // Upgrade can meet a board with no mender layout. Retrying the
          // flash renders the same upgrade-mode trampoline and fails the same
          // way; the way out is stage 0, which the queue already holds.
          // Offered only where it is a change: a plan that already says clean
          // install has nothing to switch to.
          if (_plan?.dbc.action == BoardAction.upgrade)
            PhaseAction(
              label: l10n.dbcCleanInstallButton,
              icon: Icons.restart_alt,
              side: ActionSide.back,
              onPressed: () => _cleanInstallDbcAfterFailure(l10n),
            ),
          PhaseAction(
            label: l10n.skipToFinish,
            onPressed: () => _setPhase(InstallerPhase.finish),
          ),
          PhaseAction(
            label: l10n.retryVerification,
            icon: Icons.refresh,
            primary: true,
            onPressed: () {
              setState(() {
                _reconnectStarted = true;
                _reconnectShowDiagnostics = false;
                _reconnectDiagnostics = null;
              });
              Future.microtask(_verifyDbcFlash);
            },
          ),
        ],
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                _statusMessage.isEmpty
                    ? l10n.reconnectUsbToLaptop
                    : _statusMessage,
                style: TextStyle(color: Colors.grey.shade400),
                textAlign: TextAlign.center,
              ),
            ),
          if (_reconnectShowDiagnostics) ...[
            const SizedBox(height: 16),
            _buildReconnectDiagnosticsPanel(l10n),
          ],
        ],
      ),
    );
  }

  /// Major steps the sidebar should title "Upgrade" rather than "Flash".
  /// Nothing before the plan screen is an upgrade, so an empty set until
  /// then is the right answer.
  ///
  /// The MDB's step is mdbInstall, not mdbFlash: mdbFlash prepares the board
  /// for a raw write and is the step an upgrade skips, so it keeps its own
  /// name. mdbInstall is where the upgrade happens.
  /// needsHandoff is true for tiles by themselves, so the dashboard block runs
  /// for a plan that leaves the dashboard untouched. What it does then is copy
  /// maps, and every label on it otherwise says flash.
  bool get _dbcMapsOnly =>
      !(_plan?.needsDbcWork ?? true) && (_plan?.installTiles ?? false);

  Set<MajorStep> get _upgradingSteps => {
    if (_plan?.mdb.action == BoardAction.upgrade) MajorStep.mdbInstall,
    if (_plan?.dbc.action == BoardAction.upgrade) MajorStep.dbcFlash,
  };

  /// Go back to the prep phase and re-stage everything for another
  /// trampoline run, whatever the plan now says.
  void _returnToDbcPrep() {
    setState(() {
      _dbcPrepStarted = false;
      _dbcPrepBlocked = false;
      _dbcUploadReady = false;
      _reconnectStarted = false;
      _reconnectShowDiagnostics = false;
      _reconnectDiagnostics = null;
      _reconnectSubsteps = const [];
    });
    _setPhase(InstallerPhase.dbcPrep);
  }

  /// Switch the DBC to a clean install after the upgrade route failed on it,
  /// then go round again. Costs a second cable swap and the stage-0 write;
  /// the minimal image is already in the queue, so nothing is downloaded.
  Future<void> _cleanInstallDbcAfterFailure(AppLocalizations l10n) async {
    final plan = _plan;
    if (plan == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.dbcCleanInstallTitle),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(child: Text(l10n.dbcCleanInstallBody)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancelButton),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.dbcCleanInstallConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(
      () => _plan = plan.withDbc(plan.dbc.withAction(BoardAction.cleanInstall)),
    );
    _returnToDbcPrep();
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
              Icon(
                Icons.warning_amber,
                color: Colors.orange.shade300,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.reconnectTimeoutHeading,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade100,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l10n.reconnectTimeoutBody(waitedSecs ~/ 60),
            style: TextStyle(color: Colors.orange.shade100, fontSize: 13),
          ),
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
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
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
    // reset() bumps the generation, so starting a second run sends any run
    // already in flight home at its next guard.
    _reconnectAttempt.reset();
    final generation = _reconnectAttempt.begin();
    if (generation == null) return;
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
            if (i == idx)
              _reconnectSubsteps[i].copyWith(state: state, detail: detail)
            else
              _reconnectSubsteps[i],
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
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(l10n.closeButton),
                ),
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
    final rndisOk = await _waitForRndisWithTimeout(l10n, setStep, generation);
    _reconnectRndisWaitStart = null;
    if (!rndisOk) return;
    if (!_ownsReconnect(generation)) return;
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
    // Same re-enumeration risk as the post-reboot reconnect above.
    await _ensureDriverBinding();
    final iface = await NetworkService().findLibrescootInterface();
    if (!_ownsReconnect(generation)) return;
    if (iface != null) {
      try {
        await NetworkService().configureInterface(iface);
      } on NetworkPrivilegeException catch (e) {
        setStep('net', SubstepState.failed, detail: e.toString());
        _setStatus(l10n.errorPrefix(e.toString()));
        setState(() {
          _isProcessing = false;
          _reconnectStarted = false;
        });
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
      setState(() {
        _isProcessing = false;
        _reconnectStarted = false;
      });
      return;
    }
    if (!_ownsReconnect(generation)) return;
    setStep('ssh', SubstepState.done);

    setStep('hazards', SubstepState.active);
    // The dashboard flash rebooted the main board, which brings the shipped
    // settings back (alarm.enabled=true, auto-standby=900s). With the scooter
    // locked and stood up on a lift, alarm-service arms and trips on any
    // vibration, and auto-standby drops the link we just spent minutes
    // waiting for. Park both again for whatever is left of the run.
    await _disableInstallerHazards(label: 'reconnect');
    if (!_ownsReconnect(generation)) return;
    setStep('hazards', SubstepState.done);

    setStep('status', SubstepState.active);
    // Poll for trampoline status. A slow DBC first-boot (resize2fs on a
    // fresh filesystem) can take 5–10 minutes. Give it 5 minutes of quiet
    // polling, then surface the diagnostic panel — user can keep waiting,
    // retry, or skip. The user can also bail by yanking USB and re-plugging;
    // _watchDbcFlash picks that up and puts them back on the prep screen.
    _setStatus(l10n.readingTrampolineStatus);
    _reconnectStatusWaitStart = DateTime.now();
    TrampolineStatus status;
    final pollStart = DateTime.now();
    while (true) {
      status = await _sshService.readTrampolineStatus(
        expectedRunId: _installRunId,
      );
      // `running` is as much a reason to keep polling as an absent file: the
      // trampoline writes it before the reboot that starts the dashboard
      // work, so it means "not finished", not "finished well".
      if (status.result != TrampolineResult.unknown &&
          status.result != TrampolineResult.running) {
        break;
      }
      final elapsed = DateTime.now().difference(pollStart).inSeconds;
      debugPrint(
        'Trampoline: status still unknown after ${elapsed}s, waiting...',
      );
      _setStatus(l10n.readingTrampolineStatusElapsed(elapsed));
      setStep(
        'status',
        SubstepState.active,
        detail: l10n.readingTrampolineStatusElapsed(elapsed),
      );
      if (elapsed >= 300 && !_reconnectShowDiagnostics) {
        await _surfaceReconnectDiagnostics(l10n);
      }
      // A ceiling, because a poll with no end is worse than a wrong verdict:
      // it tells the user nothing, offers nothing, and cannot be distinguished
      // from a device still working. Anything the trampoline could still be
      // doing fits inside this, so past it the answer is that we do not know,
      // and the unknown branch below says so and hands the decision over.
      if (elapsed >= _reconnectStatusCeiling.inSeconds) {
        debugPrint('Trampoline: giving up on the status after ${elapsed}s');
        status = TrampolineStatus(result: TrampolineResult.unknown);
        break;
      }
      await Future.delayed(const Duration(seconds: 5));
      if (!_ownsReconnect(generation)) return;
    }
    if (!_ownsReconnect(generation)) return;
    _reconnectStatusWaitStart = null;
    setStep('status', SubstepState.done);

    // librescoot-keycard is deliberately left alone here. This used to stop
    // it, because keycard setup came after the dashboard flash and a stray
    // tap before it could silently teach in a master card. Setup now runs
    // two phases earlier, so by the time anyone reaches this screen a master
    // exists and the running service is the one the finish screen's own
    // "unlock with a keycard you registered" step depends on.

    if (status.result == TrampolineResult.success) {
      // The green success-blink onboot.sh started means "safe to swap the
      // MDB's USB port back to the laptop". We only get here because the
      // laptop is already back on USB (that's how we read the status), so
      // the cue has done its job — stop it now instead of letting it run
      // decoratively through pairing + keycard setup.
      await _stopBootLedBlink();
      if (!_ownsReconnect(generation)) return;
      // Say which version actually landed when the trampoline reported one.
      // It is absent on a tiles-only job and on any status file written
      // before the field existed, so the bare verdict stays the fallback.
      final landedVersion = status.dbcVersion;
      _setStatus(
        landedVersion == null
            ? l10n.dbcFlashSuccessful
            : l10n.dbcInstallSuccessfulVersion(landedVersion),
      );
      await Future.delayed(const Duration(seconds: 2));
      if (!_ownsReconnect(generation)) return;
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
      // Into our own log before the dialog, because the dialog is the only
      // copy the user gets and it dies when they close it. A field report
      // that carries the verdict without the evidence behind it cannot
      // distinguish a dashboard that was pingable-but-not-ready from one that
      // was never on the bus, which are different bugs with different fixes.
      await _captureTrampolineEvidence(status.errorLog);
      if (mounted && status.errorLog != null) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.dbcFlashError),
            content: SingleChildScrollView(
              child: SelectableText(
                status.errorLog!,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.closeButton),
              ),
            ],
          ),
        );
      }
      setState(() => _isProcessing = false);
    } else {
      _setStatus(l10n.trampolineStatusUnknown);
      // The unknown branch used to log nothing at all, which is the worst
      // case to be told nothing about: we have a status file we could not
      // make sense of, and the file itself is the only thing that explains why.
      await _captureTrampolineEvidence(status.message);
      setState(() => _isProcessing = false);
    }
  }

  /// Put the trampoline's own account of a failure into the installer log,
  /// and fetch the journal alongside it. The status file carries the step
  /// markers and the lsusb dump; the journal carries what systemd saw, which
  /// is the half that explains a script that died rather than failed.
  Future<void> _captureTrampolineEvidence(String? errorLog) async {
    if (errorLog != null && errorLog.trim().isNotEmpty) {
      appendLogRaw('--- trampoline status file ---');
      appendLogRaw(errorLog.trimRight());
      appendLogRaw('--- end trampoline status file ---');
    }
    if (_isDryRun || !_sshService.isConnected) return;
    try {
      final journal = await _sshService
          .runCommand(
            'tail -n 200 /data/installer/trampoline-journal.log 2>/dev/null; true',
          )
          .timeout(const Duration(seconds: 20));
      if (journal.trim().isNotEmpty) {
        appendLogRaw('--- trampoline journal (last 200 lines) ---');
        appendLogRaw(journal.trimRight());
        appendLogRaw('--- end trampoline journal ---');
      }
    } catch (e) {
      debugPrint('UI: could not fetch the trampoline journal (ok): $e');
    }
  }

  /// What the nRF advertises itself as, which is what a phone's Bluetooth
  /// list shows. Nothing publishes it at runtime (the `ble` hash carries the
  /// address, the link state and the firmware status, but no name), so it is
  /// written here and checked against the hardware.
  static const _advertisedBleName = 'unu Scooter';

  Widget _buildBluetoothPairing(AppLocalizations l10n) {
    // Poll from the moment the panel opens, not from Start: the state that
    // matters most (someone already holds the link) is true before the user
    // touches anything.
    if (!_blePinPolling.isRunning) _startBlePinPolling();

    final (String state, Color colour) = switch ((
      _btPairingActive,
      _bleConnected,
      _blePairedCount > 0,
    )) {
      (_, true, true) => (l10n.blePairedHeading, Colors.green),
      (_, true, false) => (l10n.bleLinkHeldHeading, Colors.orangeAccent),
      (true, false, _) => (l10n.blePairingStateVisible, Colors.blueAccent),
      (false, false, _) => (l10n.blePairingStateIdle, Colors.grey),
    };

    Widget field(String label, String value) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            const SizedBox(height: 4),
            SelectableText(value,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace')),
          ],
        );

    // Steps on the left, what the scooter is doing on the right. The state
    // moves while the steps stay put, and the PIN is not here: it gets the
    // whole screen when it arrives, and saying it twice was confusing.
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l10n.blePairingWhy,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade300)),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  InstructionStep(
                    number: 1,
                    title: l10n.blePairingStep1,
                    description: l10n.blePairingStep1Desc,
                  ),
                  InstructionStep(
                    number: 2,
                    title: l10n.blePairingStep2,
                    description: l10n.blePairingStep2DescCompare,
                  ),
                  InstructionStep(
                    number: 3,
                    title: l10n.blePairingStep3,
                    description: l10n.blePairingStep3DescOverlay,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: colour.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colour.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle, color: colour),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(state,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: colour,
                                  fontSize: 14)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    field(l10n.blePairingDeviceName, _advertisedBleName),
                    const SizedBox(height: 14),
                    if (_bleMac != null) field(l10n.bleMacLabel, _bleMac!),
                    if (_btAdvertisingSettling) ...[
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(l10n.blePreparingRadio,
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey.shade400)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.link_off, size: 15, color: Colors.grey.shade500),
            const SizedBox(width: 8),
            Expanded(
              child: Text(l10n.blePairingOneAtATime,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ),
          ],
        ),
      ],
    );

    final screen = PhaseLayout(
      title: l10n.bluetoothPairingHeading,
      subtitle: l10n.bluetoothPairingHint,
      actions: [
        // Both choices carry on: one pairs a phone first, the other does not.
        // The window is open or it is not, so each state gets one way to end
        // it rather than a Start that turns into a Start over.
        if (!_btPairingActive) ...[
          PhaseAction(
            label: l10n.skipPairing,
            onPressed: () => _setPhase(InstallerPhase.keycardSetup),
          ),
          PhaseAction(
            label: l10n.startPairing,
            icon: Icons.bluetooth_searching,
            primary: true,
            onPressed: _startBluetoothPairing,
          ),
        ] else
          PhaseAction(
            label: l10n.pairingDone,
            icon: Icons.check,
            primary: true,
            onPressed: _stopBluetoothPairing,
          ),
      ],
      child: body,
    );

    final pin = _blePinCode;
    if (pin == null || pin.isEmpty) return screen;

    // The one moment in the flow that wants the whole screen: the phone is
    // asking, and the number has to be compared and confirmed there.
    return WaitScaffold(
      backdrop: screen,
      overlay: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        padding: const EdgeInsets.fromLTRB(28, 26, 28, 22),
        decoration: BoxDecoration(
          color: kBgSidebar,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.blePinConfirmTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: kAccent)),
            const SizedBox(height: 20),
            SelectableText(pin,
                style: const TextStyle(
                    fontSize: 46,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 10,
                    fontFamily: 'monospace')),
            const SizedBox(height: 18),
            Text(l10n.blePinConfirmHint,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
          ],
        ),
      ),
    );
  }

  /// How long the nRF52 needs after an advertising restart before a pairing
  /// attempt takes. The command restarts the radio; an attempt made into that
  /// window fails, and the user is left retrying a pair that cannot work.
  static const _bleAdvertisingSettle = Duration(seconds: 15);

  /// Vehicle state as it stood before the pairing window forced `parked`,
  /// restored when the window closes.
  String? _stateBeforePairing;
  bool _pairingVehicleStateChanged = false;
  bool _bleWhitelistDisabled = false;

  Future<void> _startBluetoothPairing() async {
    try {
      // The nRF grants a re-pairing request only while the vehicle reads
      // parked; in stand-by it leaves the request unanswered and the peer
      // manager refuses. The install runs with the scooter locked, so the
      // window is opened here and closed again in _stopBluetoothPairing.
      if (!_isDryRun && !_pairingVehicleStateChanged) {
        try {
          _stateBeforePairing = await _sshService.getVehicleState();
          if (_stateBeforePairing != 'parked') {
            await _sshService.forceVehicleState('parked');
            _pairingVehicleStateChanged = true;
            debugPrint(
              'UI: vehicle state -> parked for the pairing window '
              '(was $_stateBeforePairing)',
            );
          }
        } catch (e) {
          debugPrint('UI: could not open the pairing state gate (ok): $e');
        }
      }
      // Pairing normally needs the vehicle unlocked, and this used to unlock
      // it for exactly that reason. It cannot any more: the phase now runs
      // ahead of the trampoline, so a pairing window the user walks away from
      // would leave the vehicle unlocked for the whole autonomous run. The
      // no-whitelisting restart overrides the unlock gate instead, so a locked
      // scooter pairs and its state is never touched.
      await _sshService.redisLpush(
        'scooter:bluetooth',
        'advertising-restart-no-whitelisting',
      );
      _bleWhitelistDisabled = true;
      debugPrint('UI: BLE advertising restarted without whitelisting');
      _startBleAdvRearm();
      setState(() {
        // Edges only count from here, so a link that was already up reads as
        // held rather than as a pairing this window produced.
        _blePairedCount = 0;
        _btPairingActive = true;
        _btAdvertisingSettling = true;
        _blePinCode = null;
      });
      _startBlePinPolling();
      await Future.delayed(_bleAdvertisingSettle);
      if (mounted) setState(() => _btAdvertisingSettling = false);
    } catch (e) {
      debugPrint('UI: failed to restart BLE advertising: $e');
      _setStatus('Failed to start pairing: $e');
    }
  }

  /// Keep re-issuing the no-whitelisting restart while the pairing panel is
  /// open. Harmless to repeat: the firmware ignores it outright once something
  /// is connected, which is exactly when we no longer need it.
  void _startBleAdvRearm() {
    _bleAdvRearming.start(
      interval: const Duration(seconds: 30),
      poll: (generation) async {
        if (!generation.isCurrent || !mounted || !_btPairingActive) return;
        try {
          await _sshService.redisLpush(
            'scooter:bluetooth',
            'advertising-restart-no-whitelisting',
            timeout: const Duration(seconds: 2),
          );
          if (!generation.isCurrent) return;
          debugPrint('UI: re-armed the BLE pairing window');
        } catch (e) {
          debugPrint('UI: failed to re-arm the BLE pairing window (ok): $e');
        }
      },
    );
  }

  void _startBlePinPolling() {
    _blePinPolling.start(
      interval: const Duration(seconds: 1),
      poll: (generation) async {
        if (!generation.isCurrent ||
            !mounted ||
            _currentPhase != InstallerPhase.bluetoothPairing) {
          return;
        }
        try {
          // bluetooth-service writes `status` (connected/disconnected) from
          // the nRF's own link state.
          final output = await _sshService.runCommand(
            'redis-cli --raw HMGET ble status pin-code',
            timeout: const Duration(seconds: 2),
            replayOnDisconnect: true,
          );
          if (!generation.isCurrent ||
              !mounted ||
              _currentPhase != InstallerPhase.bluetoothPairing) {
            return;
          }
          final values = output.split('\n');
          final status = values.isEmpty ? null : values[0].trim();
          final rawPin = values.length < 2 ? null : values[1].trim();
          final pin = rawPin == null || rawPin.isEmpty ? null : rawPin;
          final isConnected = status == 'connected';
          if (isConnected != _bleConnected || pin != _blePinCode) {
            setState(() {
              if (isConnected && !_bleConnected && _btPairingActive) {
                _blePairedCount++;
              }
              _bleConnected = isConnected;
              _blePinCode = pin;
            });
          }
        } catch (_) {}
      },
    );
  }

  Future<void> _restoreBluetoothWhitelist() async {
    if (!_bleWhitelistDisabled) return;
    try {
      await _sshService.redisLpush(
        'scooter:bluetooth',
        'advertising-start-with-whitelisting',
      );
      _bleWhitelistDisabled = false;
      debugPrint('UI: BLE advertising restored to whitelisting');
    } catch (e) {
      debugPrint('UI: failed to restore BLE whitelisting: $e');
      rethrow;
    }
  }

  Future<void> _restorePairingVehicleState() async {
    if (!_pairingVehicleStateChanged || _isDryRun) return;
    final before = _stateBeforePairing;
    if (before == null || before == 'parked') {
      _pairingVehicleStateChanged = false;
      _stateBeforePairing = null;
      return;
    }
    try {
      await _sshService.forceVehicleState(before);
      _pairingVehicleStateChanged = false;
      _stateBeforePairing = null;
      debugPrint('UI: vehicle state restored to $before after pairing');
    } catch (e) {
      debugPrint('UI: could not restore vehicle state (ok): $e');
      rethrow;
    }
  }

  Future<void> _stopBluetoothPairing({bool advance = true}) async {
    final stopPinPolling = _blePinPolling.stop();
    final stopAdvRearming = _bleAdvRearming.stop();
    await runBoundedCleanupActions([
      () => stopPinPolling,
      () => stopAdvRearming,
      if (_bleWhitelistDisabled) _restoreBluetoothWhitelist,
      if (_pairingVehicleStateChanged) _restorePairingVehicleState,
    ]);
    if (!_pairingVehicleStateChanged) _stateBeforePairing = null;
    if (!mounted) return;
    setState(() {
      _btPairingActive = false;
      _btAdvertisingSettling = false;
      _blePinCode = null;
      _bleConnected = false;
    });
    if (advance) _setPhase(InstallerPhase.keycardSetup);
  }

  // Killed on entry to keycardSetup so that any auto-startup master-learning
  // mode in keycard-service is disengaged before the user can tap a card.
  // Without this, a stray tap on the reader during the install would be
  // learned as the master keycard and wipe the authorized list.
  Future<void> _onEnterKeycardSetup() async {
    setState(() {
      _keycardLearning = false;
      _keycardMasterLearning = false;
      _keycardStage = _KeycardStage.loading;
      _keycardServiceCanMaster = null;
      _keycardMasterCount = null;
      _keycardAuthorizedCount = null;
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

    // Keycard learning can sit here for a while, and a parked scooter is fair
    // game for both the auto-standby timer and the alarm, so re-apply the
    // policy and the parked settings. Cleared at finish.
    //
    // Only where they can land, which is the same test the two neighbouring
    // sites use. With an artifact still due, a clean install is running this
    // phase on the stage-0 image: it has no settings-service, so every one of
    // these is `lsc: not found` and post-artifact applies them once the board
    // has booted the real image. An upgrade has an artifact due too and is
    // still running the image the connect parked them on, so there is nothing
    // to re-apply there either. What is left is the board that took a full
    // image or was left alone, where a reflash did reset them.
    if (!_mdbArtifactPending) {
      try {
        await _sshService.runCommand('lsc set scooter.usb0-policy always-on');
        debugPrint('UI: scooter.usb0-policy=always-on (keycardSetup)');
      } catch (e) {
        debugPrint(
          'UI: failed to set scooter.usb0-policy=always-on at keycardSetup (ok): $e',
        );
      }
      await _disableInstallerHazards(label: 'keycardSetup');
    } else {
      // The alarm is the one hazard that can still be armed on a board this
      // skipped, and its runtime queue is there even when the settings are
      // not.
      await _disarmAlarm(label: 'keycardSetup');
    }

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
      await _sshService.runCommand(
        'systemctl start librescoot-keycard 2>/dev/null; true',
      );
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
      debugPrint(
        'UI: librescoot-keycard not active after start (state=$activeState)',
      );
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

    // Disengage boot-time auto-master-learning before any tap can land, but
    // only on a board that has it armed.
    //
    // `set-master:NONE` is the only command that clears masterLearningMode
    // (learn:master:stop only leaves teach-in), and it is destructive:
    // SetMaster replaces the whole master list with the NONE sentinel and
    // persists it, and GetMasterCount does not count NONE. Sent to a board
    // that already has a master it erases a registration and then reports
    // zero, which is what an upgrade did to a user's card. A board with a
    // master never armed auto-learning in the first place, so there is
    // nothing to disengage there and nothing lost by staying quiet.
    //
    // A count nobody could read is not a zero: unreadable leaves the command
    // unsent, which risks the next tap being learned as master on a board
    // with none, against erasing one on a board that has it.
    final masterCount = await _keycardReadMasterCount();
    if (shouldDisengageMasterLearning(masterCount)) {
      try {
        await _sshService.redisLpush('scooter:keycard', 'set-master:NONE');
        debugPrint('UI: keycardSetup entered, master mode disengaged');
      } catch (e) {
        debugPrint('UI: failed to disengage master-learning on entry: $e');
      }
    } else {
      debugPrint(
        'UI: keycardSetup entered, left the master list alone '
        '(count=${masterCount ?? "unreadable"})',
      );
    }

    final capability = await _keycardDetectCapability();
    await _keycardRefreshCounts();
    if (!mounted) return;

    setState(() {
      _keycardCapability = capability;
      final canMaster = capability == KeycardCapability.current;
      _keycardServiceCanMaster = canMaster;
      if (canMaster &&
          ((_keycardMasterCount ?? 0) > 0 ||
              (_keycardAuthorizedCount ?? 0) > 0)) {
        _keycardStage = _KeycardStage.alreadyConfigured;
      } else {
        _keycardStage = _KeycardStage.cards;
      }
    });
  }

  KeycardCapability? _keycardCapability;

  /// A reader nobody answers for cannot enrol a card, so the buttons that
  /// drive it are dead regardless of the link being up.
  bool get _canDriveKeycard =>
      (_sshService.isConnected &&
          _keycardCapability != KeycardCapability.unreachable) ||
      _isDryRun;

  /// Probe the keycard-service for new-command support by sending
  /// `learn:master:stop` and inspecting `keycard.command-result`. The new
  /// service answers either `ok` (was in master teach-in) or
  /// `error:not in master teach-in`; the old service answers
  /// `error:unknown command`. We snapshot command-result before the probe so
  /// we can wait for it to actually change, instead of racing against an old
  /// stale value.
  ///
  /// Silence is its own answer. Nobody writing command-result at all means no
  /// keycard-service is listening, which is not an old one: the reader sits on
  /// the DBC panel, so a board with no dashboard reachable cannot enrol
  /// anything. Reporting that as legacy sends the UI down a path that offers
  /// teach-in on hardware that cannot do it.
  Future<KeycardCapability> _keycardDetectCapability() async {
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
          return KeycardCapability.legacy;
        }
        debugPrint('UI: keycard capability probe -> new ($result)');
        return KeycardCapability.current;
      }
      debugPrint('UI: keycard capability probe: nobody answered');
    } catch (e) {
      debugPrint('UI: keycard capability probe failed: $e');
    }
    return KeycardCapability.unreachable;
  }

  /// How many real master cards the board has on file, or null when nobody
  /// could say. keycard-service publishes this when it starts, so a read that
  /// races its startup answers about the read rather than about the board.
  Future<int?> _keycardReadMasterCount() async {
    if (_isDryRun) return null;
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        final raw = await _sshService.redisHget('system', 'keycard-master-count');
        final parsed = int.tryParse(raw ?? '');
        if (parsed != null) return parsed;
      } catch (e) {
        debugPrint('UI: master-count read failed (attempt $attempt): $e');
      }
      if (attempt < 3) await Future.delayed(const Duration(seconds: 1));
    }
    debugPrint('UI: master count never answered');
    return null;
  }

  Future<void> _keycardRefreshCounts() async {
    if (_isDryRun) return;
    try {
      final m = await _sshService.redisHget('system', 'keycard-master-count');
      final a = await _sshService.redisHget(
        'system',
        'keycard-authorized-count',
      );
      if (!mounted) return;
      setState(() {
        // Null when absent or unparseable: the panel has to tell "not read"
        // apart from "none".
        _keycardMasterCount = int.tryParse(m ?? '');
        _keycardAuthorizedCount = int.tryParse(a ?? '');
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

  Future<void> _stopActiveKeycardModes() async {
    if (_isDryRun) {
      _keycardLearning = false;
      _keycardMasterLearning = false;
      return;
    }
    await runBoundedCleanupActions([
      if (_keycardLearning)
        () async {
          await _sshService.redisLpush('scooter:keycard', 'learn:stop');
          _keycardLearning = false;
          debugPrint('UI: stopped keycard learning during cleanup');
        },
      if (_keycardMasterLearning)
        () async {
          await _sshService.redisLpush('scooter:keycard', 'learn:master:stop');
          _keycardMasterLearning = false;
          debugPrint('UI: stopped master keycard learning during cleanup');
        },
    ]);
  }

  Future<void> _cleanupKeycardPhase() async {
    await _stopActiveKeycardModes();
    await _keycardTearDown();
  }

  Future<void> _startKeycardLearning() async {
    if (_isDryRun) {
      // Carry the previous session's count forward so "Add more" simulates
      // the additive semantics of the real service.
      _keycardAuthorizedCountBefore = _keycardAuthorizedCount ?? 0;
    } else {
      try {
        final raw = await _sshService.redisHget(
          'system',
          'keycard-authorized-count',
        );
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
          _setStatus(
            AppLocalizations.of(
              context,
            )!.keycardStartLearningFailed(e.toString()),
          );
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
          final raw = await _sshService.redisHget(
            'system',
            'keycard-authorized-count',
          );
          polled = int.tryParse(raw ?? '') ?? polled;
        } catch (_) {}
        if (polled >= expected) break;
        await Future.delayed(const Duration(milliseconds: 200));
      }
      if (polled != expected) {
        debugPrint(
          'UI: count after learn:stop ($polled) != expected ($expected); '
          'trusting events (sessionDelta=$sessionDelta)',
        );
      }
      _keycardAuthorizedCount = polled >= _keycardAuthorizedCountBefore
          ? polled
          : expected;
    }
    final registered = sessionDelta > 0;
    debugPrint(
      'UI: keycard learning stopped (registered=$registered, sessionDelta=$sessionDelta)',
    );
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
      _keycardAuthorizedCount = (_keycardAuthorizedCount ?? 0) + 1;
    });
  }

  /// Put the vehicle into master teach-in and show the stage that asks for a
  /// tap.
  ///
  /// Subscribing and starting are one operation, because the screen is only
  /// honest when both worked. A failed start means a tap does nothing at all;
  /// a failed subscribe is worse, because the vehicle really does enrol the
  /// card while the installer never hears the event, never advances, and ends
  /// up disagreeing with the scooter about what happened.
  Future<void> _keycardStartMasterStage({bool retry = false}) async {
    setState(() {
      _keycardStage = _KeycardStage.master;
      _keycardToastMessage = null;
      _keycardMasterStartError = null;
    });
    if (_isDryRun) return;

    try {
      await _keycardSubscribeEvents();
      if (retry) {
        // A push that threw may still have reached the service, so the board
        // can already be in master mode. Put it back to a known state before
        // asking again rather than starting on top of a start.
        try {
          await _sshService.redisLpush('scooter:keycard', 'learn:master:stop');
        } catch (e) {
          debugPrint('UI: could not clear master mode before retry: $e');
        }
      }
      // Set before the push, not after. If this throws we do not know whether
      // the command landed, and the cleanup on window close only sends
      // learn:master:stop when this flag is set. Claiming the mode we asked
      // for means a board left in it still gets stopped; a stop it never
      // needed is what the Skip button sends anyway.
      _keycardMasterLearning = true;
      await _sshService.redisLpush('scooter:keycard', 'learn:master:start');
    } catch (e) {
      debugPrint('UI: master teach-in did not start: $e');
      if (!mounted) return;
      setState(() => _keycardMasterStartError = e.toString());
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
          _keycardAuthorizedCount = (_keycardAuthorizedCount ?? 0) + 1;
        });
      }
    } else if (payload.startsWith('card-duplicate:')) {
      if (_keycardLearning) {
        _keycardShowToast(l10n.keycardCardDuplicateToast, Colors.orangeAccent);
      }
    } else if (payload.startsWith('master-learned:')) {
      _keycardMasterLearning = false;
      _keycardShowToast(l10n.keycardMasterStageLearnedToast, Colors.green);
      _keycardRefreshCounts();
      // Auto-advance: master successfully registered.
      Timer(const Duration(milliseconds: 1200), () async {
        if (!mounted) return;
        await _keycardTearDown();
        if (!mounted) return;
        _setPhase(_phaseAfterKeycardSetup);
      });
    } else if (payload.startsWith('rejected:already-authorized:')) {
      _keycardShowToast(l10n.keycardMasterStageRejectedToast, Colors.redAccent);
    } else if (payload.startsWith('error:save-failed:')) {
      _keycardShowToast(
        l10n.keycardMasterStageSaveFailedToast,
        Colors.redAccent,
      );
    } else if (payload == 'reset') {
      // Service told everyone state was wiped; refresh counts.
      _keycardRefreshCounts();
    }
  }

  Future<void> _keycardSimulateMasterEvent(String payload) async {
    if (!_isDryRun) return;
    if (payload.startsWith('master-learned:')) {
      setState(() {
        _keycardMasterCount = (_keycardMasterCount ?? 0) + 1;
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
    _keycardMasterLearning = false;
    await _keycardTearDown();
    if (!mounted) return;
    if (advance) {
      _setPhase(_phaseAfterKeycardSetup);
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
        _keycardMasterLearning = false;
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
        _keycardMasterCount = null;
        _keycardAuthorizedCount = null;
      }
      _keycardStage = _KeycardStage.cards;
    });
  }

  Future<void> _skipKeycardSetupEntirely() async {
    if (_keycardLearning && _canDriveKeycard) {
      await _stopKeycardLearning(advance: false);
    }
    await _keycardTearDown();
    if (mounted) _setPhase(_phaseAfterKeycardSetup);
  }

  Widget _buildKeycardSetup(AppLocalizations l10n) {
    return PhaseLayout(
      title: _keycardStageHeading(l10n),
      actions: switch (_keycardStage) {
        _KeycardStage.cards => _keycardCardsActions(l10n),
        _KeycardStage.cardsReview => _keycardCardsReviewActions(l10n),
        _KeycardStage.alreadyConfigured =>
          _keycardAlreadyConfiguredActions(l10n),
        _ => const [],
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // What the screen is for and how it goes, on every stage: it used
          // to open as an NFC icon over a spinner and say nothing at all
          // until the reader was ready. A scooter that already has cards gets
          // the same screen, with its count in the panel on the right, rather
          // than a page of its own that happens to say the same thing.
          ...[
            Text(l10n.keycardWhy,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade300)),
            const SizedBox(height: 20),
            // Steps on the left, what is true right now on the right, the same
            // shape the pairing screen uses. This step needs it more: it is the
            // only one with a count, and that count is what enables Finish, so
            // without somewhere to show it the user infers it from whether the
            // button lit up.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InstructionStep(
                        number: 1,
                        title: l10n.keycardStep1,
                        description: l10n.keycardStep1Desc,
                      ),
                      InstructionStep(
                        number: 2,
                        title: l10n.keycardStep2,
                        description: l10n.keycardStep2Desc,
                      ),
                      InstructionStep(
                        number: 3,
                        title: l10n.keycardStep3,
                        description: l10n.keycardStep3Desc,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(flex: 2, child: _keycardStatusPanel(l10n)),
              ],
            ),
            const SizedBox(height: 12),
          ],
          switch (_keycardStage) {
            _KeycardStage.loading || _KeycardStage.done => Row(
                children: [
                  const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 12),
                  Text(l10n.keycardPreparingReader,
                      style: TextStyle(color: Colors.grey.shade400)),
                ],
              ),
            _KeycardStage.alreadyConfigured =>
              _buildKeycardAlreadyConfigured(l10n),
            _KeycardStage.cards => _buildKeycardCardsStage(l10n),
            _KeycardStage.cardsReview => _buildKeycardCardsReview(l10n),
            _KeycardStage.master => _buildKeycardMasterStage(l10n),
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

  /// Where a stage's choices live: the action bar, like every other screen.
  /// Stacked full-width buttons down the middle of the body made this the one
  /// screen in the flow whose controls were somewhere else.
  List<PhaseAction> _keycardAlreadyConfiguredActions(AppLocalizations l10n) => [
        PhaseAction(
          label: l10n.skipKeycardSetup,
          side: ActionSide.back,
          onPressed: _skipKeycardSetupEntirely,
        ),
        PhaseAction(
          label: l10n.keycardStartOverButton,
          icon: Icons.refresh,
          onPressed: _keycardStartOver,
        ),
        PhaseAction(
          label: l10n.keycardEntryContinueButton,
          icon: Icons.arrow_forward,
          primary: true,
          onPressed: () => _setPhase(_phaseAfterKeycardSetup),
        ),
      ];

  Widget _buildKeycardAlreadyConfigured(AppLocalizations l10n) => Text(
        l10n.keycardEntryAlreadyConfiguredBody(
          _keycardMasterCount ?? 0,
          _keycardAuthorizedCount ?? 0,
        ),
        style: TextStyle(fontSize: 14, color: Colors.grey.shade300),
      );

  Widget _buildKeycardCardsStage(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.keycardLearningBody,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade300),
        ),
        const SizedBox(height: 16),
        // Nothing to show before the first card: the action bar already
        // carries Start, and having it here too made one screen ask twice.
        if (_keycardLearning || (_keycardAuthorizedCount ?? 0) > 0) ...[
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
                Text(
                  l10n.keycardLearningActive,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: kAccent,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.keycardLearningActiveHint,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.keycardLearningTapped(_keycardSessionTapCount),
                  style: TextStyle(
                    fontSize: 13,
                    color: _keycardSessionTapCount > 0
                        ? Colors.green
                        : Colors.grey.shade400,
                    fontWeight: _keycardSessionTapCount > 0
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
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
      ],
    );
  }

  /// The cards stage has three states and they used to share button slots, so
  /// Start sat where Done had been a moment earlier and read as "start over".
  ///
  ///   nothing enrolled : Skip .......... Start
  ///   learning         : ................ Stop learning
  ///   cards enrolled   : Start over ... Add more, Finish
  ///
  /// Skip is gone once a card is on file: the setup has happened, so the only
  /// question left is whether to add more or move on.
  /// Skip, Start/Stop and Finish, all three present at every point.
  ///
  /// The instructions on this screen tell the user to press Finish, so Finish
  /// exists from the start; it is disabled until a card has actually been
  /// taught in, which is the condition it depends on. Start becomes Stop while
  /// the reader is scanning, so ending a scan and ending the step are separate
  /// buttons rather than the same one under two names.
  /// What is true right now: the reader, and the count that gates Finish.
  Widget _keycardStatusPanel(AppLocalizations l10n) {
    final scanning = _keycardLearning;
    final preparing = _keycardStage == _KeycardStage.loading ||
        _keycardStage == _KeycardStage.done;
    final unreachable = _keycardCapability == KeycardCapability.unreachable;
    final (state, colour) = switch ((preparing, unreachable, scanning)) {
      (true, _, _) => (l10n.keycardReaderPreparing, Colors.grey.shade400),
      // Nobody answered the capability probe, so there is no reader to hold a
      // card to. Saying "Ready" here would be the panel's only lie.
      (_, true, _) => (l10n.keycardReaderUnreachable, Colors.orange),
      (_, _, true) => (l10n.keycardReaderScanning, Colors.amber),
      _ => (l10n.keycardReaderReady, kAccent),
    };
    // Taps arrive as events before the count hash settles, so the running
    // total leads with what this session has seen and falls back to the hash
    // where that is higher, which is the case on a board that already had
    // cards before the installer touched it.
    final session = _keycardAuthorizedCountBefore + _keycardSessionTapCount;
    final stored = _keycardAuthorizedCount;
    // Null while the stored count has not come back and nothing has been
    // tapped: the panel said "0 cards" and offered "register at least one"
    // before it had asked, which reads as an answer rather than a question.
    final int? cards = stored == null
        ? (_keycardSessionTapCount > 0 ? session : null)
        : (session > stored ? session : stored);
    final masters = _keycardMasterCount;

    Widget line(String text) => Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(text, style: const TextStyle(fontSize: 13)),
        );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colour.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration:
                    BoxDecoration(shape: BoxShape.circle, color: colour),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  state,
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: colour, fontSize: 14),
                ),
              ),
            ],
          ),
          line(cards == null
              ? l10n.keycardCardsChecking
              : l10n.keycardCardsTaught(cards)),
          // Only when one exists: a scooter with no master card is the
          // ordinary case and a zero here would read as something missing.
          if ((masters ?? 0) > 0)
            line(l10n.keycardMastersRegistered(masters!)),
          if (cards == 0 && !unreachable) ...[
            const SizedBox(height: 12),
            Text(
              l10n.keycardNeedOneToFinish,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
            ),
          ],
        ],
      ),
    );
  }

  List<PhaseAction> _keycardCardsActions(AppLocalizations l10n) {
    // A tap this session counts even before the hash catches up: learn:stop
    // can take seconds to settle on a freshly flashed eMMC.
    final taught =
        (_keycardAuthorizedCount ?? 0) > 0 || _keycardSessionTapCount > 0;
    return [
      if (!_keycardLearning && (_keycardServiceCanMaster ?? false))
        PhaseAction(
          label: l10n.keycardStartOverButton,
          icon: Icons.refresh,
          side: ActionSide.back,
          onPressed: _keycardStartOver,
        ),
      PhaseAction(
        label: l10n.skipKeycardSetup,
        side: ActionSide.forward,
        onPressed: () => _skipKeycardSetup(confirmFirst: !taught),
      ),
      PhaseAction(
        label: _keycardLearning
            ? l10n.keycardStopScanning
            : (taught ? l10n.keycardAddMore : l10n.keycardStartLearning),
        icon: _keycardLearning ? Icons.stop : Icons.nfc,
        onPressed: _canDriveKeycard
            ? (_keycardLearning
                ? () => _stopKeycardLearning(advance: false)
                : _startKeycardLearning)
            : null,
      ),
      PhaseAction(
        label: l10n.keycardFinishCards,
        icon: Icons.check,
        primary: true,
        onPressed: taught ? () => _stopKeycardLearning() : null,
      ),
    ];
  }

  /// Leaving the step. Skipping with nothing taught in is the one route that
  /// asks first: it is a click away from a scooter with no card, and the
  /// button sits next to Finish.
  Future<void> _skipKeycardSetup({required bool confirmFirst}) async {
    if (confirmFirst) {
      final l10n = AppLocalizations.of(context)!;
      final go = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.keycardSkipConfirmTitle),
          content: Text(l10n.keycardSkipConfirmBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancelButton),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.keycardSkipConfirmAction),
            ),
          ],
        ),
      );
      if (go != true) return;
    }
    await _skipKeycardSetupEntirely();
  }

  Widget _buildKeycardCardsReview(AppLocalizations l10n) {
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
                child: Text(
                  l10n.keycardLearnedAck(_keycardSessionTapCount),
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade200),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The same four choices the stage always had, in the action bar every other
  /// phase puts them in. They used to be stacked in the body, so finishing the
  /// card step was the one place in the flow where the buttons moved.
  List<PhaseAction> _keycardCardsReviewActions(AppLocalizations l10n) {
    final canMaster = _keycardServiceCanMaster ?? false;
    return [
      if (canMaster)
        PhaseAction(
          label: l10n.keycardStartOverButton,
          icon: Icons.refresh,
          side: ActionSide.back,
          onPressed: _keycardStartOver,
        ),
      if (canMaster && (_keycardAuthorizedCount ?? 0) > 0)
        PhaseAction(
          label: l10n.keycardCardsStageAddMasterButton,
          icon: Icons.shield_outlined,
          onPressed: _keycardStartMasterStage,
        ),
      PhaseAction(
        label: l10n.keycardAddMore,
        icon: Icons.nfc,
        onPressed: _canDriveKeycard ? _startKeycardLearning : null,
      ),
      PhaseAction(
        label: l10n.keycardCardsStageContinueButton,
        icon: Icons.arrow_forward,
        primary: true,
        onPressed: () => _setPhase(_phaseAfterKeycardSetup),
      ),
    ];
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
            border: Border.all(
              color: Colors.redAccent.withValues(alpha: 0.6),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.redAccent,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.keycardMasterStageWarningHeading,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                l10n.keycardMasterStageWarningBody,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade200),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Asking for a tap is only true while the vehicle is listening for
        // one. When the stage could not be started, the same slot says so
        // instead, because a card held against a reader that was never put
        // into master mode does nothing and looks identical to waiting.
        if (_keycardMasterStartError == null)
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
                Text(
                  l10n.keycardMasterStageHint,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: kAccent,
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 22,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.keycardMasterStageStartFailed,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SelectableText(
                  _keycardMasterStartError!,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Colors.redAccent,
                  ),
                ),
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
              border: Border.all(
                color: _keycardToastColor.withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              _keycardToastMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: _keycardToastColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (_keycardMasterStartError != null) ...[
          FilledButton.icon(
            onPressed: () => _keycardStartMasterStage(retry: true),
            icon: const Icon(Icons.refresh),
            label: Text(l10n.keycardMasterStageRetryButton),
          ),
          const SizedBox(height: 8),
        ],
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
          Text(
            '[DRY RUN]',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: () =>
                _keycardSimulateMasterEvent('master-learned:DEADBEEF'),
            icon: const Icon(Icons.touch_app, size: 16),
            label: Text(l10n.keycardSimulateMasterTapButton),
          ),
          TextButton.icon(
            onPressed: () => _keycardSimulateMasterEvent(
              'rejected:already-authorized:CAFEBABE',
            ),
            icon: const Icon(Icons.block, size: 16),
            label: Text(l10n.keycardSimulateRejectedTapButton),
          ),
        ],
      ],
    );
  }

  Widget _buildFinish(AppLocalizations l10n) {
    // The install is done by now; this is confirming the unlock landed, which
    // is a wait like any other and takes the overlay rather than a frame with
    // a spinner in it.
    if (_awaitingFinishHandover) {
      return _waitPhase(
        title: l10n.finishHandoverTitle,
        warning: l10n.finishHandoverBody,
      );
    }

    // The laptop owed the finish and could not reach the board. On this route
    // the finish is the install, so the screen says what happened rather than
    // congratulating the owner over a scooter that was never installed.
    if (_finishBlocked) {
      return PhaseLayout(
        title: l10n.finishBlockedHeading,
        actions: [
          PhaseAction(
            label: l10n.finishBlockedRetry,
            icon: Icons.refresh,
            primary: true,
            onPressed: () {
              setState(() {
                _finishBlocked = false;
                _awaitingFinishHandover = true;
              });
              Future.microtask(_onEnterFinish);
            },
          ),
        ],
        child: NoticeCard(
          severity: NoticeSeverity.danger,
          title: l10n.finishBlockedHeading,
          body: l10n.finishBlockedBody,
        ),
      );
    }
    return PhaseLayout(
      title: l10n.welcomeToLibrescoot,
      actions: [
        PhaseAction(
          label: l10n.finished,
          icon: Icons.check_circle,
          primary: true,
          onPressed: () async {
            if (!_keepCache) {
              await _offerCleanup();
            }
            if (mounted) exit(0);
          },
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.celebration, size: 40, color: kAccent),
          const SizedBox(height: 12),
          // The reassembly steps are the same on every route, but what they
          // set in motion is not: on the trampoline routes reconnecting the
          // cable starts work on the board, and the screen used to end the
          // conversation right where that begins.
          _finishWhatHappensNext(l10n),
          const SizedBox(height: 16),
          Text(
            l10n.finalSteps,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          // The dashboard path already swapped the cable back before the
          // trampoline ran, so telling the user to do it again is wrong;
          // what is left there is tightening the screws they were told to
          // leave loose. An MDB-only run still has the laptop plugged in.
          ..._finalSteps(l10n),
          const SizedBox(height: 16),
          // The one part of this screen about actually using the scooter, so
          // it is open rather than an expander at the bottom. It carries its
          // own heading and the handbook and website links.
          _buildGettingStarted(l10n),
          const SizedBox(height: 12),
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.keepCachedDownloads),
            subtitle: Text(
              l10n.mbOnDisk(_totalCacheSizeMb()),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
            value: _keepCache,
            onChanged: (v) => setState(() => _keepCache = v ?? false),
          ),
        ],
      ),
    );
  }

  /// What the reassembly steps set in motion, which differs by route.
  ///
  /// Any run that started the trampoline continues on the board after the
  /// cable goes back: that is what arms _deviceFinishArmed, and the trampoline
  /// is always given onDevice, so there is no variant that hands back to the
  /// laptop. Whether the dashboard is being written on top of that is the
  /// plan's own answer, since tiles alone also require the handoff.
  Widget _finishWhatHappensNext(AppLocalizations l10n) {
    final continues = _deviceFinishArmed;
    final flashesDbc = continues && (_plan?.needsDbcWork ?? false);
    final body = !continues
        ? l10n.finishNextNothing
        : (flashesDbc ? l10n.finishNextDbcFlash : l10n.finishNextOnDevice);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: (continues ? Colors.amber : kAccent).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (continues ? Colors.amber : kAccent).withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            continues ? Icons.autorenew : Icons.check_circle_outline,
            size: 20,
            color: continues ? Colors.amber : kAccent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.finishNextHeading,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: TextStyle(
                      fontSize: 13, height: 1.4, color: Colors.grey.shade300),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The last physical steps. Both paths unlock the scooter themselves, so
  /// neither asks the user to.
  List<Widget> _finalSteps(AppLocalizations l10n) {
    final swapped = dashboardCableIsBack(
      laptopSeesBoard: _device != null,
      deviceFinishArmed: _deviceFinishArmed,
    );
    final steps = <({String title, String description})>[
      if (!swapped)
        (
          title: l10n.disconnectUsbFromLaptopFinal,
          description: l10n.disconnectUsbFromLaptopFinalDesc,
        ),
      if (!swapped)
        (
          title: l10n.reconnectDbcUsbCable,
          description: l10n.reconnectDbcUsbCableDesc,
        ),
      if (swapped)
        (title: l10n.tightenDbcCable, description: l10n.tightenDbcCableDesc),
      (
        title: l10n.closeSeatboxAndFootwell,
        description: l10n.closeSeatboxAndFootwellDesc,
      ),
      (title: l10n.finalRide, description: l10n.finalRideDesc),
    ];
    // One line each. These are physical steps someone is looking at while
    // they do them, so the titles carry it. Only the last keeps its
    // description, because it says the one thing the scooter cannot: that it
    // has already unlocked itself, and what to do if it has not.
    return [
      for (var i = 0; i < steps.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 20,
                child: Text('${i + 1}.',
                    style:
                        TextStyle(fontSize: 13, color: Colors.grey.shade500)),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(steps[i].title,
                        style: const TextStyle(fontSize: 13)),
                    if (i == steps.length - 1) ...[
                      const SizedBox(height: 2),
                      Text(steps[i].description,
                          style: TextStyle(
                              fontSize: 12,
                              height: 1.3,
                              color: Colors.grey.shade400)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
    ];
  }

  Widget _buildGettingStarted(AppLocalizations l10n, {bool showTitle = true}) {
    final handbookUrl = _handbookUrl;
    const websiteUrl = 'https://librescoot.org/';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: kAccent.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(8),
        color: kAccent.withValues(alpha: 0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showTitle) ...[
            Row(
              children: [
                const Icon(Icons.lightbulb_outline, size: 20, color: kAccent),
                const SizedBox(width: 8),
                Text(
                  l10n.gettingStartedTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: kAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          _buildTip(
            Icons.menu_open,
            l10n.gettingStartedOpenMenuTitle,
            l10n.gettingStartedOpenMenuDesc,
          ),
          _buildTip(
            Icons.swipe_vertical,
            l10n.gettingStartedDriveMenuTitle,
            l10n.gettingStartedDriveMenuDesc,
          ),
          _buildTip(
            Icons.system_update_alt,
            l10n.gettingStartedUpdateModeTitle,
            l10n.gettingStartedUpdateModeDesc,
          ),
          _buildTip(
            Icons.navigation_outlined,
            l10n.gettingStartedNavigationTitle,
            l10n.gettingStartedNavigationDesc,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                l10n.gettingStartedFooter,
                style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              ),
              _buildLinkButton(
                Icons.open_in_new,
                l10n.gettingStartedLinkWebsite,
                websiteUrl,
              ),
              _buildLinkButton(
                Icons.menu_book_outlined,
                l10n.gettingStartedLinkHandbook,
                handbookUrl,
              ),
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
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const String discordUrl = 'https://discord.gg/BmY2P2T9j3';

  /// The handbook follows the interface language; there is no combined page.
  String get _handbookUrl =>
      Localizations.localeOf(context).languageCode == 'de'
          ? 'https://librescoot.org/handbook/'
          : 'https://librescoot.org/en/handbook/';

  /// A link that has to read as a way out, on a screen telling someone not to
  /// touch anything. A bare text button against a red border did not.
  Widget _noticeLink(IconData icon, String label, String url, Color colour) {
    return OutlinedButton.icon(
      onPressed: () => _openExternalUrl(url),
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: colour,
        side: BorderSide(color: colour.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        visualDensity: VisualDensity.compact,
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(url)));
    }
  }

  String _totalCacheSizeMb() {
    final total = _downloadState.items.fold<int>(
      0,
      (sum, i) => sum + i.expectedSize,
    );
    return (total / 1024 / 1024).toStringAsFixed(0);
  }

  Future<void> _cleanupMdb() async {
    if (!_sshService.isConnected) return;
    // The staging directory is also where the trampoline's own log, status and
    // journal live, and it is the only account of what happened while the
    // laptop was unplugged. Pull it into this installer's log before deleting
    // anything, so a run that needs explaining still can be.
    String? status;
    try {
      status = await _sshService
          .runCommand('cat /data/installer/trampoline-status 2>/dev/null; true')
          .timeout(const Duration(seconds: 15));
    } catch (_) {}
    await _captureTrampolineEvidence(status);
    try {
      // /data/installer/ holds everything this installer stages. The
      // legacy rm -f list below covers leftovers from installers that
      // wrote directly to /data/ — harmless once those versions are gone,
      // but cheap to keep for now so upgraders don't accumulate orphans.
      // settings.toml.preinstall and .default are deliberately not in it:
      // the restore owns the first and nothing owns the second.
      // Echoes what it actually copied, because a run with no trampoline
      // behind it has nothing to preserve and the directory is never made.
      final preserved = await _sshService.runCommand(
        'if [ -d ${SshService.installerDir} ]; then '
        '  mkdir -p ${SshService.installerHistoryDir}/$_installRunId; '
        '  for f in trampoline.log trampoline-status trampoline-journal.log '
        '           finalize.log; do '
        r'    [ -f "' '${SshService.installerDir}' r'/$f" ] && '
        r'      cp "' '${SshService.installerDir}' r'/$f" '
        '      ${SshService.installerHistoryDir}/$_installRunId/ && '
        r'      echo "$f"; '
        '  done; '
        '  rmdir ${SshService.installerHistoryDir}/$_installRunId 2>/dev/null; '
        'fi; true',
      );
      // Before the sweep, which deletes the directory a displaced onboot.sh is
      // saved in. It declines while a phase is still queued.
      await _sshService.retireOnbootCoordinator();
      await _sshService.runCommand(
        // Selective, because the record and the logs now live in here too.
        // See SshService.installerSweepCommand for what survives and why.
        '${SshService.installerSweepCommand}; '
        // Leftovers from installers that wrote straight to /data. Harmless
        // once those versions are gone, cheap to keep for now so upgraders do
        // not accumulate orphans.
        'rm -f /data/librescoot-unu-*.sdimg.gz /data/librescoot-unu-*.sdimg.bmap '
        '/data/tiles_*.mbtiles /data/valhalla_tiles_*.tar '
        '/data/trampoline.sh /data/trampoline.log /data/trampoline-status '
        '/data/trampoline-stdout.log /data/trampoline-journal.log '
        '/data/stop-error-signals.sh /data/librescoot-flasher '
        '/data/onboot.sh.bak '
        '/data/test-trampoline-*.sh /data/test-step*.log; '
        'rm -rf /data/fwtools /data/last-install-log',
      );
      debugPrint('Cleanup: removed installer staging from MDB');
      // Keep the small diagnostic files on the device too. They cost a few
      // hundred kilobytes against the hundreds of megabytes swept above, and
      // they are what a later visit reads when the user says it went wrong.
      // Said only when something was kept: an MDB-only run has no trampoline
      // log, and claiming a path that was never created sends whoever reads
      // this log looking for a directory that is not there.
      final kept = preserved.trim();
      debugPrint(kept.isEmpty
          ? 'Cleanup: nothing to preserve, this run had no trampoline'
          : 'Cleanup: kept in ${SshService.installerHistoryDir}/$_installRunId: '
              '${kept.split(RegExp(r"\s+")).join(", ")}');
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

/// Whether the dashboard's USB cable is the one currently in the MDB.
///
/// The board has a single USB port, so the laptop and the dashboard cannot
/// both be in it. The laptop seeing the board is proof its own cable is in
/// that port, whatever the run did earlier: someone who plugged back in to
/// read a log must not be told the dashboard cable is already seated. With no
/// link, an armed device-run finish means the user swapped it over before
/// walking away, and tightening the screws is all that is left.
bool dashboardCableIsBack({
  required bool laptopSeesBoard,
  required bool deviceFinishArmed,
}) => !laptopSeesBoard && deviceFinishArmed;

/// An install failure whose message is already in the user's language.
/// [toString] is the message itself because the artifact screen renders
/// `e.toString()` straight into the same slot as mender's stderr.
class _LocalizedInstallException implements Exception {
  _LocalizedInstallException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _ManualPasswordDialog extends StatefulWidget {
  /// Returned when the user says they do not know the password, as distinct
  /// from cancelling. Not a password anyone could set: the field rejects it.
  static const unknown = '\u0000unknown';

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
        // Distinct from Cancel: cancelling is changing your mind, this is not
        // having the answer, and the two want different next steps. Reported
        // as its own value so the caller can say where to find it.
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(_ManualPasswordDialog.unknown),
          child: Text(l10n.manualPasswordUnknown),
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
