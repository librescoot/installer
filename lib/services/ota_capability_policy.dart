/// Capability checks for full images installed from the pinned stage-0 images.
class OtaCapabilityPolicy {
  // Capabilities are bound to the exact stage-0 bytes, not the target release.
  static const _stageZeroSha256 = {
    'unu-mdb':
        '0066a5fd38b9bcd7bbc9496212a0c5ca8f136c02481c859c6767642ac52718f2',
    'unu-dbc':
        'cf7cb6d318c23f24fc280acfc53421afe14b6a3cfca12806ade823e8400c684f',
  };
  static const _supported = {'artifact.mender-v3', 'payload.gzip'};
  static final _sha256 = RegExp(r'^[0-9a-f]{64}$');

  static bool supportsBootstrap(Map<String, dynamic>? bootstrap) {
    if (bootstrap == null || bootstrap['tag_name'] != 'v1.3.0') return false;
    final assets = bootstrap['assets'];
    if (assets is! List) return false;
    for (final entry in _stageZeroSha256.entries) {
      final name = 'librescoot-${entry.key}-minimal-v1.3.0.sdimg.gz';
      final matches = assets.whereType<Map<String, dynamic>>().where(
        (a) => a['name'] == name,
      );
      if (matches.length != 1 || matches.single['sha256'] != entry.value) {
        return false;
      }
    }
    return true;
  }

  static bool eligibleFull(
    Map<String, dynamic> asset,
    String tag,
    String variant,
  ) {
    if (asset['name'] != 'librescoot-$variant-$tag.mender') return false;
    final size = asset['size'];
    final digest = asset['sha256'];
    if (size is! int ||
        size <= 0 ||
        digest is! String ||
        !_sha256.hasMatch(digest)) {
      return false;
    }
    final url = Uri.tryParse(
      asset['url'] is String ? asset['url'] as String : '',
    );
    if (url == null ||
        url.scheme != 'https' ||
        url.host.isEmpty ||
        url.userInfo.isNotEmpty ||
        url.fragment.isNotEmpty) {
      return false;
    }
    final policy = asset['ota'];
    if (policy is! Map<String, dynamic> ||
        policy['schema'] != 1 ||
        policy['kind'] != 'full' ||
        policy['variant'] != variant ||
        policy['artifact'] != 'release-$tag' ||
        policy['payload_compression'] != 'gzip' ||
        policy['algorithm'] != null ||
        policy['base'] != null ||
        policy['target'] != null) {
      return false;
    }
    final required = policy['requires'];
    if (required is! List ||
        required.isEmpty ||
        required.any((e) => e is! String || !_supported.contains(e))) {
      return false;
    }
    final unique = required.toSet();
    return unique.length == required.length && unique.containsAll(_supported);
  }

  /// Both boards need an eligible full image for the same release.
  static bool eligibleRelease(Map<String, dynamic> release) {
    final tag = release['tag_name'];
    final assets = release['assets'];
    if (tag is! String || tag.isEmpty || assets is! List) return false;
    for (final variant in _stageZeroSha256.keys) {
      final matches = assets.whereType<Map<String, dynamic>>().where(
        (a) => eligibleFull(a, tag, variant),
      );
      if (matches.length != 1) return false;
    }
    return true;
  }
}
