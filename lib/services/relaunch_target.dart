const outerWrapperPathEnvironment = 'LIBRESCOOT_OUTER_WRAPPER_PATH';

/// The command used to start a clean installer run from the finish screen.
class InstallAnotherRelaunch {
  const InstallAnotherRelaunch({
    required this.executable,
    required this.arguments,
  });

  final String executable;
  final List<String> arguments;

  /// Windows packages run this app from an NSIS temporary directory. NSIS
  /// provides its persistent wrapper path so the next run does not disappear
  /// when this process exits and its temporary directory is removed.
  factory InstallAnotherRelaunch.forPlatform({
    required bool isWindows,
    required String resolvedExecutable,
    required Map<String, String> environment,
    required String languageCode,
  }) {
    final wrapperPath = environment[outerWrapperPathEnvironment];
    return InstallAnotherRelaunch(
      executable: isWindows && wrapperPath != null && wrapperPath.isNotEmpty
          ? wrapperPath
          : resolvedExecutable,
      arguments: ['--lang=$languageCode'],
    );
  }
}
