import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../domain/entities/compression_preset.dart';
import '../controllers/image_compression_controller.dart';
import '../widgets/compression_customization_bottom_sheet.dart';
import '../widgets/compression_progress_card.dart';
import '../widgets/compression_results_card.dart';

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: Colors.white,
            size: 24,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Compress Studio',
          style: AppTypography.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppColors.lightTextPrimary,
          ),
        ),
        actions: [
          if (controller.selectedImages.isNotEmpty)
            IconButton(
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedDelete02,
                color: AppColors.error,
                size: 22,
              ),
              onPressed: controller.clearAll,
              tooltip: 'Clear Selection',
            ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final hasImages = controller.selectedImages.isNotEmpty;

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!hasImages) ...[
                    // HERO UPLOAD DROPZONE AREA
                    _buildUploadDropzone(context, isDark)
                        .animate()
                        .fadeIn(duration: 400.ms)
                        .scale(begin: const Offset(0.97, 0.97), end: const Offset(1, 1)),

                    const SizedBox(height: AppSpacing.xl),
                  ] else ...[
                    // SELECTED IMAGES PREVIEW CARDS
                    _buildSelectedImagesPreview(context, controller, isDark)
                        .animate()
                        .fadeIn(duration: 350.ms)
                        .slideY(begin: 0.05, end: 0),

                    const SizedBox(height: AppSpacing.md),

                    // CUSTOMIZATION TRIGGER BUTTON
                    _buildCustomizationTrigger(context, controller, isDark)
                        .animate()
                        .fadeIn(delay: 100.ms, duration: 350.ms),

                    const SizedBox(height: AppSpacing.lg),

                    // COMPRESS CTA ACTION BUTTON
                    _buildCompressActionButton(context, controller, isDark)
                        .animate()
                        .fadeIn(delay: 150.ms, duration: 350.ms),

                    const SizedBox(height: AppSpacing.lg),
                  ],

                  // PROGRESS SECTION (IF COMPRESSING)
                  if (controller.isCompressing || controller.statusMessage != null) ...[
                    CompressionProgressCard(controller: controller)
                        .animate()
                        .fadeIn(duration: 300.ms),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  // RESULTS SECTION (IF COMPRESSED IMAGES EXIST)
                  if (controller.compressedImages.isNotEmpty) ...[
                    Text(
                      'Compression Results',
                      style: AppTypography.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    CompressionResultsCard(controller: controller)
                        .animate()
                        .fadeIn(duration: 400.ms)
                        .slideY(begin: 0.1, end: 0),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildUploadDropzone(BuildContext context, bool isDark) {
    return GlassCard(
      onTap: widget.controller.pickImages,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xxl + 8,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: const Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedImageAdd01,
                color: AppColors.primary,
                size: 42,
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          Text(
            'Upload Images to Compress',
            textAlign: TextAlign.center,
            style: AppTypography.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Tap anywhere to choose files from device\nSupports JPEG, PNG, WebP, AVIF & multi-selection',
            textAlign: TextAlign.center,
            style: AppTypography.textTheme.bodyMedium?.copyWith(
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              height: 1.4,
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          ElevatedButton.icon(
            onPressed: widget.controller.pickImages,
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedFolderAdd,
              color: Colors.white,
              size: 20,
            ),
            label: const Text('Choose Files'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xxl,
                vertical: AppSpacing.md,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 6,
              shadowColor: AppColors.primary.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedImagesPreview(
    BuildContext context,
    ImageCompressionController controller,
    bool isDark,
  ) {
    final images = controller.selectedImages;
    final totalBytes = controller.totalOriginalBytes;
    final totalMb = (totalBytes / (1024 * 1024)).toStringAsFixed(2);

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const HugeIcon(
                    icon: HugeIcons.strokeRoundedImage01,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    '${images.length} Image${images.length == 1 ? "" : "s"} Selected ($totalMb MB)',
                    style: AppTypography.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.lightTextPrimary,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: controller.pickImages,
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedAdd01,
                  color: AppColors.primary,
                  size: 16,
                ),
                label: const Text('Add More'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Horizontal Preview List of Selected Images
          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, index) {
                final item = images[index];
                final mb = (item.originalBytes / (1024 * 1024)).toStringAsFixed(1);

                return Stack(
                  children: [
                    Container(
                      width: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? Colors.white24 : Colors.black12,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.file(
                        File(item.path),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: isDark ? Colors.white10 : Colors.black12,
                          child: const Icon(Icons.image, color: Colors.grey),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$mb MB',
                          style: AppTypography.textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => controller.removeSelectedImage(item),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomizationTrigger(
    BuildContext context,
    ImageCompressionController controller,
    bool isDark,
  ) {
    final preset = controller.preset;

    return GlassCard(
      onTap: () => CompressionCustomizationBottomSheet.show(context, controller),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 4,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xs + 2),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const HugeIcon(
              icon: HugeIcons.strokeRoundedSettings01,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Customization & Preset',
                  style: AppTypography.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${preset.quality}% Quality • ${preset.targetFormat.label}',
                  style: AppTypography.textTheme.bodySmall?.copyWith(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'Tune',
              style: AppTypography.textTheme.labelMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompressActionButton(
    BuildContext context,
    ImageCompressionController controller,
    bool isDark,
  ) {
    final isCompressing = controller.isCompressing;

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: isCompressing ? null : controller.compress,
        icon: isCompressing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : const HugeIcon(
                icon: HugeIcons.strokeRoundedArchive01,
                color: Colors.white,
                size: 22,
              ),
        label: Text(
          isCompressing
              ? 'Compressing Files...'
              : 'Compress ${controller.selectedImages.length} File${controller.selectedImages.length == 1 ? "" : "s"}',
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 6,
          shadowColor: AppColors.primary.withValues(alpha: 0.45),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(27),
          ),
          textStyle: AppTypography.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
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
