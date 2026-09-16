enum ConfigurationCategory {
  identity,
  wireGuard,
  uplink,
  radioGaga,
  settings,
  keycards,
}

class ConfigurationSource {
  const ConfigurationSource({
    required this.category,
    required this.sourcePath,
    required this.restorePath,
    required this.localName,
    this.rewriteRadioConfig = false,
  });

  final ConfigurationCategory category;
  final String sourcePath;
  final String restorePath;
  final String localName;
  final bool rewriteRadioConfig;
}

class ConfigurationInventory {
  const ConfigurationInventory(this.sources);

  final List<ConfigurationSource> sources;

  Set<ConfigurationCategory> get categories =>
      sources.map((source) => source.category).toSet();

  bool get isEmpty => sources.isEmpty;
}

class ConfigurationBackup {
  const ConfigurationBackup({
    required this.directoryPath,
    required this.categories,
  });

  final String directoryPath;
  final Set<ConfigurationCategory> categories;
}

class ConfigurationRestoreException implements Exception {
  const ConfigurationRestoreException(this.backupPath, this.reason);

  final String backupPath;
  final String reason;

  @override
  String toString() => '$reason Backup retained at: $backupPath';
}
