import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/scooter_health.dart';
import '../theme.dart';

class HealthCheckPanel extends StatelessWidget {
  const HealthCheckPanel({super.key, required this.health});

  final ScooterHealth health;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row(l10n.auxBatteryCharge, '${health.auxCharge ?? '?'}%', '\u2265 50%', health.auxChargeOk),
          if (!health.auxChargeOk) _risk(l10n.riskAuxLow),
          _row(l10n.cbbStateOfHealth, '${health.cbbStateOfHealth ?? '?'}%', '\u2265 99%', health.cbbSohOk),
          if (!health.cbbSohOk) _risk(l10n.riskCbbSoh),
          _row(l10n.cbbCharge, '${health.cbbCharge ?? '?'}%', '\u2265 80%', health.cbbChargeOk),
          if (!health.cbbChargeOk) _risk(l10n.riskCbbCharge),
          _row(l10n.mainBattery, health.batteryPresent == true ? l10n.present : l10n.notPresent, '', health.batteryPresent != null),
          if (health.batteryPresent != true) _risk(l10n.riskNoBattery),
        ],
      ),
    );
  }

  Widget _risk(String message) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, bottom: 8),
      child: Text(message,
          style: TextStyle(fontSize: 12, color: Colors.orange.shade300)),
    );
  }

  Widget _row(String label, String value, String threshold, bool ok) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.error,
            size: 16,
            color: ok ? kAccent : Colors.orange,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          Text(value, style: TextStyle(
            fontSize: 13,
            fontFamily: 'monospace',
            color: ok ? kAccent : Colors.orange,
          )),
          if (threshold.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(threshold, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ],
        ],
      ),
    );
  }
}
