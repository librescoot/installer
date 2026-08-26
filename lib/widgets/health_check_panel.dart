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
          // A value nobody could read says so. "?%" next to a threshold reads
          // as a measurement that came in low, and the threshold itself is
          // noise when there is no number to compare against it.
          _row(
            l10n.auxBatteryCharge,
            // Charge is quantised to 25% steps by the firmware, so the volts
            // carry what decides whether a tired pack lasts an install. The
            // bootstrap image publishes voltage and no charge at all, so the
            // volts also stand alone: a reading we have is worth more than the
            // word for one we do not.
            switch ((health.auxCharge, health.auxVoltageMv)) {
              (final c?, final mv?) => '$c%  ${l10n.healthAuxVoltage(mv)}',
              (final c?, null) => '$c%',
              (null, final mv?) => l10n.healthAuxVoltage(mv),
              (null, null) => l10n.healthValueUnknown,
            },
            health.auxCharge == null ? '' : '\u2265 50%',
            health.auxChargeOk,
          ),
          if (health.auxChargeOk == false) _risk(l10n.riskAuxLow),
          if (health.cbbPresent == false)
            _row(l10n.cbbCharge, l10n.notPresent, '', null)
          else ...[
            _row(
              l10n.cbbStateOfHealth,
              health.cbbStateOfHealth == null
                  ? l10n.healthValueUnknown
                  : '${health.cbbStateOfHealth}%',
              health.cbbStateOfHealth == null ? '' : '\u2265 80%',
              health.cbbSohOk,
            ),
            if (health.cbbSohOk == false) _risk(l10n.riskCbbSoh),
            _row(
              l10n.cbbCharge,
              health.cbbCharge == null
                  ? l10n.healthValueUnknown
                  : '${health.cbbCharge}%',
              health.cbbCharge == null ? '' : '\u2265 80%',
              health.cbbChargeOk,
            ),
            if (health.cbbChargeOk == false) _risk(l10n.riskCbbCharge),
          ],
          _row(
            l10n.mainBattery,
            switch (health.batteryPresent) {
              true => l10n.present,
              false => l10n.notPresent,
              null => l10n.healthValueUnknown,
            },
            '',
            health.batteryPresent,
          ),
          // Only a pack that reported itself absent is a risk. One nobody
          // could ask about is an open question, and the row says so.
          if (health.batteryPresent == false) _risk(l10n.riskNoBattery),
          // Its own row rather than a figure in the one above, the same way
          // the CBB keeps charge and health apart: fitted and charged are
          // different questions and a board can pass one and fail the other.
          if (health.batteryCharge != null) ...[
            _row(
              l10n.mainBatteryCharge,
              '${health.batteryCharge}%',
              '\u2265 10%',
              health.batteryChargeOk,
            ),
            if (health.batteryChargeOk == false) _risk(l10n.riskMainBatteryLow),
          ],
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
