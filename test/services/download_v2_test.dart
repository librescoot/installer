import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:librescoot_installer/models/download_state.dart';
import 'package:librescoot_installer/services/download_service.dart';

import 'ota_capability_policy_test.dart' as fixtures;

Map<String, dynamic> release(String tag, {bool zstd = false}) {
  final assets = [fixtures.full('unu-mdb'), fixtures.full('unu-dbc')];
  for (final asset in assets) {
    final variant = (asset['ota'] as Map<String, dynamic>)['variant'] as String;
    asset['name'] = 'librescoot-$variant-$tag.mender';
    final policy = asset['ota'] as Map<String, dynamic>;
    policy['artifact'] = 'release-$tag';
    if (zstd) {
      policy['payload_compression'] = 'zstd';
      policy['requires'] = ['artifact.mender-v3', 'payload.zstd'];
    }
  }
  return {
    'tag_name': tag,
    'published_at': '2026-11-14T00:00:00Z',
    'assets': assets,
  };
}

void main() {
  test('selects current live v2 gzip images', () async {
    final service = DownloadService();
    addTearDown(service.dispose);
    for (final channel in DownloadChannel.values) {
      final selected = await service.resolveRelease(channel);
      expect(
        selected.assets
            .where((a) => (a['name'] as String).endsWith('.mender'))
            .length,
        2,
      );
      expect(selected.assets.where((a) => a['ota'] is Map).length, 2);
    }
    expect((await service.resolveBootstrapRelease())?.tag, 'v1.3.0');
  }, skip: Platform.environment['OTA_TEST_LIVE_V2'] != '1');

  test('selects latest gzip v2 for the pinned stage-0 images', () async {
    final latest = {
      'bootstrap': fixtures.bootstrap(),
      'stable': release('v1.4.3'),
    };
    final client = MockClient((request) async {
      if (request.url.path == '/releases/v2/latest.json') {
        return http.Response(jsonEncode(latest), 200);
      }
      return http.Response('missing', 404);
    });
    final service = DownloadService(client: client);
    addTearDown(service.dispose);
    final selected = await service.resolveRelease(DownloadChannel.stable);
    expect(selected.tag, 'v1.4.3');
    expect(
      selected.assets
          .where((a) => (a['name'] as String).endsWith('.mender'))
          .length,
      2,
    );
    expect((await service.resolveBootstrapRelease())?.tag, 'v1.3.0');
  });

  test(
    'skips a newer unsupported image and finds a compatible release',
    () async {
      final latest = {
        'bootstrap': fixtures.bootstrap(),
        'stable': release('v1.5.0', zstd: true),
      };
      final client = MockClient((request) async {
        if (request.url.path == '/releases/v2/latest.json') {
          return http.Response(jsonEncode(latest), 200);
        }
        if (request.url.path == '/releases/v2/stable.json') {
          return http.Response(
            jsonEncode([release('v1.5.0', zstd: true), release('v1.4.3')]),
            200,
          );
        }
        return http.Response('missing', 404);
      });
      final service = DownloadService(client: client);
      addTearDown(service.dispose);
      expect(
        (await service.resolveRelease(DownloadChannel.stable)).tag,
        'v1.4.3',
      );
      expect(
        (await service.fetchAvailableChannels())[DownloadChannel.stable]?.tag,
        'v1.4.3',
      );
    },
  );

  test(
    'retries a transient v2 connection failure before legacy fallback',
    () async {
      var requests = 0;
      final latest = {
        'bootstrap': fixtures.bootstrap(),
        'stable': release('v1.4.3'),
      };
      final client = MockClient((request) async {
        if (request.url.path != '/releases/v2/latest.json') {
          fail('unexpected legacy request: ${request.url}');
        }
        requests++;
        if (requests == 1) throw const SocketException('temporary failure');
        return http.Response(jsonEncode(latest), 200);
      });
      final service = DownloadService(
        client: client,
        retryDelays: const [Duration.zero],
      );
      addTearDown(service.dispose);
      expect(
        (await service.resolveRelease(DownloadChannel.stable)).tag,
        'v1.4.3',
      );
      expect(requests, 2);
    },
  );

  test('unknown stage-0 never silently falls back to legacy', () async {
    final b = fixtures.bootstrap();
    (b['assets'] as List).first['sha256'] = 'b' * 64;
    final client = MockClient((request) async {
      if (request.url.path == '/releases/v2/latest.json') {
        return http.Response(
          jsonEncode({'bootstrap': b, 'stable': release('v1.4.3')}),
          200,
        );
      }
      fail('unexpected legacy request: ${request.url}');
    });
    final service = DownloadService(client: client);
    addTearDown(service.dispose);
    await expectLater(
      service.resolveRelease(DownloadChannel.stable),
      throwsFormatException,
    );
    await expectLater(
      service.resolveRelease(DownloadChannel.stable),
      throwsFormatException,
    );
  });

  test('no compatible v2 release fails without legacy fallback', () async {
    final latest = {
      'bootstrap': fixtures.bootstrap(),
      'stable': release('v1.5.0', zstd: true),
    };
    final client = MockClient((request) async {
      if (request.url.path == '/releases/v2/latest.json') {
        return http.Response(jsonEncode(latest), 200);
      }
      if (request.url.path == '/releases/v2/stable.json') {
        return http.Response(jsonEncode([release('v1.5.0', zstd: true)]), 200);
      }
      fail('unexpected legacy request: ${request.url}');
    });
    final service = DownloadService(client: client);
    addTearDown(service.dispose);
    await expectLater(
      service.resolveRelease(DownloadChannel.stable),
      throwsException,
    );
  });
}
