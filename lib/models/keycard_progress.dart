int reconciledKeycardTotal({
  required int before,
  required int observed,
  required int? stored,
}) {
  final eventTotal = before + observed;
  return stored != null && stored > eventTotal ? stored : eventTotal;
}
