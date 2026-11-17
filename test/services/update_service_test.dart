import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:librescoot_installer/services/update_service.dart';

/// Answers the two indexes the service reads. [stable] and [beta] are the
/// bodies to serve, or null to answer 404, which is what a site with no beta
/// to offer looks like.
MockClient indexClient({
  String? stable,
  String? beta,
  List<http.Request>? log,
}) {
  return MockClient((request) async {
    log?.add(request);
    final isBeta = request.url.path.endsWith('installer-beta.json');
    final body = isBeta ? beta : stable;
    if (body == null) {
      return http.Response('not found', 404);
    }
    return http.Response(body, 200);
  });
}

String releaseBody(String tag, {bool? prerelease, String? notes}) {
  return jsonEncode({
    'tag_name': tag,
    if (prerelease != null) 'prerelease': prerelease,
    'published_at': '2026-09-08T12:34:56Z',
    'release_notes': notes ?? '',
  });
}

void main() {
  group('version comparison', () {
    test('recognizes a newer semantic version', () {
      expect(UpdateService.isNewerVersion('v1.3.3', 'v1.4.0'), isTrue);
      expect(UpdateService.isNewerVersion('v1.3.3', 'v2.0.0'), isTrue);
    });

    test('rejects equal and older versions', () {
      expect(UpdateService.isNewerVersion('v1.3.3', 'v1.3.3'), isFalse);
      expect(UpdateService.isNewerVersion('v1.3.3', 'v1.3.2'), isFalse);
    });

    test('does not prompt an untagged build for its base tag', () {
      expect(
        UpdateService.isNewerVersion('v1.3.3-4-gabcdef0', 'v1.3.3'),
        isFalse,
      );
      expect(UpdateService.isNewerVersion('v1.3.3-dirty', 'v1.3.3'), isFalse);
    });

    test('recognizes the stable release after a matching prerelease', () {
      expect(UpdateService.isNewerVersion('v1.4.0-beta.2', 'v1.4.0'), isTrue);
    });

    test('rejects unparseable versions', () {
      expect(UpdateService.isNewerVersion('dev', 'v1.3.3'), isFalse);
      expect(
        UpdateService.isNewerVersion('v1.3.3', 'nightly-20260908'),
        isFalse,
      );
    });
  });

  group('release check', () {
    test('returns the latest stable release when it is newer', () async {
      final requests = <http.Request>[];
      final service = UpdateService(
        client: indexClient(
          stable: releaseBody(
            'v1.4.0',
            notes: '## Highlights\n\n- Added [`updates`](https://example.com).',
          ),
          beta: null,
          log: requests,
        ),
      );
      addTearDown(service.dispose);

      final update = await service.check('v1.3.3');

      expect(update?.currentVersion, 'v1.3.3');
      expect(update?.latestVersion, 'v1.4.0');
      expect(update?.isPrerelease, isFalse);
      expect(update?.publishedAt, DateTime.utc(2026, 9, 8, 12, 34, 56));
      expect(
        update?.releaseNotes,
        '## Highlights\n\n- Added [`updates`](https://example.com).',
      );
      expect(
        requests.map((r) => r.url.path),
        contains('/releases/installer.json'),
      );
      expect(
        requests.first.headers['User-Agent'],
        'Librescoot-Installer/v1.3.3',
      );
    });

    test('offers the beta when it is newer than stable and than this build',
        () async {
      final service = UpdateService(
        client: indexClient(
          stable: releaseBody('v1.4.0', prerelease: false),
          // The real beta index carries no prerelease flag: which index it came
          // from is what makes it a beta.
          beta: releaseBody('v1.4.1-beta.1'),
        ),
      );
      addTearDown(service.dispose);

      final update = await service.check('v1.4.0');

      expect(update?.latestVersion, 'v1.4.1-beta.1');
      expect(update?.isPrerelease, isTrue);
    });

    test('keeps the stable release when the beta is not newer', () async {
      final service = UpdateService(
        client: indexClient(
          stable: releaseBody('v1.4.0'),
          beta: releaseBody('v1.4.0-beta.9'),
        ),
      );
      addTearDown(service.dispose);

      final update = await service.check('v1.3.3');

      expect(update?.latestVersion, 'v1.4.0');
      expect(update?.isPrerelease, isFalse);
    });

    test('a beta index that cannot be read still reports stable', () async {
      final service = UpdateService(
        client: indexClient(stable: releaseBody('v1.4.0'), beta: null),
      );
      addTearDown(service.dispose);

      final update = await service.check('v1.3.3');

      expect(update?.latestVersion, 'v1.4.0');
    });

    test('returns null when the current release is latest', () async {
      final service = UpdateService(
        client: indexClient(
          stable: releaseBody('v1.3.3', prerelease: false),
          beta: null,
        ),
      );
      addTearDown(service.dispose);

      expect(await service.check('v1.3.3'), isNull);
    });

    test('ignores a prerelease on the stable index', () async {
      final service = UpdateService(
        client: indexClient(
          stable: releaseBody('v1.4.0-beta.1', prerelease: true),
          beta: null,
        ),
      );
      addTearDown(service.dispose);

      expect(await service.check('v1.3.3'), isNull);
    });

    test('does not make a request for development builds', () async {
      var requested = false;
      final service = UpdateService(
        client: MockClient((_) async {
          requested = true;
          return http.Response('{}', 200);
        }),
      );
      addTearDown(service.dispose);

      expect(await service.check('dev'), isNull);
      expect(requested, isFalse);
    });

    test('rejects unsuccessful responses', () async {
      final service = UpdateService(
        client: MockClient((_) async => http.Response('rate limited', 403)),
      );
      addTearDown(service.dispose);

      await expectLater(
        service.check('v1.3.3'),
        throwsA(isA<http.ClientException>()),
      );
    });
  });
}
