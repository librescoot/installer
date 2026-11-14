import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/ota_capability_policy.dart';

Map<String, dynamic> bootstrap() => {
  'tag_name': 'v1.3.0',
  'assets': [
    {
      'name': 'librescoot-unu-mdb-minimal-v1.3.0.sdimg.gz',
      'sha256':
          '0066a5fd38b9bcd7bbc9496212a0c5ca8f136c02481c859c6767642ac52718f2',
    },
    {
      'name': 'librescoot-unu-dbc-minimal-v1.3.0.sdimg.gz',
      'sha256':
          'cf7cb6d318c23f24fc280acfc53421afe14b6a3cfca12806ade823e8400c684f',
    },
  ],
};

Map<String, dynamic> full(String variant) => {
  'name': 'librescoot-$variant-v1.4.3.mender',
  'size': 100,
  'sha256': 'a' * 64,
  'url': 'https://example.test/image',
  'ota': {
    'schema': 1,
    'kind': 'full',
    'variant': variant,
    'artifact': 'release-v1.4.3',
    'payload_compression': 'gzip',
    'requires': ['artifact.mender-v3', 'payload.gzip'],
  },
};

void main() {
  test('stage-0 capability profile is bound to both exact image hashes', () {
    final b = bootstrap();
    expect(OtaCapabilityPolicy.supportsBootstrap(b), isTrue);
    (b['assets'] as List).first['sha256'] = 'b' * 64;
    expect(OtaCapabilityPolicy.supportsBootstrap(b), isFalse);
  });

  test('both boards need eligible gzip images', () {
    final release = {
      'tag_name': 'v1.4.3',
      'assets': [full('unu-mdb'), full('unu-dbc')],
    };
    expect(OtaCapabilityPolicy.eligibleRelease(release), isTrue);
    final dbc = (release['assets'] as List).last as Map<String, dynamic>;
    (dbc['ota'] as Map<String, dynamic>)['payload_compression'] = 'zstd';
    expect(OtaCapabilityPolicy.eligibleRelease(release), isFalse);
  });

  test('unknown and missing requirements fail closed', () {
    final asset = full('unu-mdb');
    final ota = asset['ota'] as Map<String, dynamic>;
    expect(
      OtaCapabilityPolicy.eligibleFull(asset, 'v1.4.3', 'unu-mdb'),
      isTrue,
    );
    ota['requires'] = ['artifact.mender-v3', 'payload.gzip', 'future.format'];
    expect(
      OtaCapabilityPolicy.eligibleFull(asset, 'v1.4.3', 'unu-mdb'),
      isFalse,
    );
    ota['requires'] = ['artifact.mender-v3'];
    expect(
      OtaCapabilityPolicy.eligibleFull(asset, 'v1.4.3', 'unu-mdb'),
      isFalse,
    );
    ota['requires'] = ['artifact.mender-v3', 'payload.gzip', 'payload.gzip'];
    expect(
      OtaCapabilityPolicy.eligibleFull(asset, 'v1.4.3', 'unu-mdb'),
      isFalse,
    );
  });

  test('digest, URL, exact variant and target are mandatory', () {
    for (final mutate in <void Function(Map<String, dynamic>)>[
      (a) => a['sha256'] = '',
      (a) => a['url'] = 'http://example.test/image',
      (a) => a['name'] = 'librescoot-unu-mdb-minimal-v1.4.3.mender',
      (a) => (a['ota'] as Map<String, dynamic>)['artifact'] = 'release-v1.4.2',
      (a) => (a['ota'] as Map<String, dynamic>)['schema'] = 2,
    ]) {
      final asset = full('unu-mdb');
      mutate(asset);
      expect(
        OtaCapabilityPolicy.eligibleFull(asset, 'v1.4.3', 'unu-mdb'),
        isFalse,
      );
    }
  });
}
