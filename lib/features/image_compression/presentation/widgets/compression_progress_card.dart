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
    final isCompressing = controller.isCompressing;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.bolt_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text('Rayon Parallel Batch Engine', style: theme.textTheme.titleLarge),
                ],
              ),
              if (isCompressing)
                OutlinedButton.icon(
                  onPressed: controller.cancelCompression,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Cancel'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: isCompressing ? controller.progress : 1,
              minHeight: 12,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  controller.statusMessage ?? 'Waiting for your next batch.',
                  style: theme.textTheme.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  formatPercentage(controller.progress),
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
          if (controller.processingSpeedMBps > 0 || controller.elapsedMilliseconds > 0) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                if (controller.processingSpeedMBps > 0)
                  Chip(
                    avatar: const Icon(Icons.speed_rounded, size: 16),
                    label: Text('${controller.processingSpeedMBps.toStringAsFixed(1)} MB/s'),
                    visualDensity: VisualDensity.compact,
                  ),
                if (controller.elapsedMilliseconds > 0)
                  Chip(
                    avatar: const Icon(Icons.timer_outlined, size: 16),
                    label: Text('${controller.elapsedMilliseconds} ms'),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
