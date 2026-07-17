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
          Text('Compression settings', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Choose a preset, then fine-tune quality for your current batch.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
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
          const SizedBox(height: 20),
          Text('${preset.label} preset', style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(preset.description, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 20),
          Text('Quality: ${preset.quality}', style: theme.textTheme.titleSmall),
          Slider(
            value: preset.quality.toDouble(),
            min: 40,
            max: 95,
            divisions: 11,
            label: '${preset.quality}',
            onChanged: controller.updateQuality,
          ),
          const SizedBox(height: 20),
          ResizeSettingsWidget(controller: controller),
        ],
      ),
    );
  }
}
