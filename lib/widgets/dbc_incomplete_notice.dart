import 'package:flutter/material.dart';

import 'notice_card.dart';

class DbcIncompleteNotice extends StatelessWidget {
  const DbcIncompleteNotice({
    super.key,
    required this.title,
    required this.body,
    this.detailsLabel,
    this.onShowDetails,
  });

  final String title;
  final String body;
  final String? detailsLabel;
  final VoidCallback? onShowDetails;

  @override
  Widget build(BuildContext context) {
    final showDetails = detailsLabel != null && onShowDetails != null;
    return NoticeCard(
      severity: NoticeSeverity.danger,
      title: title,
      body: body,
      footer: showDetails
          ? TextButton.icon(
              onPressed: onShowDetails,
              icon: const Icon(Icons.description_outlined, size: 18),
              label: Text(detailsLabel!),
            )
          : null,
    );
  }
}
