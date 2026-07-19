import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/compression_preset.dart';
import '../controllers/image_compression_controller.dart';

class CompressionCustomizationBottomSheet extends StatefulWidget {
  const CompressionCustomizationBottomSheet({
    required this.controller,
    super.key,
  });

  final ImageCompressionController controller;

  static Future<void> show(BuildContext context, ImageCompressionController controller) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (context) => CompressionCustomizationBottomSheet(controller: controller),
    );
  }

  @override
  State<CompressionCustomizationBottomSheet> createState() =>
      _CompressionCustomizationBottomSheetState();
}

class _CompressionCustomizationBottomSheetState
    extends State<CompressionCustomizationBottomSheet> {

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final controller = widget.controller;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final preset = controller.preset;

        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.85, // Taller for unified view
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurface.withValues(alpha: 0.85)
                    : Colors.white.withValues(alpha: 0.95),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1)),
              ),
              child: Column(
                children: [
                  _buildHeader(context, isDark, controller),
                  
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle('Quick Presets', isDark),
                          const SizedBox(height: AppSpacing.sm),
                          _buildPresetsSection(controller, preset, isDark),
                          
                          const SizedBox(height: AppSpacing.xl),
                          
                          _buildSectionTitle('Quality & Format', isDark),
                          const SizedBox(height: AppSpacing.sm),
                          _buildQualityAndFormatSection(context, controller, preset, isDark),
                          
                          const SizedBox(height: AppSpacing.xl),
                          
                          _buildSectionTitle('Image Dimensions', isDark),
                          const SizedBox(height: AppSpacing.sm),
                          _buildResizeSection(controller, preset, isDark),
                          
                          const SizedBox(height: AppSpacing.xxl),
                        ],
                      ),
                    ),
                  ),

                  _buildApplyButton(context, isDark),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark, ImageCompressionController controller) {
    return Column(
      children: [
        const SizedBox(height: AppSpacing.sm),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: isDark ? Colors.white30 : Colors.black26,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Batch Customization',
                      style: AppTypography.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: isDark ? Colors.white : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      controller.selectedImages.isEmpty
                          ? 'Fine-tune global parameters'
                          : 'Customizing parameters for ${controller.selectedImages.length} file${controller.selectedImages.length == 1 ? '' : 's'}',
                      style: AppTypography.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                ),
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedCancel01,
                  color: AppColors.lightIcon,
                  size: 20,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: AppTypography.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: isDark ? Colors.white : AppColors.lightTextPrimary,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildPresetsSection(ImageCompressionController controller, CompressionPreset preset, bool isDark) {
    final presets = [
      CompressionPreset.balanced,
      CompressionPreset.light,
      CompressionPreset.aggressive,
    ];

    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: presets.length,
        separatorBuilder: (context, index) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final p = presets[index];
          final isSelected = preset.id == p.id;
          final activeBorder = isDark ? Colors.white : AppColors.lightTextPrimary;
          final inactiveBg = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03);
          final activeBg = isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.08);

          return GestureDetector(
            onTap: () => controller.selectPreset(p),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutBack,
              width: 140,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: isSelected ? activeBg : inactiveBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? activeBorder : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  HugeIcon(
                    icon: p.id == 'balanced' 
                        ? HugeIcons.strokeRoundedZap 
                        : (p.id == 'light' 
                            ? HugeIcons.strokeRoundedSparkles 
                            : HugeIcons.strokeRoundedArchive01),
                    color: isSelected 
                        ? (isDark ? Colors.white : AppColors.lightTextPrimary) 
                        : AppColors.lightIcon,
                    size: 24,
                  ),
                  const Spacer(),
                  Text(
                    p.label,
                    style: AppTypography.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    p.description,
                    style: AppTypography.textTheme.labelSmall?.copyWith(
                      color: isDark ? Colors.white70 : Colors.black54,
                      fontSize: 10,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQualityAndFormatSection(BuildContext context, ImageCompressionController controller, CompressionPreset preset, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Column(
        children: [
          // Quality Row
          Row(
            children: [
              Text(
                'Quality',
                style: AppTypography.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${preset.quality}%',
                  style: AppTypography.textTheme.labelMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: isDark ? Colors.white12 : Colors.black12,
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withValues(alpha: 0.2),
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
            ),
            child: Slider(
              value: preset.quality.toDouble(),
              min: 1,
              max: 100,
              divisions: 99,
              onChanged: (val) => controller.updateQuality(val),
            ),
          ),
          
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Divider(height: 1, color: Colors.white10),
          ),
          
          // Format Row
          Row(
            children: [
              Text(
                'Format',
                style: AppTypography.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const Spacer(),
              Wrap(
                spacing: 8,
                children: TargetFormat.values.map((fmt) {
                  final isSelected = preset.targetFormat == fmt;
                  return GestureDetector(
                    onTap: () => controller.updateTargetFormat(fmt),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? (isDark ? Colors.white : AppColors.lightTextPrimary)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected 
                              ? Colors.transparent 
                              : (isDark ? Colors.white24 : Colors.black26)
                        ),
                      ),
                      child: Text(
                        fmt.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                          color: isSelected 
                              ? (isDark ? Colors.black : Colors.white)
                              : (isDark ? Colors.white : Colors.black),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResizeSection(ImageCompressionController controller, CompressionPreset preset, bool isDark) {
    return Column(
      children: [
        _buildResizeTile(
          controller: controller,
          mode: const ImageResizeMode.none(),
          title: 'Original Dimensions',
          subtitle: 'Keep pixel resolution unchanged',
          icon: HugeIcons.strokeRoundedImage01,
          isSelected: preset.resizeMode.maybeWhen(none: () => true, orElse: () => false),
          isDark: isDark,
        ),
        const SizedBox(height: AppSpacing.sm),
        _buildResizeTile(
          controller: controller,
          mode: const ImageResizeMode.scalePercentage(75),
          title: 'Scale Down (75%)',
          subtitle: 'Reduce width & height by 25%',
          icon: HugeIcons.strokeRoundedMinimize01,
          isSelected: preset.resizeMode.maybeWhen(scalePercentage: (_) => true, orElse: () => false),
          isDark: isDark,
        ),
        const SizedBox(height: AppSpacing.sm),
        _buildResizeTile(
          controller: controller,
          mode: const ImageResizeMode.maxLongEdge(1920),
          title: 'Web Optimized (1920px)',
          subtitle: 'Cap maximum long edge to 1920px',
          icon: HugeIcons.strokeRoundedMaximize01,
          isSelected: preset.resizeMode.maybeWhen(maxLongEdge: (_) => true, orElse: () => false),
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildResizeTile({
    required ImageCompressionController controller,
    required ImageResizeMode mode,
    required String title,
    required String subtitle,
    required List<List<dynamic>> icon,
    required bool isSelected,
    required bool isDark,
  }) {
    final activeBorder = isDark ? Colors.white : AppColors.lightTextPrimary;
    final inactiveBg = isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02);
    final activeBg = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05);

    return GestureDetector(
      onTap: () => controller.updateResizeMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : inactiveBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeBorder : (isDark ? Colors.white10 : Colors.black12),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? activeBorder.withValues(alpha: 0.1) : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: HugeIcon(
                icon: icon,
                color: isSelected ? activeBorder : AppColors.lightIcon,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              HugeIcon(
                icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                color: activeBorder,
                size: 22,
              )
            else
              const SizedBox(width: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildApplyButton(BuildContext context, bool isDark) {
    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.md,
        bottom: MediaQuery.of(context).padding.bottom + AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface.withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.9),
        border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedCheckmarkCircle02,
            color: isDark ? Colors.black : Colors.white,
            size: 20,
          ),
          label: const Text('Apply Customization'),
          style: ElevatedButton.styleFrom(
            backgroundColor: isDark ? Colors.white : AppColors.lightTextPrimary,
            foregroundColor: isDark ? Colors.black : Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            textStyle: AppTypography.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}
