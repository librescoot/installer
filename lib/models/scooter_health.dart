class ScooterHealth {
  int? auxCharge;
  int? cbbStateOfHealth;
  int? cbbCharge;
  bool? batteryPresent;
  bool? cbbPresent;

  /// Null where the value was never read. A threshold applied to a missing
  /// reading answers about the reading rather than about the hardware, and
  /// renders as a failed check rather than an unasked question.
  bool? get auxChargeOk => auxCharge == null ? null : auxCharge! >= 50;
  bool? get cbbSohOk =>
      cbbStateOfHealth == null ? null : cbbStateOfHealth! >= 80;
  bool? get cbbChargeOk => cbbCharge == null ? null : cbbCharge! >= 80;

  /// Every precondition measured and met. An unread value is not a pass.
  bool get allOk =>
      auxChargeOk == true &&
      cbbSohOk == true &&
      cbbChargeOk == true &&
      batteryPresent != null;
}
