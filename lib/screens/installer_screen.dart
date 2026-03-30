import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../models/download_state.dart';
import '../models/installer_phase.dart';
import '../models/region.dart';
import '../models/scooter_health.dart';
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
  }

  Future<void> _checkElevation() async {
    final elevated = await ElevationService.isElevated();
    if (mounted) setState(() => _isElevated = elevated);
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
    return Scaffold(
      body: Column(
        children: [
          if (!_isElevated) _buildElevationWarning(),
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
                          child: _buildPhaseContent(),
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

  Widget _buildElevationWarning() {
    return Container(
      width: double.infinity,
      color: Colors.orange.shade900,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: const Row(
        children: [
          Icon(Icons.warning, color: Colors.orange, size: 16),
          SizedBox(width: 8),
          Text(
            'Running without administrator privileges. Some operations may fail.',
            style: TextStyle(color: Colors.orange, fontSize: 12),
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

  Widget _buildPhaseContent() {
    return switch (_currentPhase) {
      InstallerPhase.welcome => _buildWelcome(),
      InstallerPhase.physicalPrep => _buildPhysicalPrep(),
      InstallerPhase.mdbConnect => _buildMdbConnect(),
      InstallerPhase.healthCheck => _buildHealthCheck(),
      InstallerPhase.batteryRemoval => _buildBatteryRemoval(),
      InstallerPhase.mdbToUms => _buildMdbToUms(),
      InstallerPhase.mdbFlash => _buildMdbFlash(),
      InstallerPhase.scooterPrep => _buildScooterPrep(),
      InstallerPhase.mdbBoot => _buildMdbBoot(),
      InstallerPhase.cbbReconnect => _buildCbbReconnect(),
      InstallerPhase.dbcPrep => _buildDbcPrep(),
      InstallerPhase.dbcFlash => _buildDbcFlash(),
      InstallerPhase.reconnect => _buildReconnect(),
      InstallerPhase.finish => _buildFinish(),
    };
  }

  Widget _phasePlaceholder(String extra) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_currentPhase.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(_currentPhase.description, style: TextStyle(color: Colors.grey.shade400)),
          const SizedBox(height: 16),
          Text(extra, style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildWelcome() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Welcome to LibreScoot Installer',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('This wizard will guide you through installing LibreScoot firmware on your scooter.',
              style: TextStyle(color: Colors.grey.shade400)),
          const SizedBox(height: 24),

          // Prerequisites
          const Text('What you need:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          _prerequisite('PH2 or H4 screwdriver for footwell screws'),
          _prerequisite('Flat head or PH1 screwdriver for USB cable'),
          _prerequisite('USB cable (laptop to Mini-B)'),
          _prerequisite('About 45 minutes'),
          const SizedBox(height: 24),

          // Channel selection
          const Text('Firmware Channel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          SegmentedButton<DownloadChannel>(
            segments: const [
              ButtonSegment(value: DownloadChannel.stable, label: Text('Stable')),
              ButtonSegment(value: DownloadChannel.testing, label: Text('Testing')),
              ButtonSegment(value: DownloadChannel.nightly, label: Text('Nightly')),
            ],
            selected: {_downloadState.channel},
            onSelectionChanged: (selected) {
              setState(() => _downloadState.channel = selected.first);
            },
          ),
          const SizedBox(height: 24),

          // Online/offline
          const Text('Connectivity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Scooter will be offline'),
            subtitle: const Text('Most scooters are offline — download maps for navigation'),
            value: _downloadState.isOffline,
            onChanged: (v) => setState(() {
              _downloadState.isOffline = v;
              _downloadState.wantsOfflineMaps = v;
            }),
          ),
          if (!_downloadState.isOffline)
            SwitchListTile(
              title: const Text('Download offline maps anyway'),
              subtitle: const Text('Faster and more reliable navigation'),
              value: _downloadState.wantsOfflineMaps,
              onChanged: (v) => setState(() => _downloadState.wantsOfflineMaps = v),
            ),

          // Region selection
          if (_downloadState.wantsOfflineMaps) ...[
            const SizedBox(height: 16),
            const Text('Region', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            DropdownButtonFormField<Region>(
              initialValue: _downloadState.selectedRegion,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Select your region',
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
              label: const Text('Start Installation'),
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
    if (_downloadState.wantsOfflineMaps && _downloadState.selectedRegion == null) {
      _setStatus('Please select a region for offline maps');
      return;
    }

    setState(() => _isProcessing = true);
    _setStatus('Resolving releases...');

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
      _setStatus('Error: $e');
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
  Widget _buildPhysicalPrep() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Physical Preparation',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Prepare your scooter for USB connection.',
              style: TextStyle(color: Colors.grey.shade400)),
          const SizedBox(height: 24),
          const InstructionStep(
            number: 1,
            title: 'Remove footwell cover',
            description: 'Use a PH2 or H4 screwdriver to remove the footwell cover screws.',
            imagePlaceholder: '[Photo: footwell cover with screw locations highlighted]',
          ),
          const InstructionStep(
            number: 2,
            title: 'Unscrew USB cable from MDB',
            description: 'Disconnect the internal DBC USB cable from the MDB board. Use a flat head or PH1 screwdriver.',
            imagePlaceholder: '[Photo: USB Mini-B connector on MDB, close-up]',
          ),
          const InstructionStep(
            number: 3,
            title: 'Connect laptop USB cable',
            description: 'Plug your USB cable into the MDB port and connect the other end to your laptop.',
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
              label: const Text('Done — Detect Device'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMdbConnect() {
    if (!_mdbConnectStarted && !_isProcessing) {
      _mdbConnectStarted = true;
      Future.microtask(_autoConnectMdb);
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Connecting to MDB',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (_isProcessing) ...[
            const SizedBox(width: 48, height: 48, child: CircularProgressIndicator()),
            const SizedBox(height: 16),
          ],
          Text(_statusMessage.isEmpty ? 'Waiting for USB device...' : _statusMessage,
              style: TextStyle(color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  Future<void> _autoConnectMdb() async {
    setState(() => _isProcessing = true);

    _setStatus('Waiting for RNDIS device (VID 0525:A4A2)...');
    await _waitForDevice(DeviceMode.ethernet);

    if (Platform.isWindows) {
      _setStatus('Checking RNDIS driver...');
      if (!await DriverService.isDriverInstalled()) {
        _setStatus('Installing RNDIS driver...');
        await DriverService.installDriver();
      }
    }

    _setStatus('Configuring network...');
    final networkService = NetworkService();
    final iface = await networkService.findLibreScootInterface();
    if (iface != null) {
      await networkService.configureInterface(iface);
    }

    _setStatus('Connecting via SSH...');
    try {
      await _sshService.connectToMdb();
      _setStatus('Connected!');
      setState(() => _isProcessing = false);
      _setPhase(InstallerPhase.healthCheck);
    } catch (e) {
      _setStatus('SSH connection failed: $e. Check cable and retry.');
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _waitForDevice(DeviceMode mode) async {
    while (_device?.mode != mode) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
    }
  }

  Widget _buildHealthCheck() {
    if (!_healthCheckStarted && _scooterHealth == null && !_isProcessing) {
      _healthCheckStarted = true;
      Future.microtask(_runHealthCheck);
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Health Check',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Verifying scooter readiness...',
              style: TextStyle(color: Colors.grey.shade400)),
          const SizedBox(height: 24),
          if (_scooterHealth != null)
            SizedBox(width: 400, child: HealthCheckPanel(health: _scooterHealth!)),
          const SizedBox(height: 24),
          if (_scooterHealth != null && _scooterHealth!.allOk)
            FilledButton.icon(
              onPressed: () => _setPhase(InstallerPhase.batteryRemoval),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Continue'),
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
              label: const Text('Retry'),
            ),
        ],
      ),
    );
  }

  Future<void> _runHealthCheck() async {
    setState(() => _isProcessing = true);
    try {
      final health = await _sshService.queryHealth();
      setState(() => _scooterHealth = health);
    } catch (e) {
      _setStatus('Health check failed: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Widget _buildBatteryRemoval() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Battery Removal',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          if (_scooterHealth?.batteryPresent == true) ...[
            const InstructionStep(
              number: 1,
              title: 'Seatbox is opening...',
              description: 'The seatbox will open automatically.',
            ),
            const InstructionStep(
              number: 2,
              title: 'Remove the main battery',
              description: 'Lift the main battery (Fahrakku) out of the seatbox.',
            ),
            const SizedBox(height: 16),
            if (!_isProcessing)
              FilledButton(
                onPressed: _openSeatboxAndWaitForBattery,
                child: const Text('Open Seatbox'),
              ),
            if (_isProcessing) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 8),
              Text(_statusMessage, style: TextStyle(color: Colors.grey.shade400)),
            ],
          ] else ...[
            const Icon(Icons.check_circle, size: 48, color: Colors.tealAccent),
            const SizedBox(height: 16),
            const Text('Main battery already removed'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _setPhase(InstallerPhase.mdbToUms),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Continue'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openSeatboxAndWaitForBattery() async {
    setState(() => _isProcessing = true);
    _setStatus('Opening seatbox...');
    await _sshService.openSeatbox();

    _setStatus('Waiting for battery removal...');
    while (await _sshService.isBatteryPresent()) {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
    }
    _setStatus('Battery removed!');
    setState(() {
      _scooterHealth?.batteryPresent = false;
      _isProcessing = false;
    });
    _setPhase(InstallerPhase.mdbToUms);
  }
  Widget _buildMdbToUms() => _phasePlaceholder('TODO: fw_setenv + reboot');
  Widget _buildMdbFlash() => _phasePlaceholder('TODO: two-phase dd');
  Widget _buildScooterPrep() => _phasePlaceholder('TODO: CBB + AUX instructions');
  Widget _buildMdbBoot() => _phasePlaceholder('TODO: wait for RNDIS');
  Widget _buildCbbReconnect() => _phasePlaceholder('TODO: verify CBB');
  Widget _buildDbcPrep() => _phasePlaceholder('TODO: upload + trampoline');
  Widget _buildDbcFlash() => _phasePlaceholder('TODO: waiting screen');
  Widget _buildReconnect() => _phasePlaceholder('TODO: verify status');
  Widget _buildFinish() => _phasePlaceholder('TODO: reassemble instructions');
}
