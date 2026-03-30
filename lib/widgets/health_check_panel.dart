import 'package:flutter/material.dart';
import '../models/scooter_health.dart';

class HealthCheckPanel extends StatelessWidget {
  const HealthCheckPanel({super.key, required this.health});

  final ScooterHealth health;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row('AUX battery charge', '${health.auxCharge ?? '?'}%', '≥ 50%', health.auxChargeOk),
          _row('CBB state of health', '${health.cbbStateOfHealth ?? '?'}%', '≥ 99%', health.cbbSohOk),
          _row('CBB charge', '${health.cbbCharge ?? '?'}%', '≥ 80%', health.cbbChargeOk),
          _row('Main battery', health.batteryPresent == true ? 'present' : 'not present', '', health.batteryPresent != null),
        ],
      ),
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
            color: ok ? Colors.tealAccent : Colors.orange,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          Text(value, style: TextStyle(
            fontSize: 13,
            fontFamily: 'monospace',
            color: ok ? Colors.tealAccent : Colors.orange,
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
