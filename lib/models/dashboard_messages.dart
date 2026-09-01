/// What the trampoline prints on the dashboard while it works.
///
/// The template used to carry these as German literals, which left a garage
/// outside Germany unable to read the one instruction a dashboard install
/// cannot proceed without: swap the cable back. They are filled in here
/// instead, so the template holds no prose and the language belongs to
/// whoever started the run.
///
/// Not the same choice as the language persisted at the end of an install.
/// That one is the owner's dashboard language afterwards; these are what the
/// person doing the install reads while it runs, and in a workshop those are
/// frequently not the same person.
///
/// installer-cli fills the same placeholders from its own table, so the two
/// tools share one template rather than forking it. Changing a placeholder
/// name here means changing it there.
class DashboardMessages {
  const DashboardMessages({
    required this.banner,
    required this.installing,
    required this.installed,
    required this.running,
    required this.maps,
    required this.routing,
    required this.failed,
    required this.swap1,
    required this.swap2,
    required this.done,
    required this.failOnboot,
    required this.failDbc,
    required this.failTiles,
  });

  /// The line the dashboard console opens with, before there is any progress
  /// to report.
  final String banner;

  /// Firmware write started, expect a wait.
  final String installing;

  /// Written, the dashboard is about to restart.
  final String installed;

  /// The new firmware is up. Carries [versionToken], which the script on the
  /// vehicle expands; this side never learns the version.
  final String running;

  /// Display tiles going across.
  final String maps;

  /// Routing tiles going across.
  final String routing;

  final String failed;

  /// The cable-swap instruction, one console line each. Two rather than one
  /// because the dashboard console does not wrap.
  final String swap1;
  final String swap2;

  /// Finished, the scooter is unlocking.
  final String done;

  /// Why it failed. [failed] is the frame these appear under, so leaving them
  /// behind reads worse than not translating either: an operator who can read
  /// "Installation failed" and not the line under it knows only that
  /// something is wrong.
  final String failOnboot;
  final String failDbc;

  /// Carries [tileErrorsToken], counted by the script on the vehicle.
  final String failTiles;

  /// The shell variable the trampoline expands into [running] on the vehicle.
  /// It reaches the script as literal text, so it has to survive this side
  /// unexpanded, which is what the raw string at every use of it is for.
  static const versionToken = r'$DBC_VER';

  /// How many map transfers failed, likewise counted on the vehicle.
  static const tileErrorsToken = r'$TILE_ERRORS';

  Map<String, String> get placeholders => {
        '{{MSG_BANNER}}': banner,
        '{{MSG_INSTALLING}}': installing,
        '{{MSG_INSTALLED}}': installed,
        '{{MSG_RUNNING}}': running,
        '{{MSG_MAPS}}': maps,
        '{{MSG_ROUTING}}': routing,
        '{{MSG_FAILED}}': failed,
        '{{MSG_SWAP_1}}': swap1,
        '{{MSG_SWAP_2}}': swap2,
        '{{MSG_DONE}}': done,
        '{{MSG_FAIL_ONBOOT}}': failOnboot,
        '{{MSG_FAIL_DBC}}': failDbc,
        '{{MSG_FAIL_TILES}}': failTiles,
      };

  /// The set for a caller with no localisations to hand.
  ///
  /// English rather than German, despite German being what the template
  /// shipped with: an operator who did not choose a language gets more out of
  /// English, and a garage that wants German can ask for it.
  static const english = DashboardMessages(
    banner: 'Installing Librescoot',
    installing: 'Installing firmware, this takes a few minutes',
    installed: 'Firmware installed, display restarting',
    running: 'Firmware $versionToken running',
    maps: 'Transferring maps',
    routing: 'Transferring routing maps',
    failed: 'Installation failed',
    swap1: 'Plug the USB cable back into the MDB and',
    swap2: 'continue in the installer on the laptop.',
    done: 'Done. The scooter is unlocking now.',
    failOnboot: 'The part after the restart failed repeatedly.',
    failDbc: 'The display did not come back after flashing.',
    failTiles: '$tileErrorsToken map transfer(s) failed.',
  );
}
