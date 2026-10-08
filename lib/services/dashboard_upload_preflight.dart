Future<bool> prepareDashboardUpload({
  required bool Function() owns,
  required Future<void> Function() connectForStatus,
  required Future<void> Function() verifyUsbRoute,
  required Future<bool> Function() installerActive,
  required Future<void> Function() observeActive,
  required Future<void> Function() connectForWork,
}) async {
  if (!owns()) return false;
  await connectForStatus();
  if (!owns()) return false;
  await verifyUsbRoute();
  if (!owns()) return false;
  if (await installerActive()) {
    if (owns()) await observeActive();
    return false;
  }
  if (!owns()) return false;
  await connectForWork();
  if (!owns()) return false;
  await verifyUsbRoute();
  if (!owns()) return false;
  if (await installerActive()) {
    if (owns()) await observeActive();
    return false;
  }
  return owns();
}
