import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart' show LaunchArgs, installerLog, launchArgs, showElevationRequiredDialog;
import '../l10n/app_localizations.dart';
import '../models/download_state.dart';
import '../models/installer_phase.dart';
import '../models/region.dart';
import '../models/scooter_health.dart';
import '../models/trampoline_status.dart';
import '../services/services.dart';
import '../widgets/download_progress.dart';
import '../widgets/health_check_panel.dart';
import '../widgets/instruction_step.dart';
import '../widgets/phase_sidebar.dart';
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

  // Phase guard flags (prevent auto-start methods from re-firing on rebuild)
  bool _mdbConnectStarted = false;
  bool _healthCheckStarted = false;
  bool _mdbToUmsStarted = false;
  bool _mdbFlashStarted = false;
  bool _mdbBootStarted = false;
  bool _dbcPrepStarted = false;
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
  Timer? _blePinPollTimer;
  final ScrollController _phaseScrollController = ScrollController();
  bool _keycardLearning = false;
  int _keycardAuthorizedCountBefore = 0; // captured at Start, compared at Done
  int _keycardSessionTapCount = 0; // delta = current - before, polled live
  Timer? _keycardCountPollTimer;
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
  Completer<bool>? _unlockCompleter;
  bool _keepCache = false;
  bool _isCriticalOperation = false; // prevent quit during flash/upload
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

  Future<void> _detectRegionFromIp() async {
    if (_downloadState.selectedRegion != null) return; // already set (e.g. from launch args)
    final region = await Region.detectFromIp();
    if (region != null && mounted && _downloadState.selectedRegion == null) {
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
    _keycardCountPollTimer?.cancel();
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
    if (phase == InstallerPhase.keycardSetup) {
      _onEnterKeycardSetup();
    }
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
      InstallerPhase.healthCheck => _buildHealthCheck(l10n),
      InstallerPhase.batteryRemoval => _buildBatteryRemoval(l10n),
      InstallerPhase.mdbToUms => _buildMdbToUms(l10n),
      InstallerPhase.mdbFlash => _buildMdbFlash(l10n),
      InstallerPhase.scooterPrep => _buildScooterPrep(l10n),
      InstallerPhase.mdbBoot => _buildMdbBoot(l10n),
      InstallerPhase.cbbReconnect => _buildCbbReconnect(l10n),
      InstallerPhase.dbcPrep => _buildDbcPrep(l10n),
      InstallerPhase.dbcFlash => _buildDbcFlash(l10n),
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
            items: Region.all
                .map((r) => DropdownMenuItem(value: r, child: Text(r.name)))
                .toList(),
            onChanged: (r) => setState(() => _downloadState.selectedRegion = r),
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
        await networkService.configureInterface(iface);
      } on NetworkPrivilegeException catch (e) {
        _setStatus(l10n.errorPrefix(e.toString()));
        setState(() { _isProcessing = false; _mdbConnectStarted = false; });
        return;
      }
    }

    _setStatus(l10n.connectingSsh);
    try {
      await _sshService.loadDeviceConfig('assets');
      final info = await _sshService.connectToMdb();
      setState(() => _mdbInfo = info);
      debugPrint('SSH: firmware=${info.firmwareVersion}, serial=${info.serialNumber ?? "unknown"}');

      // Wait for scooter to be in parked state (or user-overridden ready-to-drive)
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
      _setPhase(InstallerPhase.healthCheck);
    } catch (e) {
      _setStatus(l10n.sshConnectionFailed(e.toString()));
      setState(() { _isProcessing = false; _mdbConnectStarted = false; });
    }
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

  bool get _isLibrescootFirmware {
    // /etc/os-release ID= is the authoritative discriminator. Stable
    // LibreScoot ships VERSION_ID=1.0.1, indistinguishable from stock by
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
          for (final phase in MajorStep.dbcFlash.phases) {
            _skippedPhases.add(phase);
          }
          _setPhase(InstallerPhase.bluetoothPairing);
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
      final health = await _sshService.queryHealth();
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

      // Restore radio-gaga config if we backed it up
      if (_radioGagaBackupPath != null) {
        _setStatus(l10n.restoringConfig);
        final restored = await _sshService.restoreRadioGagaConfig(_radioGagaBackupPath!);
        if (restored) {
          debugPrint('UI: radio-gaga config restored to /data/radio-gaga/');
        }
      }

      if (_skipDbcFlash) {
        _setPhase(InstallerPhase.bluetoothPairing);
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
            if (bat) _setPhase(InstallerPhase.dbcPrep);
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
                  if (mounted) _setPhase(InstallerPhase.dbcPrep);
                } else {
                  _setStatus(l10n.cbbNotDetected);
                  setState(() => _isProcessing = false);
                }
              },
              child: Text(l10n.verifyBatteryPresence),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => _setPhase(InstallerPhase.dbcPrep),
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
      _setPhase(InstallerPhase.dbcPrep);
      return;
    }
    _setStatus(l10n.checkingCbbAndBattery);
    var attempts = 0;
    while (attempts < 30) {
      if (await _sshService.isCbbPresent()) {
        _setStatus(l10n.cbbConnected);
        await Future.delayed(const Duration(seconds: 1));
        _setPhase(InstallerPhase.dbcPrep);
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

  Widget _buildDbcPrep(AppLocalizations l10n) {
    if (!_dbcPrepStarted && !_isProcessing) {
      _dbcPrepStarted = true;
      Future.microtask(_uploadDbcFiles);
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.preparingDbcFlash,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          SizedBox(
            width: 500,
            child: Column(
              children: [
                LinearProgressIndicator(value: _progress, minHeight: 8),
                const SizedBox(height: 8),
                Text(_statusMessage,
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
          if (!_isProcessing) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                setState(() { _dbcPrepStarted = false; });
                Future.microtask(() {
                  setState(() => _dbcPrepStarted = true);
                  _uploadDbcFiles();
                });
              },
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retryDbcPrep),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _uploadDbcFiles() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isProcessing = true);
    _setCritical(true);

    if (_isDryRun) {
      _setStatus('[DRY RUN] Simulating DBC upload...');
      await Future.delayed(const Duration(seconds: 1));
      _setPhase(InstallerPhase.dbcFlash);
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
        onProgress: (status, progress) {
          _setStatus(status, progress: progress);
        },
      );

      _setStatus(l10n.startingTrampoline);
      await trampolineService.start();
      _setCritical(false);
      await Future.delayed(const Duration(seconds: 1));
      _setPhase(InstallerPhase.dbcFlash);
    } catch (e) {
      _setCritical(false);
      _setStatus(l10n.uploadError(e.toString()));
      debugPrint('DBC prep error: $e');
      setState(() => _isProcessing = false);
      // Don't reset _dbcPrepStarted: retry button handles that
    }
  }

  bool _dbcFlashWatchStarted = false;
  bool _dbcUsbDisconnected = false;

  Widget _buildDbcFlash(AppLocalizations l10n) {
    // Start watching for USB disconnect and MDB reconnect
    if (!_dbcFlashWatchStarted) {
      _dbcFlashWatchStarted = true;
      _watchDbcFlash();
    }

    if (!_dbcUsbDisconnected) {
      // Step 1: waiting for user to swap cables
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.dbcFlashInProgress,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
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
                style: TextStyle(color: Colors.grey.shade400)),
            const SizedBox(height: 8),
            const CircularProgressIndicator(),
          ],
        ),
      );
    }

    // Step 2: USB disconnected: MDB is flashing autonomously
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.dbcFlashInProgress,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF222222),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.mdbFlashingDbcAutonomously,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(l10n.dbcWillCyclePower,
                    style: TextStyle(color: Colors.orange.shade300, fontSize: 13)),
                const SizedBox(height: 12),
                Text(l10n.watchLightsForProgress,
                    style: TextStyle(color: Colors.grey.shade400)),
                const SizedBox(height: 8),
                _ledSignal(l10n.ledFrontRingPulse, l10n.ledFrontRingPulseMeaning),
                _ledSignal(l10n.ledBlinkerProgress, l10n.ledBlinkerProgressMeaning),
                _ledSignal(l10n.ledBootAmber, l10n.ledBootAmberMeaning),
                _ledSignal(l10n.ledBootGreen, l10n.ledBootGreenMeaning),
                _ledSignal(l10n.ledBootRedError, l10n.ledBootRedMeaning),
                _ledSignal(l10n.ledRearLightSolid, l10n.ledRearLightSolidMeaning),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SizedBox(height: 8),
          Text(l10n.flashingTakesAbout10Min,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          const SizedBox(height: 16),
          Text(_statusMessage.isEmpty
              ? l10n.waitingForMdbToReconnect
              : _statusMessage,
              style: TextStyle(color: Colors.grey.shade400)),
          const SizedBox(height: 8),
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.12),
              border: Border.all(color: Colors.orange.shade700),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.hourglass_top, color: Colors.orange.shade300, size: 20),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(l10n.ledAmberWaitNotice,
                      style: TextStyle(color: Colors.orange.shade100, fontSize: 13)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.icon(
                onPressed: () {
                  _dbcFlashSimulateError = false;
                  _setPhase(InstallerPhase.reconnect);
                },
                icon: const Icon(Icons.check_circle, color: Colors.green),
                label: Text(l10n.ledIsGreen),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () {
                  _dbcFlashSimulateError = true;
                  _setPhase(InstallerPhase.reconnect);
                },
                icon: const Icon(Icons.error, color: Colors.red),
                label: Text(l10n.ledIsRed),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _watchDbcFlash() async {
    // Wait for USB disconnect
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

  Widget _ledSignal(String signal, String meaning) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const SizedBox(width: 8),
          const Icon(Icons.circle, size: 8, color: kAccent),
          const SizedBox(width: 8),
          Expanded(child: Text(signal, style: const TextStyle(fontSize: 13))),
          Text(meaning, style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildReconnect(AppLocalizations l10n) {
    if (!_reconnectStarted && !_isProcessing) {
      _reconnectStarted = true;
      Future.microtask(_verifyDbcFlash);
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.verifyingDbcInstallation,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (_isProcessing)
            const SizedBox(width: 48, height: 48, child: CircularProgressIndicator()),
          const SizedBox(height: 8),
          Text(_statusMessage.isEmpty ? l10n.reconnectUsbToLaptop : _statusMessage,
              style: TextStyle(color: Colors.grey.shade400)),
          if (!_isProcessing) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                setState(() => _reconnectStarted = true);
                Future.microtask(_verifyDbcFlash);
              },
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retryVerification),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _dbcPrepStarted = false;
                  _reconnectStarted = false;
                });
                _setPhase(InstallerPhase.dbcPrep);
              },
              icon: const Icon(Icons.replay),
              label: Text(l10n.retryDbcFlash),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _setPhase(InstallerPhase.bluetoothPairing),
              child: Text(l10n.skipToFinish),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _verifyDbcFlash() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isProcessing = true);

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
      _setPhase(InstallerPhase.bluetoothPairing);
      return;
    }

    _setStatus(l10n.waitingForRndisDevice);
    await _waitForDevice(DeviceMode.ethernet);

    _setStatus(l10n.configuringNetwork);
    final iface = await NetworkService().findLibrescootInterface();
    if (iface != null) {
      try {
        await NetworkService().configureInterface(iface);
      } on NetworkPrivilegeException catch (e) {
        _setStatus(l10n.errorPrefix(e.toString()));
        setState(() { _isProcessing = false; _reconnectStarted = false; });
        return;
      }
    }

    _setStatus(l10n.connectingSsh);
    try {
      await _sshService.connectToMdb();
    } catch (e) {
      _setStatus(l10n.sshConnectionFailed(e.toString()));
      setState(() { _isProcessing = false; _reconnectStarted = false; });
      return;
    }

    // Stop the failure indicators (blinking boot LED, hazards) if any are
    // running. The trampoline drops /data/stop-error-signals.sh for exactly
    // this. Best-effort: if the script isn't there or there's nothing to
    // stop, the helper just no-ops.
    try {
      await _sshService.runCommand(
        '[ -x /data/stop-error-signals.sh ] && /data/stop-error-signals.sh; true',
      );
    } catch (_) {}

    // Poll for trampoline status: the script may still be running when MDB
    // reconnects to RNDIS. Wait up to 5 minutes for a definitive result.
    _setStatus(l10n.readingTrampolineStatus);
    TrampolineStatus status;
    final deadline = DateTime.now().add(const Duration(minutes: 5));
    while (true) {
      status = await _sshService.readTrampolineStatus();
      if (status.result != TrampolineResult.unknown) break;
      if (DateTime.now().isAfter(deadline)) break;
      debugPrint('Trampoline: status still unknown, waiting...');
      await Future.delayed(const Duration(seconds: 5));
      if (!mounted) return;
    }

    // TODO: re-enable after dev
    // await _cleanupMdb();

    // Restart keycard service as the final MDB-side step. Using restart (not
    // start) guarantees LP5662.init() runs and the LED returns to a known
    // state, even if onboot.sh already started the service or the helper
    // above clobbered the PWM regs.
    try {
      await _sshService.runCommand('systemctl restart librescoot-keycard 2>/dev/null || systemctl restart keycard-service 2>/dev/null || true');
    } catch (_) {}

    if (status.result == TrampolineResult.success) {
      _setStatus(l10n.dbcFlashSuccessful);
      await Future.delayed(const Duration(seconds: 2));
      _setPhase(InstallerPhase.bluetoothPairing);
    } else if (status.result == TrampolineResult.error) {
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bluetooth, size: 48, color: Colors.blueAccent),
          const SizedBox(height: 16),
          Text(l10n.bluetoothPairingHeading,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(l10n.bluetoothPairingHint,
              style: TextStyle(color: Colors.grey.shade400)),
          const SizedBox(height: 24),

          if (!_btPairingActive) ...[
            FilledButton.icon(
              onPressed: _startBluetoothPairing,
              icon: const Icon(Icons.bluetooth_searching),
              label: Text(l10n.startPairing),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => _setPhase(InstallerPhase.keycardSetup),
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
      ),
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
    _keycardCountPollTimer?.cancel();
    _keycardCountPollTimer = null;
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
    if (!_isDryRun) {
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
    setState(() {
      _keycardLearning = true;
      _keycardSessionTapCount = 0;
    });
    _keycardCountPollTimer?.cancel();
    if (!_isDryRun) {
      _keycardCountPollTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
        if (!mounted || !_keycardLearning) return;
        try {
          final raw = await _sshService.redisHget('system', 'keycard-authorized-count');
          final cur = int.tryParse(raw ?? '') ?? _keycardAuthorizedCountBefore;
          final delta = cur - _keycardAuthorizedCountBefore;
          if (mounted && delta != _keycardSessionTapCount) {
            setState(() {
              _keycardSessionTapCount = delta;
              _keycardAuthorizedCount = cur;
            });
          }
        } catch (_) {}
      });
    }
  }

  Future<void> _stopKeycardLearning({bool advance = true}) async {
    _keycardCountPollTimer?.cancel();
    _keycardCountPollTimer = null;
    bool registered = _isDryRun;
    int sessionDelta = _isDryRun ? _keycardSessionTapCount : _keycardSessionTapCount;
    if (_isDryRun && sessionDelta == 0) sessionDelta = 1;
    if (!_isDryRun) {
      try {
        await _sshService.redisLpush('scooter:keycard', 'learn:stop');
      } catch (e) {
        debugPrint('UI: failed to stop keycard learning: $e');
      }
      await Future.delayed(const Duration(milliseconds: 300));
      try {
        final raw = await _sshService.redisHget('system', 'keycard-authorized-count');
        final after = int.tryParse(raw ?? '') ?? 0;
        sessionDelta = after - _keycardAuthorizedCountBefore;
        registered = sessionDelta != 0;
        _keycardAuthorizedCount = after;
      } catch (e) {
        debugPrint('UI: failed to read authorized count after learn: $e');
      }
    }
    debugPrint('UI: keycard learning stopped (registered=$registered, sessionDelta=$sessionDelta)');
    if (!mounted) return;
    setState(() {
      _keycardLearning = false;
      _keycardSessionTapCount = sessionDelta < 0 ? 0 : sessionDelta;
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
    if (payload.startsWith('master-learned:')) {
      _keycardShowToast(l10n.keycardMasterStageLearnedToast, Colors.green);
      _keycardRefreshCounts();
      // Auto-advance: master successfully registered.
      Timer(const Duration(milliseconds: 1200), () async {
        if (!mounted) return;
        await _keycardTearDown();
        if (!mounted) return;
        _setPhase(InstallerPhase.finish);
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
      _setPhase(InstallerPhase.finish);
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
      _keycardCountPollTimer?.cancel();
      _keycardCountPollTimer = null;
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
    if (mounted) _setPhase(InstallerPhase.finish);
  }

  Widget _buildKeycardSetup(AppLocalizations l10n) {
    return Center(
      child: ConstrainedBox(
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
          onPressed: () => _setPhase(InstallerPhase.finish),
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
          onPressed: () => _setPhase(InstallerPhase.finish),
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
              title: l10n.insertMainBattery,
              description: l10n.insertMainBatteryDesc,
            ),
            InstructionStep(
              number: 4,
              title: l10n.closeSeatboxAndFootwell,
              description: l10n.closeSeatboxAndFootwellDesc,
            ),
            InstructionStep(
              number: 5,
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
      await _sshService.runCommand(
        'rm -f /data/librescoot-unu-*.sdimg.gz /data/librescoot-unu-*.sdimg.bmap '
        '/data/tiles_*.mbtiles /data/valhalla_tiles_*.tar '
        '/data/trampoline.sh /data/trampoline.log /data/trampoline-status '
        '/data/trampoline-stdout.log /data/test-trampoline-*.sh /data/test-step*.log; '
        'rm -rf /data/fwtools',
      );
      debugPrint('Cleanup: removed trampoline and image files from MDB');
    } catch (e) {
      debugPrint('Cleanup: MDB cleanup failed: $e');
    }
  }

  Future<void> _offerCleanup() async {
    final l10n = AppLocalizations.of(context)!;
    final freed = await _downloadService.deleteCache(_downloadState.items);
    // TODO: re-enable after dev
    // await _cleanupMdb();
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
