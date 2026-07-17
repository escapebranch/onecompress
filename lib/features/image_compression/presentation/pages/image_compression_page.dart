import 'package:flutter/material.dart';

import '../../../../core/widgets/section_card.dart';
import '../controllers/image_compression_controller.dart';
import '../widgets/compression_actions.dart';
import '../widgets/compression_header.dart';
import '../widgets/compression_progress_card.dart';
import '../widgets/compression_results_card.dart';
import '../widgets/compression_settings_card.dart';
import '../widgets/image_queue_card.dart';

class ImageCompressionPage extends StatefulWidget {
  const ImageCompressionPage({required this.controller, super.key});

  final ImageCompressionController controller;

  @override
  State<ImageCompressionPage> createState() => _ImageCompressionPageState();
}

class _ImageCompressionPageState extends State<ImageCompressionPage> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final theme = Theme.of(context);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF5F1E8), Color(0xFFE6F3EF), Color(0xFFFFF9EE)],
          ),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1240),
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      const CompressionHeader(),
                      const SizedBox(height: 20),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isCompact = constraints.maxWidth < 920;
                          if (isCompact) {
                            return Column(
                              children: [
                                CompressionSettingsCard(controller: controller),
                                const SizedBox(height: 16),
                                CompressionActions(controller: controller),
                              ],
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: CompressionSettingsCard(
                                  controller: controller,
                                ),
                              ),
                              const SizedBox(width: 16),
                              SizedBox(
                                width: 320,
                                child: CompressionActions(
                                  controller: controller,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      if (controller.isCompressing ||
                          controller.statusMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: CompressionProgressCard(
                            controller: controller,
                          ),
                        ),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isCompact = constraints.maxWidth < 920;
                          if (isCompact) {
                            return Column(
                              children: [
                                ImageQueueCard(controller: controller),
                                const SizedBox(height: 16),
                                CompressionResultsCard(controller: controller),
                              ],
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: ImageQueueCard(controller: controller),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: CompressionResultsCard(
                                  controller: controller,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      SectionCard(
                        child: Text(
                          'Phase 1 is built as a standalone feature module so future video, audio, PDF, archive, and batch workflows can slot into the same repository/use-case pattern without disturbing the UI shell.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _handleControllerChanged() {
    final errorMessage = widget.controller.errorMessage;
    if (errorMessage == null || !mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(errorMessage)));
  }
}
