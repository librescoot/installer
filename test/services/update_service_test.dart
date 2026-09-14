import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:librescoot_installer/services/update_service.dart';

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
      late http.Request request;
      final service = UpdateService(
        client: MockClient((incoming) async {
          request = incoming;
          return http.Response(
            jsonEncode({
              'tag_name': 'v1.4.0',
              'published_at': '2026-09-08T12:34:56Z',
              'release_notes':
                  '## Highlights\n\n- Added [`updates`](https://example.com).',
              'assets': <Object>[],
            }),
            200,
          );
        }),
      );
      addTearDown(service.dispose);

      final update = await service.check('v1.3.3');

      expect(update?.currentVersion, 'v1.3.3');
      expect(update?.latestVersion, 'v1.4.0');
      expect(update?.publishedAt, DateTime.utc(2026, 9, 8, 12, 34, 56));
      expect(
        update?.releaseNotes,
        '## Highlights\n\n- Added [`updates`](https://example.com).',
      );
      expect(request.url.path, '/releases/installer.json');
      expect(request.headers['User-Agent'], 'Librescoot-Installer/v1.3.3');
    });

    test('returns null when the current release is latest', () async {
      final service = UpdateService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'tag_name': 'v1.3.3',
              'draft': false,
              'prerelease': false,
            }),
            200,
          ),
        ),
      );
      addTearDown(service.dispose);

      expect(await service.check('v1.3.3'), isNull);
    });

    test('ignores a release explicitly marked as a prerelease', () async {
      final service = UpdateService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({'tag_name': 'v1.4.0-beta.1', 'prerelease': true}),
            200,
          ),
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
