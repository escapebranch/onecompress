import 'package:flutter/material.dart';

import '../../../../core/widgets/section_card.dart';
import '../../domain/entities/compression_preset.dart';
import '../controllers/image_compression_controller.dart';
import 'resize_settings_widget.dart';

class CompressionSettingsCard extends StatelessWidget {
  const CompressionSettingsCard({required this.controller, super.key});

  final ImageCompressionController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preset = controller.preset;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Text('Compression & Engine Settings', style: theme.textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Configure native Rust engine compression presets, target format, and multi-thread resize options.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          Text('Preset Mode', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: CompressionPreset.defaults
                .map(
                  (option) => ChoiceChip(
                    label: Text(option.label),
                    selected: preset.id == option.id,
                    onSelected: (_) => controller.selectPreset(option),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    preset.description,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Target Output Format', style: theme.textTheme.labelLarge),
              Text(
                preset.targetFormat.name.toUpperCase(),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SegmentedButton<TargetFormat>(
            segments: const [
              ButtonSegment(
                value: TargetFormat.auto,
                label: Text('Auto'),
                icon: Icon(Icons.auto_awesome_rounded),
              ),
              ButtonSegment(
                value: TargetFormat.jpeg,
                label: Text('JPEG'),
                icon: Icon(Icons.image_outlined),
              ),
              ButtonSegment(
                value: TargetFormat.png,
                label: Text('PNG'),
                icon: Icon(Icons.palette_outlined),
              ),
              ButtonSegment(
                value: TargetFormat.webp,
                label: Text('WebP'),
                icon: Icon(Icons.speed_rounded),
              ),
            ],
            selected: {preset.targetFormat},
            onSelectionChanged: (selection) {
              if (selection.isNotEmpty) {
                controller.updateTargetFormat(selection.first);
              }
            },
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Quality level', style: theme.textTheme.labelLarge),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${preset.quality}%',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: preset.quality.toDouble(),
            min: 40,
            max: 98,
            divisions: 29,
            label: '${preset.quality}%',
            onChanged: controller.updateQuality,
          ),
          const SizedBox(height: 16),
          ResizeSettingsWidget(controller: controller),
        ],
      ),
    );
  }
}
