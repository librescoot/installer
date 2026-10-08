import 'installer_sounds.dart';

InstallerCue? keycardLearningErrorCue(
  String payload, {
  required bool learningCards,
  required bool learningMaster,
}) {
  if (learningCards && payload.startsWith('card-duplicate:')) {
    return InstallerCue.error;
  }
  if (learningMaster && payload.startsWith('rejected:already-authorized:')) {
    return InstallerCue.error;
  }
  if ((learningCards || learningMaster) &&
      payload.startsWith('error:save-failed:')) {
    return InstallerCue.error;
  }
  return null;
}
