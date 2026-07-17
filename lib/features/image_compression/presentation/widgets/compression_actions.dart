import 'package:flutter/material.dart';

import '../../../../core/utils/byte_formatter.dart';
import '../../../../core/widgets/section_card.dart';
import '../controllers/image_compression_controller.dart';

class CompressionActions extends StatelessWidget {
  const CompressionActions({required this.controller, super.key});

  final ImageCompressionController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Actions', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Pick your images, compress them as a batch, then save or share the outputs.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: controller.pickImages,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('Select images'),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed:
                controller.selectedImages.isEmpty || controller.isCompressing
                ? null
                : controller.compress,
            icon: const Icon(Icons.auto_fix_high_outlined),
            label: const Text('Compress batch'),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: controller.compressedImages.isEmpty
                ? null
                : controller.saveCompressedImages,
            icon: const Icon(Icons.download_outlined),
            label: const Text('Save compressed files'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: controller.compressedImages.isEmpty
                ? null
                : controller.shareCompressedImages,
            icon: const Icon(Icons.ios_share_outlined),
            label: const Text('Share outputs'),
          ),
          const SizedBox(height: 20),
          Text(
            'Original total: ${formatBytes(controller.totalOriginalBytes)}',
            style: theme.textTheme.bodyMedium,
          ),
          Text(
            'Compressed total: ${formatBytes(controller.totalCompressedBytes)}',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
