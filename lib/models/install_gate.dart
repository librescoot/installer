bool canStartWelcome({
  required bool isProcessing,
  required bool localImagesOnly,
  required bool channelsLoading,
  required bool channelsLoadFailed,
  required bool hasChannels,
  required bool wantsOfflineMaps,
  required bool hasRegion,
}) {
  if (isProcessing) return false;
  if (localImagesOnly) return true;
  return !channelsLoading &&
      !channelsLoadFailed &&
      hasChannels &&
      (!wantsOfflineMaps || hasRegion);
}

bool canStartBluetoothPairing({required bool active, required bool starting}) =>
    !active && !starting;

bool canStartKeycardLearning({
  required bool learning,
  required bool starting,
}) => !learning && !starting;
