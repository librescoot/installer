import 'dart:async';

import 'package:flutter/material.dart';

import '../models/download_state.dart';
import '../models/installer_phase.dart';
import '../models/scooter_health.dart';
import '../services/services.dart';
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

  Widget _buildWelcome() => _phasePlaceholder('TODO: channel select, region, download');
  Widget _buildPhysicalPrep() => _phasePlaceholder('TODO: instructions');
  Widget _buildMdbConnect() => _phasePlaceholder('TODO: auto-detect');
  Widget _buildHealthCheck() => _phasePlaceholder('TODO: redis checks');
  Widget _buildBatteryRemoval() => _phasePlaceholder('TODO: seatbox + verify');
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
