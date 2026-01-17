import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
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

  @override
  void initState() {
    super.initState();
    _checkElevation();
    _usbDetector.deviceStream.listen(_onDeviceChanged);
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
  }

  void _onDeviceChanged(UsbDevice? device) {
    setState(() => _device = device);

    if (device != null && _currentStep == InstallerStep.connectDevice) {
      _onDeviceConnected(device);
    } else if (device != null &&
        device.mode == DeviceMode.massStorage &&
        _currentStep == InstallerStep.prepareDevice) {
      _onMassStorageReady(device);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LibreScoot Installer'),
        actions: [
          if (!_isElevated)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Chip(
                avatar: const Icon(Icons.warning, size: 16, color: Colors.white),
                label: const Text(
                  'Not elevated',
                  style: TextStyle(color: Colors.white),
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
            _buildStepIndicator(),
            const SizedBox(height: 32),
            Expanded(child: _buildCurrentStep()),
            if (_statusMessage != null) ...[
              const SizedBox(height: 16),
              _buildStatusBar(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    final steps = [
      'Select Firmware',
      'Connect Device',
      'Configure Network',
      'Prepare Device',
      'Flash Firmware',
      'Complete',
    ];

    return Row(
      children: List.generate(steps.length, (index) {
        final isActive = index == _currentStep.index;
        final isComplete = index < _currentStep.index;

        return Expanded(
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
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case InstallerStep.selectFirmware:
        return _buildSelectFirmware();
      case InstallerStep.connectDevice:
        return _buildConnectDevice();
      case InstallerStep.configureNetwork:
        return _buildConfigureNetwork();
      case InstallerStep.prepareDevice:
        return _buildPrepareDevice();
      case InstallerStep.flashFirmware:
        return _buildFlashFirmware();
      case InstallerStep.complete:
        return _buildComplete();
    }
  }

  Widget _buildSelectFirmware() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.folder_open, size: 64, color: Colors.teal),
        const SizedBox(height: 16),
        const Text(
          'Select Firmware Image',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Choose a .wic or .wic.gz firmware file to flash',
          style: TextStyle(color: Colors.grey),
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
              label: Text(_firmwarePath == null ? 'Select File' : 'Change File'),
            ),
            if (_firmwarePath != null) ...[
              const SizedBox(width: 16),
              FilledButton.icon(
                onPressed: () => setState(() => _currentStep = InstallerStep.connectDevice),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Continue'),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildConnectDevice() {
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
          _device != null ? 'Device Connected' : 'Connect Your Device',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          _device != null
              ? '${_device!.name}\nMode: ${_device!.mode.name}'
              : 'Connect the MDB via USB and wait for detection',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 24),
        if (_device == null)
          const CircularProgressIndicator()
        else
          FilledButton.icon(
            onPressed: () => _onDeviceConnected(_device!),
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Continue'),
          ),
      ],
    );
  }

  Widget _buildConfigureNetwork() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          _isProcessing ? Icons.settings_ethernet : Icons.network_check,
          size: 64,
          color: Colors.teal,
        ),
        const SizedBox(height: 16),
        const Text(
          'Configuring Network',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          _isProcessing
              ? 'Setting up network interface...'
              : 'Ready to configure network for device communication',
          style: const TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 24),
        if (_isProcessing)
          const CircularProgressIndicator()
        else
          FilledButton.icon(
            onPressed: _configureNetwork,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Configure Network'),
          ),
      ],
    );
  }

  Widget _buildPrepareDevice() {
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
          _isProcessing ? 'Preparing Device' : 'Ready to Prepare',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (_deviceInfo != null)
          Text(
            'Connected to: ${_deviceInfo!.host}\n'
            'Firmware: ${_deviceInfo!.firmwareVersion}\n'
            'Serial: ${_deviceInfo!.serialNumber ?? "Unknown"}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
        const SizedBox(height: 24),
        if (_isProcessing)
          const CircularProgressIndicator()
        else
          FilledButton.icon(
            onPressed: _prepareDevice,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Prepare for Flashing'),
          ),
      ],
    );
  }

  Widget _buildFlashFirmware() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.flash_on, size: 64, color: Colors.amber),
        const SizedBox(height: 16),
        const Text(
          'Flashing Firmware',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        LinearProgressIndicator(value: _progress),
        const SizedBox(height: 8),
        Text('${(_progress * 100).toStringAsFixed(0)}%'),
        const SizedBox(height: 16),
        if (!_isProcessing)
          FilledButton.icon(
            onPressed: _flashFirmware,
            icon: const Icon(Icons.flash_on),
            label: const Text('Start Flashing'),
          ),
      ],
    );
  }

  Widget _buildComplete() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle, size: 64, color: Colors.green),
        const SizedBox(height: 16),
        const Text(
          'Installation Complete!',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your device has been successfully flashed.\n'
          'It will reboot automatically.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
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
          label: const Text('Flash Another Device'),
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

  Future<void> _pickFirmware() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        dialogTitle: 'Select Firmware Image',
      );

      if (result != null && result.files.isNotEmpty) {
        final path = result.files.first.path;
        if (path != null) {
          if (path.endsWith('.wic') || path.endsWith('.wic.gz') || path.endsWith('.gz')) {
            setState(() => _firmwarePath = path);
          } else {
            setState(() => _statusMessage = 'Please select a .wic or .wic.gz file');
          }
        }
      }
    } catch (e) {
      setState(() => _statusMessage = 'Error opening file picker: $e');
    }
  }

  void _onDeviceConnected(UsbDevice device) {
    if (device.mode == DeviceMode.ethernet) {
      setState(() => _currentStep = InstallerStep.configureNetwork);
      _usbDetector.startMonitoring();
    } else if (device.mode == DeviceMode.massStorage) {
      setState(() => _currentStep = InstallerStep.flashFirmware);
    }
  }

  Future<void> _configureNetwork() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Finding network interface...';
    });

    try {
      final iface = await _networkService.findLibreScootInterface();
      if (iface == null) {
        throw Exception('Could not find USB network interface');
      }

      setState(() => _statusMessage = 'Configuring ${iface.displayName}...');

      final success = await _networkService.configureInterface(iface);
      if (!success) {
        throw Exception('Failed to configure network interface');
      }

      setState(() {
        _statusMessage = 'Network configured successfully';
        _currentStep = InstallerStep.prepareDevice;
      });

      // Connect via SSH
      await _connectSsh();
    } catch (e) {
      setState(() => _statusMessage = 'Error: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _connectSsh() async {
    setState(() => _statusMessage = 'Connecting via SSH...');

    try {
      // Load passwords from assets
      await _sshService.loadPasswords('assets');

      final info = await _sshService.connectToMdb();
      setState(() {
        _deviceInfo = info;
        _statusMessage = 'Connected to ${info.firmwareVersion}';
      });
    } catch (e) {
      setState(() => _statusMessage = 'SSH error: $e');
    }
  }

  Future<void> _prepareDevice() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Configuring bootloader for mass storage mode...';
    });

    try {
      await _sshService.configureMassStorageMode();

      setState(() => _statusMessage = 'Rebooting device...');
      await _sshService.reboot();

      setState(() {
        _statusMessage = 'Waiting for device to reboot in mass storage mode...';
      });

      // USB detector will pick up the mass storage device
    } catch (e) {
      setState(() => _statusMessage = 'Error: $e');
      _isProcessing = false;
    }
  }

  void _onMassStorageReady(UsbDevice device) {
    setState(() {
      _isProcessing = false;
      _statusMessage = 'Device ready for flashing';
      _currentStep = InstallerStep.flashFirmware;
    });
  }

  Future<void> _flashFirmware() async {
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
      await _showSafetyError(safetyCheck);
      return;
    }

    // Show confirmation dialog
    final confirmed = await _showFlashConfirmation(safetyCheck.warnings);
    if (confirmed != true) return;

    setState(() {
      _isProcessing = true;
      _progress = 0.0;
      _statusMessage = 'Starting flash...';
    });

    try {
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
          _statusMessage = 'Flash complete!';
        });
      } else {
        throw Exception(result.error ?? 'Unknown error');
      }
    } catch (e) {
      setState(() => _statusMessage = 'Flash error: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _showSafetyError(SafetyCheck safetyCheck) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.dangerous, color: Colors.red, size: 48),
        title: const Text('Safety Check Failed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cannot flash this device due to safety concerns:',
              style: TextStyle(fontWeight: FontWeight.bold),
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
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showFlashConfirmation(List<String> warnings) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber, color: Colors.orange, size: 48),
        title: const Text('Confirm Flash Operation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'You are about to write firmware to:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildDeviceInfoRow('Device', _device!.name),
            _buildDeviceInfoRow('Path', _device!.path),
            _buildDeviceInfoRow('Size', _device!.sizeFormatted),
            _buildDeviceInfoRow('VID:PID',
                '${_device!.vendorId.toRadixString(16).toUpperCase()}:'
                '${_device!.productId.toRadixString(16).toUpperCase()}'),
            const SizedBox(height: 16),
            const Text(
              'Firmware:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _firmwarePath!.split('/').last.split('\\').last,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
            if (warnings.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Warnings:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
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
              child: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.red),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This will ERASE ALL DATA on the device. '
                      'This action cannot be undone.',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Flash Device'),
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
