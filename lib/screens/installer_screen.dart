import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

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

  // Phase guard flags (prevent auto-start methods from re-firing on rebuild)
  bool _mdbConnectStarted = false;
  bool _healthCheckStarted = false;
  bool _mdbToUmsStarted = false;
  bool _mdbFlashStarted = false;
  bool _mdbBootStarted = false;
  bool _dbcPrepStarted = false;
  bool _reconnectStarted = false;

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
    Future.microtask(_detectResumeState);
  }

  Future<void> _checkElevation() async {
    final elevated = await ElevationService.isElevated();
    if (mounted) setState(() => _isElevated = elevated);
  }

  Future<void> _detectResumeState() async {
    // Give USB detector time to find devices
    await Future.delayed(const Duration(seconds: 2));
    if (_device == null) return; // No device — start from beginning

    if (_device!.mode == DeviceMode.massStorage) {
      // MDB in UMS mode — resume from flash
      _setPhase(InstallerPhase.mdbFlash);
    } else if (_device!.mode == DeviceMode.ethernet) {
      // MDB in RNDIS — check if LibreScoot or stock
      try {
        final iface = await NetworkService().findLibreScootInterface();
        if (iface != null) {
          await NetworkService().configureInterface(iface);
        }
        final info = await _sshService.connectToMdb();
        if (info.firmwareVersion.toLowerCase().contains('librescoot')) {
          _setPhase(InstallerPhase.cbbReconnect);
        }
      } catch (_) {
        // Ignore — stay at welcome
      }
    }
  }

  @override
  void dispose() {
    _deviceSub?.cancel();
    _usbDetector.stopMonitoring();
    super.dispose();
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
    setState(() {
      _statusMessage = message;
      if (progress != null) _progress = progress;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: Column(
        children: [
          if (!_isElevated) _buildElevationWarning(l10n),
          Expanded(
            child: Row(
              children: [
                PhaseSidebar(
                  currentPhase: _currentPhase,
                  completedPhases: _completedPhases,
                ),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: _buildPhaseContent(l10n),
                        ),
                      ),
                      _buildStatusBar(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
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

  Widget _buildStatusBar() {
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
        ],
      ),
    );
  }

  Widget _buildPhaseContent(AppLocalizations l10n) {
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
      InstallerPhase.finish => _buildFinish(l10n),
    };
  }

  Widget _buildWelcome(AppLocalizations l10n) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.welcomeHeading,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(l10n.welcomeSubheading,
              style: TextStyle(color: Colors.grey.shade400)),
          const SizedBox(height: 24),

          // Prerequisites
          Text(l10n.whatYouNeed, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          _prerequisite(l10n.prerequisiteScrewdriverPH2),
          _prerequisite(l10n.prerequisiteScrewdriverFlat),
          _prerequisite(l10n.prerequisiteUsbCable),
          _prerequisite(l10n.prerequisiteTime),
          const SizedBox(height: 24),

          // Channel selection
          Text(l10n.firmwareChannel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          SegmentedButton<DownloadChannel>(
            segments: [
              ButtonSegment(value: DownloadChannel.stable, label: Text(l10n.channelStable)),
              ButtonSegment(value: DownloadChannel.testing, label: Text(l10n.channelTesting)),
              ButtonSegment(value: DownloadChannel.nightly, label: Text(l10n.channelNightly)),
            ],
            selected: {_downloadState.channel},
            onSelectionChanged: (selected) {
              setState(() => _downloadState.channel = selected.first);
            },
          ),
          const SizedBox(height: 24),

          // Online/offline
          Text(l10n.connectivity, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          SwitchListTile(
            title: Text(l10n.scooterOffline),
            subtitle: Text(l10n.scooterOfflineSubtitle),
            value: _downloadState.isOffline,
            onChanged: (v) => setState(() {
              _downloadState.isOffline = v;
              _downloadState.wantsOfflineMaps = v;
            }),
          ),
          if (!_downloadState.isOffline)
            SwitchListTile(
              title: Text(l10n.downloadOfflineMaps),
              subtitle: Text(l10n.downloadOfflineMapsSubtitle),
              value: _downloadState.wantsOfflineMaps,
              onChanged: (v) => setState(() => _downloadState.wantsOfflineMaps = v),
            ),

          // Region selection
          if (_downloadState.wantsOfflineMaps) ...[
            const SizedBox(height: 16),
            Text(l10n.region, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
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
          ],

          const SizedBox(height: 24),

          // Download progress
          if (_downloadState.items.isNotEmpty)
            DownloadProgressWidget(items: _downloadState.items),

          const SizedBox(height: 24),

          // Start button
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _isProcessing ? null : _startDownloadsAndContinue,
              icon: const Icon(Icons.arrow_forward),
              label: Text(l10n.startInstallation),
            ),
          ),
        ],
      ),
    );
  }

  Widget _prerequisite(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Icon(Icons.check_box_outline_blank, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(color: Colors.grey.shade300)),
        ],
      ),
    );
  }

  Future<void> _startDownloadsAndContinue() async {
    final l10n = AppLocalizations.of(context)!;
    if (_downloadState.wantsOfflineMaps && _downloadState.selectedRegion == null) {
      _setStatus(l10n.selectRegionError);
      return;
    }

    setState(() => _isProcessing = true);
    _setStatus(l10n.resolvingReleases);

    try {
      final items = await _downloadService.buildDownloadQueue(
        channel: _downloadState.channel,
        region: _downloadState.selectedRegion,
        wantsOfflineMaps: _downloadState.wantsOfflineMaps,
      );
      setState(() => _downloadState.items = items);

      // Start downloads in background
      _downloadInBackground();

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
    return SingleChildScrollView(
      child: Column(
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
            imagePlaceholder: l10n.removeFootwellCoverImage,
          ),
          InstructionStep(
            number: 2,
            title: l10n.unscrewUsbCable,
            description: l10n.unscrewUsbCableDesc,
            imagePlaceholder: l10n.unscrewUsbCableImage,
          ),
          InstructionStep(
            number: 3,
            title: l10n.connectLaptopUsb,
            description: l10n.connectLaptopUsbDesc,
          ),
          const SizedBox(height: 24),
          if (_downloadState.items.isNotEmpty)
            DownloadProgressWidget(items: _downloadState.items),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () => _setPhase(InstallerPhase.mdbConnect),
              icon: const Icon(Icons.arrow_forward),
              label: Text(l10n.doneDetectDevice),
            ),
          ),
        ],
      ),
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
        ],
      ),
    );
  }

  Future<void> _autoConnectMdb() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isProcessing = true);

    _setStatus(l10n.waitingForRndis);
    await _waitForDevice(DeviceMode.ethernet);

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
      await _sshService.connectToMdb();
      _setStatus(l10n.connected);
      setState(() => _isProcessing = false);
      _setPhase(InstallerPhase.healthCheck);
    } catch (e) {
      _setStatus(l10n.sshConnectionFailed(e.toString()));
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _waitForDevice(DeviceMode mode) async {
    while (_device?.mode != mode) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
    }
  }

  Widget _buildHealthCheck(AppLocalizations l10n) {
    if (!_healthCheckStarted && _scooterHealth == null && !_isProcessing) {
      _healthCheckStarted = true;
      Future.microtask(_runHealthCheck);
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.healthCheckHeading,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(l10n.verifyingReadiness,
              style: TextStyle(color: Colors.grey.shade400)),
          const SizedBox(height: 24),
          if (_scooterHealth != null)
            SizedBox(width: 400, child: HealthCheckPanel(health: _scooterHealth!)),
          const SizedBox(height: 24),
          if (_scooterHealth != null && _scooterHealth!.allOk)
            FilledButton.icon(
              onPressed: () => _setPhase(InstallerPhase.batteryRemoval),
              icon: const Icon(Icons.arrow_forward),
              label: Text(l10n.continueButton),
            ),
          if (_scooterHealth != null && !_scooterHealth!.allOk)
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
        ],
      ),
    );
  }

  Future<void> _runHealthCheck() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isProcessing = true);
    try {
      final health = await _sshService.queryHealth();
      setState(() => _scooterHealth = health);
    } catch (e) {
      _setStatus(l10n.healthCheckFailed(e.toString()));
    } finally {
      setState(() => _isProcessing = false);
    }
  }

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
        ],
      ),
    );
  }

  Future<void> _configureMdbUms() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isProcessing = true);
    try {
      _setStatus(l10n.uploadingBootloaderTools);
      await _sshService.configureMassStorageMode();
      _setStatus(l10n.rebootingMdbUms);
      await _sshService.reboot();
      _setStatus(l10n.waitingForUmsDevice);
      await _waitForDevice(DeviceMode.massStorage);
      _setPhase(InstallerPhase.mdbFlash);
    } catch (e) {
      _setStatus(l10n.errorPrefix(e.toString()));
      setState(() => _isProcessing = false);
    }
  }

  Widget _buildMdbFlash(AppLocalizations l10n) {
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
        ],
      ),
    );
  }

  Future<void> _flashMdb() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isProcessing = true);

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
      if (_device?.path == null || _device!.path.isEmpty) {
        _setStatus(l10n.noDevicePath);
        setState(() => _isProcessing = false);
        return;
      }

      final flashService = FlashService();
      await flashService.writeTwoPhase(
        mdbItem.localPath!,
        _device!.path,
        onProgress: (progress, message) {
          _setStatus(message, progress: progress);
        },
      );

      _setStatus(l10n.mdbFlashComplete);
      await Future.delayed(const Duration(seconds: 1));
      _setPhase(InstallerPhase.scooterPrep);
    } catch (e) {
      _setStatus(l10n.flashError(e.toString()));
      setState(() => _isProcessing = false);
    }
  }

  Widget _buildScooterPrep(AppLocalizations l10n) {
    return SingleChildScrollView(
      child: Column(
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
          ),
          InstructionStep(
            number: 2,
            title: l10n.disconnectAuxPole,
            description: l10n.disconnectAuxPoleDesc,
            isWarning: true,
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
      ),
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
        ],
      ),
    );
  }

  Future<void> _waitForMdbBoot() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isProcessing = true);

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
      _setPhase(InstallerPhase.cbbReconnect);
    } catch (e) {
      _setStatus(l10n.sshReconnectionFailed(e.toString()));
    }
    setState(() => _isProcessing = false);
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
  Widget _buildCbbReconnect(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.reconnectCbbHeading,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          InstructionStep(
            number: 1,
            title: l10n.reconnectCbb,
            description: l10n.reconnectCbbDesc,
          ),
          const SizedBox(height: 16),
          if (_isProcessing) ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 8),
            Text(_statusMessage, style: TextStyle(color: Colors.grey.shade400)),
          ] else
            FilledButton(
              onPressed: _waitForCbb,
              child: Text(l10n.verifyCbbConnection),
            ),
        ],
      ),
    );
  }

  Future<void> _waitForCbb() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isProcessing = true);
    _setStatus(l10n.checkingCbb);
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
    setState(() => _isProcessing = false);
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
            width: 400,
            child: Column(
              children: [
                LinearProgressIndicator(value: _progress, minHeight: 8),
                const SizedBox(height: 8),
                Text(_statusMessage, style: TextStyle(color: Colors.grey.shade400)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadDbcFiles() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isProcessing = true);

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

      await trampolineService.uploadAll(
        dbcImageLocalPath: dbcItem!.localPath!,
        osmTilesLocalPath: osmItem?.localPath,
        valhallaTilesLocalPath: valhallaItem?.localPath,
        region: _downloadState.selectedRegion,
        onProgress: (status, progress) {
          _setStatus(status, progress: progress);
        },
      );

      _setStatus(l10n.startingTrampoline);
      await trampolineService.start();
      await Future.delayed(const Duration(seconds: 1));
      _setPhase(InstallerPhase.dbcFlash);
    } catch (e) {
      _setStatus(l10n.uploadError(e.toString()));
      setState(() => _isProcessing = false);
    }
  }

  Widget _buildDbcFlash(AppLocalizations l10n) {
    return SingleChildScrollView(
      child: Center(
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
                  Text(l10n.watchLightsForProgress,
                      style: TextStyle(color: Colors.grey.shade400)),
                  const SizedBox(height: 8),
                  _ledSignal(l10n.ledFrontRingOn, l10n.ledFrontRingMeaning),
                  _ledSignal(l10n.ledPositionLightsOn, l10n.ledPositionLightsMeaning),
                  _ledSignal(l10n.ledBootGreen, l10n.ledBootGreenMeaning),
                  _ledSignal(l10n.ledHazardFlashers, l10n.ledHazardFlashersMeaning),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _setPhase(InstallerPhase.reconnect),
              icon: const Icon(Icons.arrow_forward),
              label: Text(l10n.bootLedGreenReconnect),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _setPhase(InstallerPhase.reconnect),
              icon: const Icon(Icons.warning, color: Colors.orange),
              label: Text(l10n.hazardFlashersCheckError),
            ),
          ],
        ),
      ),
    );
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
        ],
      ),
    );
  }

  Future<void> _verifyDbcFlash() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isProcessing = true);

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
      setState(() => _isProcessing = false);
      return;
    }

    _setStatus(l10n.readingTrampolineStatus);
    final status = await _sshService.readTrampolineStatus();

    if (status.result == TrampolineResult.success) {
      _setStatus(l10n.dbcFlashSuccessful);
      await Future.delayed(const Duration(seconds: 2));
      _setPhase(InstallerPhase.finish);
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

  Widget _buildFinish(AppLocalizations l10n) {
    return SingleChildScrollView(
      child: Center(
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
            if (_downloadState.items.isNotEmpty)
              OutlinedButton.icon(
                onPressed: _offerCleanup,
                icon: const Icon(Icons.delete_outline),
                label: Text(l10n.deleteCachedDownloads(_totalCacheSizeMb())),
              ),
          ],
        ),
      ),
    );
  }

  String _totalCacheSizeMb() {
    final total = _downloadState.items.fold<int>(0, (sum, i) => sum + i.expectedSize);
    return (total / 1024 / 1024).toStringAsFixed(0);
  }

  Future<void> _offerCleanup() async {
    final l10n = AppLocalizations.of(context)!;
    final freed = await _downloadService.deleteCache(_downloadState.items);
    if (mounted) {
      _setStatus(l10n.deletedCache((freed / 1024 / 1024).toStringAsFixed(0)));
    }
  }
}
