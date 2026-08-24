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
          if (health.auxChargeOk == false) _risk(l10n.riskAuxLow),
          if (health.cbbPresent == false)
            _row(l10n.cbbCharge, l10n.notPresent, '', null)
          else ...[
            _row(l10n.cbbStateOfHealth, '${health.cbbStateOfHealth ?? '?'}%', '\u2265 80%', health.cbbSohOk),
            if (health.cbbSohOk == false) _risk(l10n.riskCbbSoh),
            _row(l10n.cbbCharge, '${health.cbbCharge ?? '?'}%', '\u2265 80%', health.cbbChargeOk),
            if (health.cbbChargeOk == false) _risk(l10n.riskCbbCharge),
          ],
          _row(l10n.mainBattery, health.batteryPresent == true ? l10n.present : l10n.notPresent, '', health.batteryPresent),
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

  /// [ok] null is a value that was never read: shown in grey with a neutral
  /// mark, so it reads as an open question rather than as a check that failed.
  Widget _row(String label, String value, String threshold, bool? ok) {
    final color = switch (ok) {
      true => kAccent,
      false => Colors.orange,
      null => Colors.grey.shade500,
    };
    final icon = switch (ok) {
      true => Icons.check_circle,
      false => Icons.error,
      null => Icons.help_outline,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          Text(value, style: TextStyle(
            fontSize: 13,
            fontFamily: 'monospace',
            color: color,
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
