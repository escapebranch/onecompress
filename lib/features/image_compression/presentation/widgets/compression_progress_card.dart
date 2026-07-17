import 'package:flutter/material.dart';

import '../../../../core/utils/percentage_formatter.dart';
import '../../../../core/widgets/section_card.dart';
import '../controllers/image_compression_controller.dart';

class CompressionProgressCard extends StatelessWidget {
  const CompressionProgressCard({required this.controller, super.key});

  final ImageCompressionController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Progress', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: controller.isCompressing ? controller.progress : 1,
              minHeight: 12,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            controller.statusMessage ?? 'Waiting for your next batch.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Progress: ${formatPercentage(controller.progress)}',
            style: theme.textTheme.labelLarge,
          ),
        ],
      ),
    );
  }
}
