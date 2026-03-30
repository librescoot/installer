class ScooterHealth {
  int? auxCharge;
  int? cbbStateOfHealth;
  int? cbbCharge;
  bool? batteryPresent;

  bool get auxChargeOk => (auxCharge ?? 0) >= 50;
  bool get cbbSohOk => (cbbStateOfHealth ?? 0) >= 99;
  bool get cbbChargeOk => (cbbCharge ?? 0) >= 80;
  bool get allOk => auxChargeOk && cbbSohOk && cbbChargeOk && batteryPresent != null;
}
