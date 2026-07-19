import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/selected_image.dart';
import '../controllers/image_compression_controller.dart';
import '../widgets/format_chip_selector.dart';
import '../widgets/studio_bottom_bar.dart';
import '../widgets/studio_gallery_view.dart';
import '../widgets/image_preview_modal.dart';

class ImageCompressionPage extends StatefulWidget {
  const ImageCompressionPage({required this.controller, super.key});

  final ImageCompressionController controller;

  @override
  State<ImageCompressionPage> createState() => _ImageCompressionPageState();
}

class _ImageCompressionPageState extends State<ImageCompressionPage> {
  CompressMediaType _selectedMediaType = CompressMediaType.image;

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

  void _handleControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasCompressedImages = controller.compressedImages.isNotEmpty;

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
          // Header Download Button (Wireframe 3)
          if (hasCompressedImages)
            IconButton(
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedDownload01,
                color: AppColors.primary,
                size: 22,
              ),
              onPressed: () => _handleSaveAll(context),
              tooltip: 'Save All Compressed Images',
            ),

          // Clear Selection Button
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
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.xs),

            // 1. TOP FORMAT CHIPS STRIP (Wireframe 1: Supported Types chip-styled)
            FormatChipSelector(
              selectedType: _selectedMediaType,
              onSelectType: (type) {
                setState(() => _selectedMediaType = type);
              },
            ),

            const SizedBox(height: AppSpacing.md),

            // 2. MAIN GALLERY WORKSPACE
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Column(
                  children: [
                    StudioGalleryView(
                      controller: controller,
                      onPickImages: controller.pickImages,
                      onTapImageItem: (item) => _handleImageItemTap(context, item),
                    )
                        .animate()
                        .fadeIn(duration: 350.ms)
                        .slideY(begin: 0.03, end: 0),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),

            // 3. DOCKED BOTTOM BAR COMMANDER (Wireframes 1, 2, 3)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: StudioBottomBar(
                controller: controller,
                onPickImages: controller.pickImages,
                onCompressPressed: controller.compress,
                onSaveAllPressed: () => _handleSaveAll(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSaveAll(BuildContext context) async {
    final savePath = await widget.controller.saveCompressedImages();
    if (!context.mounted) return;
    if (savePath != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkCircle02, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Saved ${widget.controller.compressedImages.length} compressed image(s) to OneCompress folder!',
                  ),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
    }
  }

  void _handleImageItemTap(BuildContext context, SelectedImage item) {
    ImagePreviewModal.show(context, item, widget.controller);
  }
}
