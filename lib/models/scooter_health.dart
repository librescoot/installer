class ScooterHealth {
  int? auxCharge;
  int? cbbStateOfHealth;
  int? cbbCharge;
  bool? batteryPresent;
  bool? cbbPresent;

  /// Main pack charge in percent.
  int? batteryCharge;

  /// Corrected terminal voltage in mV. Predicts whether the pack survives a
  /// long install better than the charge does: the firmware quantises charge
  /// to 25% steps, so 100% covers everything from 12543 mV upward.
  int? auxVoltageMv;

  /// Null where the value was never read. A threshold applied to a missing
  /// reading answers about the reading rather than about the hardware, and
  /// renders as a failed check rather than an unasked question.
  bool? get auxChargeOk => auxCharge == null ? null : auxCharge! >= 50;
  bool? get cbbSohOk =>
      cbbStateOfHealth == null ? null : cbbStateOfHealth! >= 80;
  bool? get cbbChargeOk => cbbCharge == null ? null : cbbCharge! >= 80;

  /// A warning rather than a precondition, which is why it is not in [allOk].
  /// The board runs off the AUX battery, so an install completes on a nearly
  /// flat pack; what it costs is the scooter afterwards, and a bench left on
  /// a pack this low goes flat overnight.
  /// Null without a fitted pack: the hash carries a 0 for one that is not
  /// there, and judging that is how "not present" and "nearly empty" came to
  /// stand on the same screen.
  bool? get batteryChargeOk => batteryPresent != true || batteryCharge == null
      ? null
      : batteryCharge! >= 10;

  /// Every precondition measured and met. An unread value is not a pass.
  bool get allOk =>
      auxChargeOk == true &&
      cbbSohOk == true &&
      cbbChargeOk == true &&
      batteryPresent != null;
}
