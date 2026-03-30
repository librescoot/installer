import 'dart:convert';
import 'package:http/http.dart' as http;

class Region {
  const Region({
    required this.name,
    required this.slug,
  });

  final String name;
  final String slug;

  /// Map ip-api.com regionName to our slug.
  static const _ipApiMap = {
    'Baden-Württemberg': 'baden-wuerttemberg',
    'Bavaria': 'bayern',
    'State of Berlin': 'berlin_brandenburg',
    'Brandenburg': 'berlin_brandenburg',
    'Free Hanseatic City of Bremen': 'bremen',
    'Free and Hanseatic City of Hamburg': 'hamburg',
    'Hesse': 'hessen',
    'Mecklenburg-Vorpommern': 'mecklenburg-vorpommern',
    'Lower Saxony': 'niedersachsen',
    'North Rhine-Westphalia': 'nordrhein-westfalen',
    'Rhineland-Palatinate': 'rheinland-pfalz',
    'Saarland': 'saarland',
    'Saxony': 'sachsen',
    'Saxony-Anhalt': 'sachsen-anhalt',
    'Schleswig-Holstein': 'schleswig-holstein',
    'Thuringia': 'thueringen',
  };

  /// Try to detect the user's region from their IP address.
  /// Returns null if detection fails or user is outside Germany.
  static Future<Region?> detectFromIp({http.Client? client}) async {
    try {
      final c = client ?? http.Client();
      final response = await c.get(Uri.parse('http://ip-api.com/json/?fields=countryCode,regionName'))
          .timeout(const Duration(seconds: 5));
      if (client == null) c.close();
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['countryCode'] != 'DE') return null;
      final regionName = data['regionName'] as String?;
      if (regionName == null) return null;
      final slug = _ipApiMap[regionName];
      if (slug == null) return null;
      return all.where((r) => r.slug == slug).firstOrNull;
    } catch (_) {
      return null;
    }
  }

  String get osmTilesFilename => 'tiles_$slug.mbtiles';
  String get osmTilesChecksumFilename => 'tiles_$slug.mbtiles.sha256';
  String get valhallaTilesFilename => 'valhalla_tiles_$slug.tar';
  String get valhallaTilesChecksumFilename => 'valhalla_tiles_$slug.tar.sha256';

  static const List<Region> all = [
    Region(name: 'Baden-Württemberg', slug: 'baden-wuerttemberg'),
    Region(name: 'Bayern', slug: 'bayern'),
    Region(name: 'Berlin & Brandenburg', slug: 'berlin_brandenburg'),
    Region(name: 'Bremen', slug: 'bremen'),
    Region(name: 'Hamburg', slug: 'hamburg'),
    Region(name: 'Hessen', slug: 'hessen'),
    Region(name: 'Mecklenburg-Vorpommern', slug: 'mecklenburg-vorpommern'),
    Region(name: 'Niedersachsen', slug: 'niedersachsen'),
    Region(name: 'Nordrhein-Westfalen', slug: 'nordrhein-westfalen'),
    Region(name: 'Rheinland-Pfalz', slug: 'rheinland-pfalz'),
    Region(name: 'Saarland', slug: 'saarland'),
    Region(name: 'Sachsen', slug: 'sachsen'),
    Region(name: 'Sachsen-Anhalt', slug: 'sachsen-anhalt'),
    Region(name: 'Schleswig-Holstein', slug: 'schleswig-holstein'),
    Region(name: 'Thüringen', slug: 'thueringen'),
  ];
}
