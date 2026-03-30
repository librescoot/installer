class Region {
  const Region({
    required this.name,
    required this.slug,
  });

  final String name;
  final String slug;

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
