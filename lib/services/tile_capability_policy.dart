class TileCapabilityPolicy {
  // Add a DBC artifact digest only after its reader stack is qualified.
  static const Map<String, Set<String>> qualifiedArtifacts = {};

  static final _sha256 = RegExp(r'^[0-9a-f]{64}$');
  static final _token = RegExp(r'^[a-z0-9][a-z0-9.-]*$');

  static bool eligibleFull(
    Map<String, dynamic> asset,
    String kind,
    String region,
    Set<String> supported,
  ) {
    if (kind != 'map' && kind != 'routing') return false;
    if (asset['kind'] != kind || asset['region'] != region) return false;
    if (asset.keys.any(
      (key) => key != 'requires' && key.toLowerCase() == 'requires',
    )) {
      return false;
    }
    final format = asset['format'];
    final digest = asset['sha256'];
    final size = asset['size'];
    final rawUrl = asset['url'];
    if (format is! String ||
        !_token.hasMatch(format) ||
        digest is! String ||
        !_sha256.hasMatch(digest) ||
        size is! int ||
        size <= 0 ||
        rawUrl is! String) {
      return false;
    }
    final url = Uri.tryParse(rawUrl);
    if (url == null ||
        url.scheme != 'https' ||
        url.host.isEmpty ||
        url.userInfo.isNotEmpty ||
        url.hasFragment) {
      return false;
    }
    final requires = asset['requires'];
    if (requires is! List ||
        requires.isEmpty ||
        requires.any(
          (value) =>
              value is! String ||
              !_token.hasMatch(value) ||
              !supported.contains(value),
        )) {
      return false;
    }
    final distinct = requires.toSet();
    return distinct.length == requires.length &&
        distinct.contains('$kind.format.$format');
  }
}
