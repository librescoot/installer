import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class InstallerUpdate {
  const InstallerUpdate({
    required this.currentVersion,
    required this.latestVersion,
    this.publishedAt,
    this.releaseNotes = '',
    this.isPrerelease = false,
  });

  final String currentVersion;
  final String latestVersion;
  final DateTime? publishedAt;
  final String releaseNotes;

  /// Whether the release came from the beta index. Always false for the stable
  /// one, and true for anything the beta index offers, which is a prerelease by
  /// construction.
  final bool isPrerelease;
}

class UpdateService {
  UpdateService({
    http.Client? client,
    // 20 s: a field machine hit the old 8 s ceiling on the installer update
    // check, which is a cosmetic check but reported as a failure each run.
    this.requestTimeout = const Duration(seconds: 20),
  }) : _client = client ?? http.Client();

  static final Uri downloadsUri = Uri.parse('https://downloads.librescoot.org');
  static final Uri _installerReleaseUri = Uri.parse(
    'https://downloads.librescoot.org/releases/installer.json',
  );

  /// The newest prerelease the site publishes, and only when it is newer than
  /// stable: the site's generator compares the two and drops the field.
  static final Uri _installerBetaReleaseUri = Uri.parse(
    'https://downloads.librescoot.org/releases/installer-beta.json',
  );

  final http.Client _client;
  final Duration requestTimeout;

  /// Asks both indexes and returns the newer of what they offer.
  ///
  /// The stable index is authoritative: if it cannot be read, the check fails
  /// the way it always has. The beta index is read best effort, so a build that
  /// predates the betas, or a site with none to offer, still checks cleanly.
  Future<InstallerUpdate?> check(String currentVersion) async {
    if (_parseVersion(currentVersion) == null) return null;

    final stable = await _readIndex(
      _installerReleaseUri,
      currentVersion,
      fromBetaIndex: false,
    );
    final beta = await _readBetaIndex(currentVersion);

    if (stable == null) return beta;
    if (beta == null) return stable;
    return isNewerVersion(stable.latestVersion, beta.latestVersion)
        ? beta
        : stable;
  }

  Future<InstallerUpdate?> _readBetaIndex(String currentVersion) async {
    try {
      return await _readIndex(
        _installerBetaReleaseUri,
        currentVersion,
        fromBetaIndex: true,
      );
    } catch (error) {
      debugPrint('Update: beta index not available ($error)');
      return null;
    }
  }

  Future<InstallerUpdate?> _readIndex(
    Uri uri,
    String currentVersion, {
    required bool fromBetaIndex,
  }) async {
    final response = await _client
        .get(
          uri,
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'Librescoot-Installer/$currentVersion',
          },
        )
        .timeout(requestTimeout);
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Installer release index returned HTTP ${response.statusCode}',
        uri,
      );
    }

    final release = jsonDecode(response.body);
    if (release is! Map<String, dynamic> || release['draft'] == true) {
      return null;
    }
    // The stable index is not supposed to carry a prerelease. If one turns up
    // there, it is not something to put in front of somebody who is not
    // following betas; the beta index is the way to ask for one.
    if (!fromBetaIndex && release['prerelease'] == true) {
      return null;
    }
    final latestVersion = release['tag_name'];
    if (latestVersion is! String ||
        !isNewerVersion(currentVersion, latestVersion)) {
      return null;
    }

    final publishedAt = release['published_at'];
    final releaseNotes = release['release_notes'];
    return InstallerUpdate(
      currentVersion: currentVersion,
      latestVersion: latestVersion,
      publishedAt: publishedAt is String
          ? DateTime.tryParse(publishedAt)
          : null,
      releaseNotes: releaseNotes is String ? releaseNotes : '',
      isPrerelease: fromBetaIndex,
    );
  }

  @visibleForTesting
  static bool isNewerVersion(String current, String candidate) {
    final currentParsed = _parseVersion(current);
    final candidateParsed = _parseVersion(candidate);
    if (currentParsed == null || candidateParsed == null) return false;

    for (var i = 0; i < 3; i++) {
      if (candidateParsed.numbers[i] != currentParsed.numbers[i]) {
        return candidateParsed.numbers[i] > currentParsed.numbers[i];
      }
    }

    return currentParsed.isPrerelease && !candidateParsed.isPrerelease;
  }

  static ({List<int> numbers, bool isPrerelease})? _parseVersion(String value) {
    final match = RegExp(
      r'^v?(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?(?:\+[0-9A-Za-z.-]+)?$',
    ).firstMatch(value.trim());
    if (match == null) return null;

    final suffix = match.group(4);
    final isDevelopmentBuild =
        suffix != null &&
        RegExp(r'^(?:dirty|\d+-g[0-9a-f]+(?:-dirty)?)$').hasMatch(suffix);
    return (
      numbers: [
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
      ],
      isPrerelease: suffix != null && !isDevelopmentBuild,
    );
  }

  void dispose() => _client.close();
}
