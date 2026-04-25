import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart' show LaunchArgs, installerLog, launchArgs;
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
  bool _keycardLearning = false;
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
    _checkElevation();
    _applyLaunchArgs();
    Future.microtask(_detectResumeState);
    _resolveAvailableChannels();
    _detectRegionFromIp();
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
    if (args.autoStart) {
      // Auto-start downloads after channels resolve
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _currentPhase == InstallerPhase.welcome) {
          _startDownloadsAndContinue();
        }
      });
    }
  }

  Future<void> _checkElevation() async {
    final elevated = await ElevationService.isElevated();
    if (mounted) setState(() => _isElevated = elevated);
  }

  Future<void> _detectResumeState() async {
    // Detection happens in _autoConnectMdb — no early jumping here.
  }

  @override
  void dispose() {
    _deviceSub?.cancel();
    _usbDetector.stopMonitoring();
    _blePinPollTimer?.cancel();
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
          // Default to best available: stable > testing > nightly
          if (channels.isNotEmpty) {
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
    setState(() {
      _completedPhases.add(_currentPhase);
      _currentPhase = phase;
      _statusMessage = '';
      _progress = 0.0;
      _isProcessing = false;
    });
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
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Log & Debug Shell'),
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
                        decoration: const InputDecoration(
                          hintText: 'Run a command in the installer context...',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
              child: const Text('Copy to clipboard'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
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
      body: Column(
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
                          builder: (context, constraints) => SingleChildScrollView(
                            padding: const EdgeInsets.all(32),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minHeight: constraints.maxHeight - 64),
                              child: Center(child: _buildPhaseContent(l10n)),
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
      color: const Color(0xFF1A1A2E),
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
                color: Colors.tealAccent,
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
            const Icon(Icons.open_in_new, size: 48, color: Colors.tealAccent),
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

        // Prerequisites (2x2 grid)
        Text(l10n.whatYouNeed, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _prerequisite(prerequisites[0], 0)),
            const SizedBox(width: 8),
            Expanded(child: _prerequisite(prerequisites[1], 1)),
          ],
        ),
        Row(
          children: [
            Expanded(child: _prerequisite(prerequisites[2], 2)),
            const SizedBox(width: 8),
            Expanded(child: _prerequisite(prerequisites[3], 3)),
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
            Row(
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

        // Start button (with elevation hint on macOS/Linux if not elevated)
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _isProcessing ||
                    (_downloadState.wantsOfflineMaps && _downloadState.selectedRegion == null)
                ? null
                : _startDownloadsAndContinue,
            icon: const Icon(Icons.arrow_forward),
            label: Text(l10n.startInstallation),
          ),
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
            color: selected ? Colors.tealAccent : Colors.grey.shade700,
            width: selected ? 2 : 1,
          ),
          color: selected
              ? Colors.tealAccent.withValues(alpha: 0.08)
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
                    color: selected ? Colors.tealAccent : null,
                  )),
              const SizedBox(height: 4),
              Text(description,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
              const SizedBox(height: 8),
              Text(
                releaseDate != null
                    ? l10n.channelLatest(releaseDate)
                    : l10n.channelNoReleases,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _prerequisite(String text, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: () => setState(() => _prerequisiteChecks[index] = !_prerequisiteChecks[index]),
        borderRadius: BorderRadius.circular(4),
        child: Row(
          children: [
            Icon(
              _prerequisiteChecks[index] ? Icons.check_box : Icons.check_box_outline_blank,
              size: 18,
              color: _prerequisiteChecks[index] ? Colors.tealAccent : Colors.grey,
            ),
            const SizedBox(width: 8),
            Text(text, style: TextStyle(
              color: _prerequisiteChecks[index] ? Colors.grey.shade200 : Colors.grey.shade400,
            )),
          ],
        ),
      ),
    );
  }

  Future<void> _startDownloadsAndContinue() async {
    final l10n = AppLocalizations.of(context)!;
    if (_downloadState.wantsOfflineMaps && _downloadState.selectedRegion == null && !launchArgs.hasLocalImages) {
      _setStatus(l10n.selectRegionError);
      return;
    }

    setState(() => _isProcessing = true);

    // On macOS, no self-elevation needed — diskwriter handles authorization
    // via AuthorizationCreate + authopen when raw disk access is needed.
    // On Windows, elevation is handled by UAC at app startup.
    // On Linux, the app should be launched with sudo by the user.

    try {
      if (launchArgs.hasLocalImages) {
        // Use local images instead of downloading
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

        // Start downloads in background
        _downloadInBackground();
      }

      // Move to next phase immediately
      _setPhase(InstallerPhase.physicalPrep);
    } catch (e) {
      _setStatus(l10n.errorPrefix(e.toString()));
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _downloadInBackground() async {
    try {
      await _downloadService.downloadAll(
        _downloadState.items,
        onProgress: (item, bytes, total) {
          if (mounted) setState(() {}); // Trigger rebuild to update progress
        },
      );
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

  Future<void> _autoConnectMdb() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isProcessing = true);

    if (_isDryRun) {
      _setStatus('[DRY RUN] Loading auth assets...');
      try {
        await _sshService.loadDeviceConfig('assets');
        _setStatus('[DRY RUN] Auth loaded, simulating MDB v1.15.0 connection...');
      } catch (e) {
        _setStatus('[DRY RUN] Auth load failed: $e — continuing anyway');
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
      // Device is already in UMS mode — skip ahead to flash
      _setStatus(l10n.mdbDetectedUmsSkipping);
      await Future.delayed(const Duration(seconds: 1));
      _setPhase(InstallerPhase.mdbFlash);
      return;
    }

    // RNDIS mode — normal flow
    if (Platform.isWindows) {
      _setStatus(l10n.checkingRndisDriver);
      if (!await DriverService.isDriverInstalled()) {
        _setStatus(l10n.installingRndisDriver);
        await DriverService.installDriver();
      }
    }

    _setStatus(l10n.configuringNetwork);
    final networkService = NetworkService();
    final iface = await networkService.findLibreScootInterface();
    if (iface != null) {
      await networkService.configureInterface(iface);
    }

    _setStatus(l10n.connectingSsh);
    try {
      await _sshService.loadDeviceConfig('assets');
      final info = await _sshService.connectToMdb();
      setState(() => _mdbInfo = info);
      debugPrint('SSH: firmware=${info.firmwareVersion}, serial=${info.serialNumber ?? "unknown"}');

      // Wait for scooter to be unlocked (parked state) before proceeding
      _setStatus(l10n.waitingForUnlock);
      final state = await _sshService.getVehicleState();
      debugPrint('SSH: vehicle state = $state');
      if (state != 'parked') {
        final reached = await _sshService.waitForVehicleState('parked');
        if (!reached) {
          _setStatus(l10n.unlockTimeout);
          setState(() { _isProcessing = false; _mdbConnectStarted = false; });
          return;
        }
      }
      debugPrint('SSH: scooter is unlocked (parked), locking...');

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

      final iface = await NetworkService().findLibreScootInterface();
      if (iface != null) await NetworkService().configureInterface(iface);

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

  bool get _isLibreScootFirmware {
    final v = _mdbInfo?.firmwareVersion ?? '';
    return v.contains('librescoot') || v.contains('nightly') ||
        v.contains('testing') || v.contains('stable');
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

          // LibreScoot detected — offer to skip MDB reflash
          if (_scooterHealth != null && _isLibreScootFirmware) ...[
            const SizedBox(height: 24),
            Container(
              width: 400,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.libreScootFirmwareDetected,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.tealAccent)),
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
            const Icon(Icons.check_circle, size: 48, color: Colors.tealAccent),
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
    while (await _sshService.isBatteryPresent()) {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
    }

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
          _setStatus('fw_setenv failed — bootcmd is still: ${bootcmd.trim()}');
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

      // UMS didn't appear — show retry/log buttons
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
    if (mdbItem == null || !mdbItem.isComplete) {
      _setStatus(l10n.waitingForMdbFirmware);
      while (mdbItem == null || !mdbItem.isComplete) {
        await Future.delayed(const Duration(seconds: 1));
        if (!mounted) return;
        mdbItem = _downloadState.itemOfType(DownloadItemType.mdbFirmware);
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

      final flashService = FlashService();
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
      // Diagnose: is the device still present and what state is it in?
      String diagnosis = e.toString();
      if (_device == null) {
        diagnosis += '\n\nDevice disconnected. Reconnect USB and retry.';
      } else if (_device!.mode == DeviceMode.massStorage) {
        final devName = _device!.path.split('/').last;
        final sizeCheck = await Process.run('cat', ['/sys/block/$devName/size']);
        final size = int.tryParse(sizeCheck.stdout.toString().trim()) ?? 0;
        if (size == 0) {
          diagnosis += '\n\nDevice is connected but reports 0 size. '
              'Power cycle the board and retry.';
        } else {
          diagnosis += '\n\nDevice is still available — you can retry.';
        }
      } else {
        diagnosis += '\n\nDevice is in ${_device!.mode.name} mode, not mass storage. '
            'Power cycle the board to re-enter UMS mode.';
      }
      _setStatus(diagnosis);
      setState(() => _isProcessing = false);
      if (await _shouldRetry('mdbFlash')) {
        setState(() => _mdbFlashStarted = false);
      }
    }
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

    var stableCount = 0;
    while (stableCount < 10) {
      final reachable = await _pingMdb();
      if (reachable) {
        stableCount++;
        _setStatus(l10n.pingStable(stableCount));
      } else {
        stableCount = 0;
        _setStatus(l10n.waitingStableConnection);
      }
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
    }

    _setStatus(l10n.reconnectingSsh);
    final iface = await NetworkService().findLibreScootInterface();
    if (iface != null) {
      await NetworkService().configureInterface(iface);
    }
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
    for (var i = 0; i < _cbbPollIterations; i++) {
      if (!mounted) return false;
      if (await _sshService.isCbbPresent()) return true;
      if (!mounted) return false;
      if (i + 1 == _cbbNoticeAfterIterations && !_cbbWaitNoticeShown) {
        setState(() => _cbbWaitNoticeShown = true);
      }
      _setStatus(l10n.waitingForCbb(i + 1));
      await Future.delayed(const Duration(seconds: 2));
    }
    return false;
  }

  Widget _buildCbbReconnect(AppLocalizations l10n) {
    // Auto-check CBB on enter — poll for up to 3 minutes
    if (!_cbbAutoCheckStarted && !_isProcessing) {
      _cbbAutoCheckStarted = true;
      Future.microtask(() async {
        if (_isDryRun) return;
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
          final bat = await _sshService.isBatteryPresent();
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
                const Icon(Icons.check_circle, size: 16, color: Colors.tealAccent),
                const SizedBox(width: 8),
                Text(l10n.cbbDetected, style: const TextStyle(color: Colors.tealAccent, fontSize: 13)),
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
                          const Icon(Icons.check_circle, size: 16, color: Colors.tealAccent),
                          const SizedBox(width: 8),
                          Text(l10n.batteryDetected, style: const TextStyle(color: Colors.tealAccent, fontSize: 13)),
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
                final bat = await _sshService.isBatteryPresent();
                if (bat) {
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
      // Don't reset _dbcPrepStarted — retry button handles that
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

    // Step 2: USB disconnected — MDB is flashing autonomously
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

    // Poll for MDB reconnect every 10s — only while still on dbcFlash phase
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
          const Icon(Icons.circle, size: 8, color: Colors.tealAccent),
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
    final iface = await NetworkService().findLibreScootInterface();
    if (iface != null) {
      await NetworkService().configureInterface(iface);
    }

    _setStatus(l10n.connectingSsh);
    try {
      await _sshService.connectToMdb();
    } catch (e) {
      _setStatus(l10n.sshConnectionFailed(e.toString()));
      setState(() { _isProcessing = false; _reconnectStarted = false; });
      return;
    }

    // Poll for trampoline status — the script may still be running when MDB
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

    // Restart keycard service
    try {
      await _sshService.runCommand('systemctl start librescoot-keycard 2>/dev/null || systemctl start keycard-service 2>/dev/null || true');
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
          // PIN cleared — pairing completed for this device
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

  Future<void> _startKeycardLearning() async {
    try {
      await _sshService.redisLpush('scooter:keycard', 'set-master:NONE');
      await _sshService.redisLpush('scooter:keycard', 'learn:start');
      debugPrint('UI: keycard learning started (no master)');
      setState(() => _keycardLearning = true);
    } catch (e) {
      debugPrint('UI: failed to start keycard learning: $e');
      _setStatus('Failed to start keycard learning: $e');
    }
  }

  Future<void> _stopKeycardLearning() async {
    try {
      await _sshService.redisLpush('scooter:keycard', 'learn:stop');
      debugPrint('UI: keycard learning stopped');
    } catch (e) {
      debugPrint('UI: failed to stop keycard learning: $e');
    }
    setState(() => _keycardLearning = false);
  }

  Widget _buildKeycardSetup(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.nfc, size: 48, color: Colors.tealAccent),
          const SizedBox(height: 16),
          Text(l10n.keycardLearningHeading,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          SizedBox(
            width: 400,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.keycardMasterHeading,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade200)),
                const SizedBox(height: 8),
                Text(l10n.keycardLearningStep1,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade300)),
                const SizedBox(height: 4),
                Text(l10n.keycardLearningStep2,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade300)),
                const SizedBox(height: 4),
                Text(l10n.keycardLearningStep3,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade300)),
                const SizedBox(height: 4),
                Text(l10n.keycardLearningStep4,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade300)),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                Text(l10n.keycardNoMasterHeading,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade200)),
                const SizedBox(height: 8),
                Text(l10n.keycardNoMasterHint,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade300)),
                const SizedBox(height: 16),
                if (!_keycardLearning)
                  OutlinedButton.icon(
                    onPressed: _sshService.isConnected ? _startKeycardLearning : null,
                    icon: const Icon(Icons.nfc, size: 18),
                    label: Text(l10n.keycardStartLearning),
                  )
                else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.tealAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.contactless, size: 28, color: Colors.tealAccent),
                        const SizedBox(height: 8),
                        Text(l10n.keycardLearningActive,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.tealAccent)),
                        const SizedBox(height: 4),
                        Text(l10n.keycardLearningActiveHint,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _stopKeycardLearning,
                    icon: const Icon(Icons.check, size: 18),
                    label: Text(l10n.keycardStopLearning),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () => _setPhase(InstallerPhase.finish),
                child: Text(l10n.skipKeycardSetup),
              ),
              const SizedBox(width: 16),
              FilledButton.icon(
                onPressed: () => _setPhase(InstallerPhase.finish),
                icon: const Icon(Icons.arrow_forward),
                label: Text(l10n.continueButton),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFinish(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.celebration, size: 64, color: Colors.tealAccent),
          const SizedBox(height: 16),
          Text(l10n.welcomeToLibreScoot,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.tealAccent)),
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
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.keepCachedDownloads),
            subtitle: Text('${_totalCacheSizeMb()} MB on disk',
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
    );
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
