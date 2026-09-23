import 'install_plan.dart';

/// Keep the published timestamp spelling when os-release uses a lowercase t.
String displayVersion(String version) {
  final trimmed = version.trim();
  final timestamped = RegExp(
    r'^(nightly|testing)-(\d{8})[tT](\d{6})(.*)$',
    caseSensitive: false,
  ).firstMatch(trimmed);
  if (timestamped == null) return trimmed;
  return '${timestamped.group(1)!.toLowerCase()}-${timestamped.group(2)}T${timestamped.group(3)}${timestamped.group(4)}';
}

String installedVersionLabel(String distro, String version) {
  final displayed = displayVersion(version);
  return displayed.isEmpty ? distro : '$distro $displayed';
}

String targetVersionLabel(String distro, String channel, String tag) {
  final displayed = displayVersion(tag);
  return InstallPlan.channelOf(displayed) == channel
      ? '$distro $displayed'
      : '$distro $channel $displayed';
}
