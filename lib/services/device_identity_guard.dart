class DeviceIdentityException implements Exception {
  const DeviceIdentityException({required this.unavailable});

  final bool unavailable;

  @override
  String toString() => unavailable
      ? 'The device identity could not be verified. Reconnect the same scooter.'
      : 'A different device is connected. Reconnect the original scooter or '
            'start a new installer session for another scooter.';
}

/// Bind each service address to one immutable chip UID for this installer run.
class DeviceIdentityGuard {
  final _identities = <String, String>{};

  String verify(String host, String? serial) {
    final normalized = serial?.trim().toLowerCase();
    if (normalized == null || !RegExp(r'^[0-9a-f]{16}$').hasMatch(normalized)) {
      throw const DeviceIdentityException(unavailable: true);
    }
    final expected = _identities[host];
    if (expected != null && expected != normalized) {
      throw const DeviceIdentityException(unavailable: false);
    }
    _identities[host] = normalized;
    return normalized;
  }
}
