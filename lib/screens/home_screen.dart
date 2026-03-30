import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import '../l10n/app_localizations.dart';
import '../services/services.dart';

enum InstallerStep {
  selectFirmware,
  connectDevice,
  configureNetwork,
  prepareDevice,
  flashFirmware,
  complete,
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const bool _flashDryRun = false;
  InstallerStep _currentStep = InstallerStep.selectFirmware;
  String? _firmwarePath;
  String? _statusMessage;
  bool _isProcessing = false;
  double _progress = 0.0;
  bool _isElevated = false;

  final _usbDetector = UsbDetector();
  final _networkService = NetworkService();
  final _sshService = SshService();
  final _flashService = FlashService();

  UsbDevice? _device;
  DeviceInfo? _deviceInfo;
  bool _networkAutoStarted = false;

  @override
  void initState() {
    super.initState();
    _checkElevation();
    _usbDetector.deviceStream.listen(_onDeviceChanged);
    _usbDetector.startMonitoring();
    _autoLoadFirmwareFromCwd();
  }

  @override
  void dispose() {
    _usbDetector.dispose();
    _sshService.disconnect();
    super.dispose();
  }

  Future<void> _checkElevation() async {
    final elevated = await ElevationService.isElevated();
    setState(() => _isElevated = elevated);

    if (elevated) {
      await _ensureDriverInstalled();
    }
  }

  Future<void> _ensureDriverInstalled() async {
    if (!Platform.isWindows) return;

    final l10n = AppLocalizations.of(context)!;
    final installed = await DriverService.isDriverInstalled();
    if (!installed) {
      setState(() => _statusMessage = l10n.installingUsbDriver);
      final result = await DriverService.installDriver();
      if (result.success) {
        setState(() => _statusMessage = result.alreadyInstalled
            ? null
            : l10n.usbDriverInstalled);
      } else {
        setState(() => _statusMessage = l10n.driverInstallFailed(result.error ?? ''));
      }
    }
  }

  Future<void> _autoLoadFirmwareFromCwd() async {
    final autoPath = _findAutoFirmwareCandidateInCwd();
    debugPrint('Startup firmware check: ${autoPath ?? "no matching firmware in cwd"}');
    if (!mounted || autoPath == null || _firmwarePath != null) return;

    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _firmwarePath = autoPath;
      _currentStep = InstallerStep.connectDevice;
      _statusMessage = l10n.autoLoadedFirmware;
    });
    _consumeAlreadyDetectedDevice();
  }

  String? _findAutoFirmwareCandidateInCwd() {
    final dir = Directory.current;
    if (!dir.existsSync()) return null;

    final pattern = RegExp(
      r'^librescoot-unu-mdb-([a-z0-9-]+)-(\d{8}T\d{6})\.sdimg\.gz$',
      caseSensitive: false,
    );

    String? bestPath;
    String? bestTimestamp;

    for (final entity in dir.listSync(followLinks: false)) {
      if (entity is! File) continue;
      final fileName = path.basename(entity.path);
      final match = pattern.firstMatch(fileName);
      if (match == null) continue;

      final timestamp = match.group(2)!;
      if (bestTimestamp == null || timestamp.compareTo(bestTimestamp) > 0) {
        bestTimestamp = timestamp;
        bestPath = entity.path;
      }
    }

    // Backward-compatible fallback.
    if (bestPath == null) {
      for (final name in ['mdb.sdimg.gz', 'mdb.sdimg', 'mdb.wic.gz', 'mdb.wic', 'mdb.img']) {
        final legacy = path.join(dir.path, name);
        if (File(legacy).existsSync()) return legacy;
      }
    }

    return bestPath;
  }

  void _consumeAlreadyDetectedDevice() {
    final device = _usbDetector.currentDevice;
    if (device != null && _currentStep == InstallerStep.connectDevice) {
      debugPrint('UI: consuming already-detected device ${device.name} (${device.mode.name})');
      _onDeviceConnected(device);
    }
  }

  void _onDeviceChanged(UsbDevice? device) {
    debugPrint(
      device == null
          ? 'USB device disconnected'
          : 'USB device detected: ${device.name} (${device.mode.name})',
    );
    setState(() => _device = device);

    if (device == null) {
      if (_currentStep == InstallerStep.prepareDevice) {
        final l10n = AppLocalizations.of(context)!;
        setState(() {
          _isProcessing = false;
          _currentStep = InstallerStep.connectDevice;
          _statusMessage = l10n.deviceDisconnected;
        });
      }
      return;
    }

    if (_currentStep == InstallerStep.connectDevice) {
      _onDeviceConnected(device);
    } else if (device.mode == DeviceMode.massStorage &&
        _currentStep == InstallerStep.prepareDevice) {
      _onMassStorageReady(device);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.homeAppTitle),
        actions: [
          if (!_isElevated)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Chip(
                avatar: const Icon(Icons.warning, size: 16, color: Colors.white),
                label: Text(
                  l10n.notElevated,
                  style: const TextStyle(color: Colors.white),
                ),
                backgroundColor: Colors.orange.shade800,
              ),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStepIndicator(l10n),
            const SizedBox(height: 32),
            Expanded(child: _buildCurrentStep(l10n)),
            if (_statusMessage != null) ...[
              const SizedBox(height: 16),
              _buildStatusBar(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator(AppLocalizations l10n) {
    final steps = [
      l10n.selectFirmwareStep,
      l10n.connectDeviceStep,
      l10n.configureNetworkStep,
      l10n.prepareDeviceStep,
      l10n.flashFirmwareStep,
      l10n.completeStep,
    ];

    return Row(
      children: List.generate(steps.length, (index) {
        final isActive = index == _currentStep.index;
        final isComplete = index < _currentStep.index;
        final canJump = isComplete && !_isProcessing;

        return Expanded(
          child: InkWell(
            onTap: canJump
                ? () {
                    setState(() => _currentStep = InstallerStep.values[index]);
                  }
                : null,
            borderRadius: BorderRadius.horizontal(
              left: index == 0 ? const Radius.circular(8) : Radius.zero,
              right: index == steps.length - 1 ? const Radius.circular(8) : Radius.zero,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isActive
                    ? Theme.of(context).colorScheme.primary
                    : isComplete
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Colors.grey.shade800,
                borderRadius: BorderRadius.horizontal(
                  left: index == 0 ? const Radius.circular(8) : Radius.zero,
                  right: index == steps.length - 1 ? const Radius.circular(8) : Radius.zero,
                ),
              ),
              child: Text(
                steps[index],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive || isComplete ? Colors.white : Colors.grey,
                  decoration: canJump ? TextDecoration.underline : TextDecoration.none,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildCurrentStep(AppLocalizations l10n) {
    switch (_currentStep) {
      case InstallerStep.selectFirmware:
        return _buildSelectFirmware(l10n);
      case InstallerStep.connectDevice:
        return _buildConnectDevice(l10n);
      case InstallerStep.configureNetwork:
        return _buildConfigureNetwork(l10n);
      case InstallerStep.prepareDevice:
        return _buildPrepareDevice(l10n);
      case InstallerStep.flashFirmware:
        return _buildFlashFirmware(l10n);
      case InstallerStep.complete:
        return _buildComplete(l10n);
    }
  }

  Widget _buildSelectFirmware(AppLocalizations l10n) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.folder_open, size: 64, color: Colors.teal),
        const SizedBox(height: 16),
        Text(
          l10n.selectFirmwareImage,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.selectFirmwareHint,
          style: const TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 24),
        if (_firmwarePath != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade800,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.insert_drive_file),
                const SizedBox(width: 8),
                Flexible(child: Text(_firmwarePath!, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: _pickFirmware,
              icon: const Icon(Icons.file_open),
              label: Text(_firmwarePath == null ? l10n.selectFile : l10n.changeFile),
            ),
            if (_firmwarePath != null) ...[
              const SizedBox(width: 16),
              FilledButton.icon(
                onPressed: () {
                  setState(() => _currentStep = InstallerStep.connectDevice);
                  _consumeAlreadyDetectedDevice();
                },
                icon: const Icon(Icons.arrow_forward),
                label: Text(l10n.continueButton),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildConnectDevice(AppLocalizations l10n) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          _device != null ? Icons.usb : Icons.usb_off,
          size: 64,
          color: _device != null ? Colors.green : Colors.grey,
        ),
        const SizedBox(height: 16),
        Text(
          _device != null ? l10n.deviceConnected : l10n.connectYourDevice,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          _device != null
              ? '${_device!.name}\n${l10n.modeLabel(_device!.mode.name)}'
              : l10n.connectMdbViaUsb,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 24),
        if (_device == null) ...[
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () => setState(() => _currentStep = InstallerStep.selectFirmware),
            icon: const Icon(Icons.arrow_back),
            label: Text(l10n.backButton),
          ),
        ] else
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: () => setState(() => _currentStep = InstallerStep.selectFirmware),
                icon: const Icon(Icons.arrow_back),
                label: Text(l10n.backButton),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => _onDeviceConnected(_device!),
                icon: const Icon(Icons.arrow_forward),
                label: Text(l10n.continueButton),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildConfigureNetwork(AppLocalizations l10n) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          _isProcessing ? Icons.settings_ethernet : Icons.network_check,
          size: 64,
          color: Colors.teal,
        ),
        const SizedBox(height: 16),
        Text(
          l10n.configuringNetworkHeading,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          _isProcessing
              ? l10n.settingUpNetwork
              : l10n.readyToConfigureNetwork,
          style: const TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 24),
        if (_isProcessing)
          const CircularProgressIndicator()
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: () => setState(() => _currentStep = InstallerStep.connectDevice),
                icon: const Icon(Icons.arrow_back),
                label: Text(l10n.backButton),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _configureNetwork,
                icon: const Icon(Icons.play_arrow),
                label: Text(l10n.configureNetworkButton),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildPrepareDevice(AppLocalizations l10n) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          _isProcessing ? Icons.sync : Icons.developer_board,
          size: 64,
          color: Colors.orange,
        ),
        const SizedBox(height: 16),
        Text(
          _isProcessing ? l10n.preparingDevice : l10n.readyToPrepare,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (_deviceInfo != null)
          Text(
            l10n.connectedTo(
              _deviceInfo!.host,
              _deviceInfo!.firmwareVersion,
              _deviceInfo!.serialNumber ?? l10n.unknown,
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
        const SizedBox(height: 24),
        if (_isProcessing)
          const CircularProgressIndicator()
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: () => setState(() => _currentStep = InstallerStep.configureNetwork),
                icon: const Icon(Icons.arrow_back),
                label: Text(l10n.backButton),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _prepareDevice,
                icon: const Icon(Icons.play_arrow),
                label: Text(l10n.prepareForFlashing),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildFlashFirmware(AppLocalizations l10n) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.flash_on, size: 64, color: Colors.amber),
        const SizedBox(height: 16),
        Text(
          l10n.flashingFirmware,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        LinearProgressIndicator(value: _progress),
        const SizedBox(height: 8),
        Text('${(_progress * 100).toStringAsFixed(0)}%'),
        const SizedBox(height: 16),
        if (!_isProcessing)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: () => setState(() => _currentStep = InstallerStep.prepareDevice),
                icon: const Icon(Icons.arrow_back),
                label: Text(l10n.backButton),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _flashFirmware,
                icon: const Icon(Icons.flash_on),
                label: Text(l10n.startFlashing),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildComplete(AppLocalizations l10n) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle, size: 64, color: Colors.green),
        const SizedBox(height: 16),
        Text(
          l10n.installationComplete,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.installationCompleteDesc,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () {
            setState(() {
              _currentStep = InstallerStep.selectFirmware;
              _firmwarePath = null;
              _device = null;
              _deviceInfo = null;
            });
          },
          icon: const Icon(Icons.refresh),
          label: Text(l10n.flashAnotherDevice),
        ),
      ],
    );
  }

  Widget _buildStatusBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          if (_isProcessing)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            const Icon(Icons.info_outline, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(_statusMessage ?? '')),
        ],
      ),
    );
  }

  static bool _isFirmwareFile(String path) {
    return path.endsWith('.sdimg.gz') ||
        path.endsWith('.sdimg') ||
        path.endsWith('.wic.gz') ||
        path.endsWith('.wic') ||
        path.endsWith('.img');
  }

  Future<void> _pickFirmware() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['gz', 'sdimg', 'wic', 'img'],
        dialogTitle: l10n.selectFirmwareDialogTitle,
      );

      if (result != null && result.files.isNotEmpty) {
        final selectedPath = result.files.first.path;
        if (selectedPath != null) {
          if (_isFirmwareFile(selectedPath)) {
            setState(() {
              _firmwarePath = selectedPath;
              _statusMessage = null;
            });
          } else {
            setState(() => _statusMessage = l10n.selectFirmwareFileError);
          }
        }
      }
    } catch (e) {
      setState(() => _statusMessage = l10n.errorOpeningFilePicker(e.toString()));
    }
  }

  void _onDeviceConnected(UsbDevice device) {
    if (device.mode == DeviceMode.ethernet) {
      setState(() => _currentStep = InstallerStep.configureNetwork);
      _usbDetector.startMonitoring();
      _tryAutoConfigureNetwork();
    } else if (device.mode == DeviceMode.massStorage) {
      setState(() => _currentStep = InstallerStep.flashFirmware);
    }
  }

  void _tryAutoConfigureNetwork() {
    if (_networkAutoStarted || _isProcessing) return;
    _networkAutoStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _currentStep != InstallerStep.configureNetwork) return;
      _configureNetwork();
    });
  }

  Future<void> _configureNetwork() async {
    final l10n = AppLocalizations.of(context)!;
    _networkAutoStarted = false;
    setState(() {
      _isProcessing = true;
      _statusMessage = l10n.waitingForMdbNetwork;
    });

    try {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      setState(() => _statusMessage = l10n.findingNetworkInterface);

      final iface = await _networkService.findLibreScootInterface();
      if (iface == null) {
        throw Exception(l10n.couldNotFindInterface);
      }

      setState(() => _statusMessage = '${l10n.configuringNetwork} ${iface.displayName}...');

      final success = await _networkService.configureInterface(iface);
      if (!success) {
        throw Exception(l10n.couldNotFindInterface);
      }

      setState(() {
        _statusMessage = l10n.networkConfigured;
        _currentStep = InstallerStep.prepareDevice;
      });

      // Connect via SSH
      await _connectSsh();
    } catch (e) {
      setState(() => _statusMessage = l10n.errorPrefix(e.toString()));
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _connectSsh() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _statusMessage = l10n.connectingSsh);
    debugPrint('UI: starting SSH connect to MDB');

    try {
      // Load passwords from assets
      await _sshService.loadDeviceConfig('assets');

      final info = await _sshService.connectToMdb();
      debugPrint('UI: SSH connected, firmware=${info.firmwareVersion}, serial=${info.serialNumber ?? "unknown"}');
      setState(() {
        _deviceInfo = info;
        _statusMessage = l10n.connectedToFirmware(info.firmwareVersion);
      });
    } catch (e) {
      debugPrint('UI: SSH connection failed: $e');
      setState(() => _statusMessage = l10n.sshConnectionFailed(e.toString()));
    }
  }

  Future<void> _prepareDevice() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isProcessing = true;
      _statusMessage = l10n.configuringBootloader;
    });
    debugPrint('UI: prepare step started');

    try {
      debugPrint('UI: calling configureMassStorageMode()');
      await _sshService.configureMassStorageMode();
      debugPrint('UI: configureMassStorageMode() completed');

      setState(() => _statusMessage = l10n.rebootingDevice);
      debugPrint('UI: calling reboot()');
      await _sshService.reboot();
      debugPrint('UI: reboot() call returned');

      setState(() {
        _statusMessage = l10n.waitingForMassStorage;
      });
      debugPrint('UI: waiting for USB detector to report mass storage mode');

      // USB detector will pick up the mass storage device
    } catch (e) {
      debugPrint('UI: prepare step failed: $e');
      setState(() => _statusMessage = l10n.errorPrefix(e.toString()));
      _isProcessing = false;
    }
  }

  void _onMassStorageReady(UsbDevice device) {
    final l10n = AppLocalizations.of(context)!;
    debugPrint('UI: mass storage detected: ${device.name} path=${device.path}');
    setState(() {
      _isProcessing = false;
      _statusMessage = l10n.deviceReadyForFlashing;
      _currentStep = InstallerStep.flashFirmware;
    });
  }

  Future<void> _flashFirmware() async {
    final l10n = AppLocalizations.of(context)!;
    if (_firmwarePath == null || _device == null) return;

    // Safety validation
    final safetyCheck = _flashService.validateDevice(
      devicePath: _device!.path,
      sizeBytes: _device!.sizeBytes,
      isRemovable: _device!.isRemovable,
      isSystemDisk: _device!.isSystemDisk,
      vendorId: _device!.vendorId,
      productId: _device!.productId,
    );

    if (!safetyCheck.passed) {
      await _showSafetyError(safetyCheck, l10n);
      return;
    }

    // Show confirmation dialog
    final confirmed = await _showFlashConfirmation(safetyCheck.warnings, l10n);
    if (confirmed != true) return;

    setState(() {
      _isProcessing = true;
      _progress = 0.0;
      _statusMessage = _flashDryRun ? l10n.resolvingReleases : l10n.startFlashing;
    });

    try {
      if (_flashDryRun) {
        final plan = await _flashService.buildFlashPlan(
          _firmwarePath!,
          _device!.path,
        );
        setState(() => _statusMessage = l10n.flashDryRun);
        await _showFlashPlan(plan, l10n);
      } else {
        final result = await _flashService.writeImage(
          _firmwarePath!,
          _device!.path,
          onProgress: (progress, status) {
            setState(() {
              _progress = progress;
              _statusMessage = status;
            });
          },
        );

        if (result.success) {
          setState(() {
            _currentStep = InstallerStep.complete;
            _statusMessage = l10n.flashComplete;
          });
        } else {
          throw Exception(result.error ?? l10n.unknown);
        }
      }
    } catch (e) {
      setState(() => _statusMessage = l10n.flashError(e.toString()));
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _showFlashPlan(String plan, AppLocalizations l10n) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.terminal),
        title: Text(l10n.flashDryRun),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360, maxWidth: 700),
          child: SingleChildScrollView(
            child: SelectableText(
              plan,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.closeButton),
          ),
        ],
      ),
    );
  }

  Future<void> _showSafetyError(SafetyCheck safetyCheck, AppLocalizations l10n) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.dangerous, color: Colors.red, size: 48),
        title: Text(l10n.safetyCheckFailed),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.cannotFlashSafety,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...safetyCheck.errors.map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(e)),
                ],
              ),
            )),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.okButton),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showFlashConfirmation(List<String> warnings, AppLocalizations l10n) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber, color: Colors.orange, size: 48),
        title: Text(l10n.confirmFlashOperation),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.aboutToWriteFirmware,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildDeviceInfoRow(l10n.deviceLabel, _device!.name),
                _buildDeviceInfoRow(l10n.pathLabel, _device!.path),
                _buildDeviceInfoRow(l10n.sizeLabel, _device!.sizeFormatted),
                _buildDeviceInfoRow('VID:PID',
                    '${_device!.vendorId.toRadixString(16).toUpperCase()}:'
                    '${_device!.productId.toRadixString(16).toUpperCase()}'),
                const SizedBox(height: 16),
                Text(
                  l10n.firmwareLabel,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  _firmwarePath!.split('/').last.split('\\').last,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
                if (warnings.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    l10n.warningsLabel,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                  ),
                  const SizedBox(height: 8),
                  ...warnings.map((w) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning, color: Colors.orange, size: 14),
                        const SizedBox(width: 8),
                        Expanded(child: Text(w, style: const TextStyle(fontSize: 12))),
                      ],
                    ),
                  )),
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade700),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.eraseWarning,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancelButton),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.flashDeviceButton),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text('$label:', style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }
}
