import 'dart:convert';
import 'package:http/http.dart' as http;

class Region {
  const Region({
    required this.name,
    required this.slug,
    this.country = '',
  });

  final String name;
  final String slug;

  /// Country the region belongs to, used to group the dropdown. Empty for
  /// regions we don't recognise (they fall under [_unknownCountry]).
  final String country;

  static const _unknownCountry = 'Weitere';

  /// Known slugs, in dropdown order (grouped by country: German states first,
  /// then the neighbours). Single source of truth for [all], the offline
  /// fallback catalogue. Slugs published by the tile repos but missing here
  /// still work via [fromSlug], which humanises the slug.
  static const _catalog = <String, ({String name, String country})>{
    'baden-wuerttemberg': (name: 'Baden-Württemberg', country: 'Deutschland'),
    'bayern': (name: 'Bayern', country: 'Deutschland'),
    'berlin_brandenburg': (name: 'Berlin & Brandenburg', country: 'Deutschland'),
    'bremen': (name: 'Bremen', country: 'Deutschland'),
    'hamburg': (name: 'Hamburg', country: 'Deutschland'),
    'hessen': (name: 'Hessen', country: 'Deutschland'),
    'mecklenburg-vorpommern':
        (name: 'Mecklenburg-Vorpommern', country: 'Deutschland'),
    'niedersachsen': (name: 'Niedersachsen', country: 'Deutschland'),
    'nordrhein-westfalen': (name: 'Nordrhein-Westfalen', country: 'Deutschland'),
    'rheinland-pfalz': (name: 'Rheinland-Pfalz', country: 'Deutschland'),
    'saarland': (name: 'Saarland', country: 'Deutschland'),
    'sachsen': (name: 'Sachsen', country: 'Deutschland'),
    'sachsen-anhalt': (name: 'Sachsen-Anhalt', country: 'Deutschland'),
    'schleswig-holstein': (name: 'Schleswig-Holstein', country: 'Deutschland'),
    'thueringen': (name: 'Thüringen', country: 'Deutschland'),
    'belgium': (name: 'Belgien', country: 'Belgien'),
    'netherlands': (name: 'Niederlande', country: 'Niederlande'),
    'luxembourg': (name: 'Luxemburg', country: 'Luxemburg'),
    'ile-de-france': (name: 'Île-de-France', country: 'Frankreich'),
    'italy-nord-ovest': (name: 'Italien (Nordwest)', country: 'Italien'),
  };

  /// Map ipwho.is country_code -> region_code -> our slug. Keyed on the ISO
  /// 3166-2 subdivision code rather than the English region name, which is
  /// stable across the provider's localisation. Both Berlin (BE) and
  /// Brandenburg (BB) collapse to the combined berlin_brandenburg region.
  /// France and Italy only have partial coverage, so only the subdivisions
  /// whose tiles we publish map to a slug:
  ///   - FR Île-de-France (IDF)
  ///   - IT northwest (Piemonte 21, Valle d'Aosta 23, Lombardia 25, Liguria 42)
  /// Other subdivisions of those countries fall through to no match.
  static const _geoMap = <String, Map<String, String>>{
    'DE': {
      'BW': 'baden-wuerttemberg',
      'BY': 'bayern',
      'BE': 'berlin_brandenburg',
      'BB': 'berlin_brandenburg',
      'HB': 'bremen',
      'HH': 'hamburg',
      'HE': 'hessen',
      'MV': 'mecklenburg-vorpommern',
      'NI': 'niedersachsen',
      'NW': 'nordrhein-westfalen',
      'RP': 'rheinland-pfalz',
      'SL': 'saarland',
      'SN': 'sachsen',
      'ST': 'sachsen-anhalt',
      'SH': 'schleswig-holstein',
      'TH': 'thueringen',
    },
    'FR': {'IDF': 'ile-de-france'},
    'IT': {
      '21': 'italy-nord-ovest',
      '23': 'italy-nord-ovest',
      '25': 'italy-nord-ovest',
      '42': 'italy-nord-ovest',
    },
  };

  /// Countries we cover in full: any subdivision maps to the one slug. Checked
  /// after [_geoMap], so a region-level match always wins.
  static const _countryDefault = <String, String>{
    'BE': 'belgium',
    'NL': 'netherlands',
    'LU': 'luxembourg',
  };

  /// Build a Region for a slug, using a known display name and country if we
  /// have them and otherwise humanising the slug ("italy-nord-ovest" ->
  /// "Italy Nord Ovest") under the catch-all country group.
  factory Region.fromSlug(String slug) {
    final entry = _catalog[slug];
    return entry == null
        ? Region(name: _humanize(slug), slug: slug, country: _unknownCountry)
        : Region(name: entry.name, slug: slug, country: entry.country);
  }

  static String _humanize(String slug) => slug
      .split(RegExp(r'[-_]'))
      .where((w) => w.isNotEmpty)
      .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  /// Try to detect the user's region from their IP via ipwho.is (HTTPS).
  /// Returns the region slug, or null if detection fails or the location is
  /// not a region we map. The caller matches the slug against the regions it
  /// actually offers before preselecting.
  static Future<String?> detectSlugFromIp({http.Client? client}) async {
    try {
      final c = client ?? http.Client();
      final response = await c
          .get(Uri.parse(
              'https://ipwho.is/?fields=success,country_code,region_code'))
          .timeout(const Duration(seconds: 5));
      if (client == null) c.close();
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['success'] != true) return null;
      final countryCode = data['country_code'] as String?;
      final regionCode = data['region_code'] as String?;
      if (countryCode == null) return null;
      return _geoMap[countryCode]?[regionCode] ?? _countryDefault[countryCode];
    } catch (_) {
      return null;
    }
  }

  String get osmTilesFilename => 'tiles_$slug.mbtiles';
  String get osmTilesChecksumFilename => 'tiles_$slug.mbtiles.sha256';
  String get valhallaTilesFilename => 'valhalla_tiles_$slug.tar';
  String get valhallaTilesChecksumFilename => 'valhalla_tiles_$slug.tar.sha256';

  /// Known regions, used as the offline fallback when the published tile list
  /// can't be fetched. Identity is by slug, so a Region built here compares
  /// equal to one built by [fromSlug] from the live tile listing.
  static final List<Region> all = _catalog.entries
      .map((e) =>
          Region(name: e.value.name, slug: e.key, country: e.value.country))
      .toList(growable: false);

  @override
  bool operator ==(Object other) => other is Region && other.slug == slug;

  @override
  int get hashCode => slug.hashCode;
}
