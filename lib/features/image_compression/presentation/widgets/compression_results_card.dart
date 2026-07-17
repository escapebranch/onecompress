import 'package:flutter/material.dart';

import '../../../../core/utils/byte_formatter.dart';
import '../../../../core/utils/percentage_formatter.dart';
import '../../../../core/widgets/section_card.dart';
import '../controllers/image_compression_controller.dart';

class CompressionResultsCard extends StatelessWidget {
  const CompressionResultsCard({required this.controller, super.key});

  final ImageCompressionController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final results = controller.compressedImages;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Results', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            results.isEmpty
                ? 'Compressed files will appear here with side-by-side size comparisons.'
                : '${results.length} compressed image${results.length == 1 ? '' : 's'} ready.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          if (results.isEmpty)
            const _EmptyState()
          else
            ...results.map(
              (result) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: Text(result.outputFileName),
                    subtitle: Text(
                      '${formatBytes(result.originalBytes)} -> ${formatBytes(result.compressedBytes)}',
                    ),
                    trailing: Text(
                      formatPercentage(result.savingsRatio),
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text(
        'Run your first batch to unlock export and sharing.',
        style: theme.textTheme.bodyMedium,
      ),
    );
  }
}
