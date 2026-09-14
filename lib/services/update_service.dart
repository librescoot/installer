import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class InstallerUpdate {
  const InstallerUpdate({
    required this.currentVersion,
    required this.latestVersion,
    this.publishedAt,
    this.releaseNotes = '',
  });

  final String currentVersion;
  final String latestVersion;
  final DateTime? publishedAt;
  final String releaseNotes;
}

class UpdateService {
  UpdateService({
    http.Client? client,
    this.requestTimeout = const Duration(seconds: 8),
  }) : _client = client ?? http.Client();

  static final Uri downloadsUri = Uri.parse('https://downloads.librescoot.org');
  static final Uri _installerReleaseUri = Uri.parse(
    'https://downloads.librescoot.org/releases/installer.json',
  );

  final http.Client _client;
  final Duration requestTimeout;

  Future<InstallerUpdate?> check(String currentVersion) async {
    if (_parseVersion(currentVersion) == null) return null;

    final response = await _client
        .get(
          _installerReleaseUri,
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'Librescoot-Installer/$currentVersion',
          },
        )
        .timeout(requestTimeout);
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Installer release index returned HTTP ${response.statusCode}',
        _installerReleaseUri,
      );
    }

    final release = jsonDecode(response.body);
    if (release is! Map<String, dynamic> ||
        release['draft'] == true ||
        release['prerelease'] == true) {
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
