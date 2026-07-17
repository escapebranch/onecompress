import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/utils/byte_formatter.dart';
import '../../../../core/widgets/section_card.dart';
import '../controllers/image_compression_controller.dart';

class ImageQueueCard extends StatelessWidget {
  const ImageQueueCard({required this.controller, super.key});

  final ImageCompressionController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final images = controller.selectedImages;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Selected images', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            images.isEmpty
                ? 'Pick one or more images to preview them here before compression.'
                : '${images.length} file${images.length == 1 ? '' : 's'} queued.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          if (images.isEmpty)
            const _EmptyQueue()
          else
            ...images.map((image) {
              final result = controller.resultFor(image.path);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: 52,
                        height: 52,
                        child: Image.file(
                          File(image.path),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const ColoredBox(
                            color: Color(0xFFE7E2D9),
                            child: Icon(Icons.image_not_supported_outlined),
                          ),
                        ),
                      ),
                    ),
                    title: Text(image.fileName),
                    subtitle: Text(
                      result == null
                          ? formatBytes(image.originalBytes)
                          : '${formatBytes(image.originalBytes)} -> ${formatBytes(result.compressedBytes)}',
                    ),
                    trailing: result == null
                        ? const Icon(Icons.schedule_outlined)
                        : const Icon(Icons.check_circle_outline),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _EmptyQueue extends StatelessWidget {
  const _EmptyQueue();

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
        'The queue stays separate from the compression engine so future formats can reuse the same selection and progress workflow.',
        style: theme.textTheme.bodyMedium,
      ),
    );
  }
}
