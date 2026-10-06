import 'package:flutter/material.dart';

import '../theme.dart';

class PreparationStep extends StatelessWidget {
  const PreparationStep({
    super.key,
    required this.number,
    required this.title,
    required this.description,
    this.images = const [],
    this.imageLabels = const [],
  });

  final int number;
  final String title;
  final String description;
  final List<String> images;
  final List<String> imageLabels;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$number. $title',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(description, style: const TextStyle(fontSize: 14, height: 1.4)),
          if (images.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                for (var i = 0; i < images.length; i++) ...[
                  if (i > 0)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(
                        Icons.arrow_forward,
                        size: 24,
                        color: kAccent,
                      ),
                    ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.asset(
                            images[i],
                            height: 260,
                            fit: BoxFit.contain,
                          ),
                        ),
                        if (i < imageLabels.length) ...[
                          const SizedBox(height: 6),
                          Text(
                            imageLabels[i],
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
