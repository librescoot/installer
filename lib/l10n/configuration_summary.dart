import 'app_localizations.dart';

String configurationDetectedSummary(
  AppLocalizations l10n,
  List<String> labels,
) {
  assert(labels.isNotEmpty);
  final names = labels.length == 1
      ? labels.single
      : '${labels.take(labels.length - 1).join(', ')}${l10n.configurationListAnd}${labels.last}';
  return l10n.configurationTransferable(names);
}
