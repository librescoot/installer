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
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$number. $title',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(description, style: const TextStyle(fontSize: 14, height: 1.4)),
      ],
    );
    final photos = Row(
      children: [
        for (var i = 0; i < images.length; i++) ...[
          if (i > 0)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Icons.arrow_forward, size: 18, color: kAccent),
            ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(images[i], height: 165, fit: BoxFit.contain),
                  if (i < imageLabels.length)
                    Text(imageLabels[i], style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (images.isEmpty) return text;
          if (constraints.maxWidth < 600) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [text, const SizedBox(height: 10), photos],
            );
          }
          return Row(
            children: [
              Expanded(flex: 5, child: text),
              const SizedBox(width: 18),
              Expanded(flex: 6, child: photos),
            ],
          );
        },
      ),
    );
  }
}
