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
    extends State<CompressionCustomizationBottomSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurface.withValues(alpha: 0.95)
                    : Colors.white.withValues(alpha: 0.95),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  // Drag handle & Header
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white30 : Colors.black26,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Batch Customization',
                              style: AppTypography.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : AppColors.lightTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              controller.selectedImages.isEmpty
                                  ? 'Fine-tune quality, target format & dimensions'
                                  : 'Customizing parameters for ${controller.selectedImages.length} batch file${controller.selectedImages.length == 1 ? '' : 's'}',
                              style: AppTypography.textTheme.bodySmall?.copyWith(
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const HugeIcon(
                            icon: HugeIcons.strokeRoundedCancel01,
                            color: AppColors.lightIcon,
                            size: 22,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.sm),

                  // TAB BAR SYSTEM
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      indicator: BoxDecoration(
                        color: isDark ? Colors.white : AppColors.lightTextPrimary,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.2)
                                : Colors.black.withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      labelColor: isDark ? Colors.black : Colors.white,
                      unselectedLabelColor:
                          isDark ? AppColors.darkIcon : AppColors.lightIcon,
                      labelStyle: AppTypography.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      tabs: const [
                        Tab(text: 'Compression'),
                        Tab(text: 'Resize'),
                        Tab(text: 'Presets'),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.sm),

                  // TAB VIEW CONTENT
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // Tab 1: Compression Quality & Format
                        _buildCompressionTab(context, controller, preset, isDark),

                        // Tab 2: Resize Options
                        _buildResizeTab(context, controller, preset, isDark),

                        // Tab 3: Quick Presets
                        _buildPresetsTab(context, controller, preset, isDark),
                      ],
                    ),
                  ),

                  // Apply / Close CTA Button
                  Padding(
                    padding: EdgeInsets.only(
                      left: AppSpacing.md,
                      right: AppSpacing.md,
                      top: AppSpacing.sm,
                      bottom: MediaQuery.of(context).padding.bottom + AppSpacing.sm,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
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
                            borderRadius: BorderRadius.circular(25),
                          ),
                          textStyle: AppTypography.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompressionTab(
    BuildContext context,
    ImageCompressionController controller,
    CompressionPreset preset,
    bool isDark,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quality Slider Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Compression Quality',
                style: AppTypography.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${preset.quality}%',
                  style: AppTypography.textTheme.labelMedium?.copyWith(
                    color: isDark ? Colors.white : AppColors.lightTextPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),

          // Slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: isDark ? Colors.white : AppColors.lightTextPrimary,
              inactiveTrackColor: isDark ? Colors.white12 : Colors.black12,
              thumbColor: isDark ? Colors.white : AppColors.lightTextPrimary,
              overlayColor: (isDark ? Colors.white : AppColors.lightTextPrimary).withValues(alpha: 0.2),
              trackHeight: 6,
            ),
            child: Slider(
              value: preset.quality.toDouble(),
              min: 1,
              max: 100,
              divisions: 99,
              onChanged: (val) => controller.updateQuality(val),
            ),
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '⚡ Maximum Savings',
                style: AppTypography.textTheme.bodySmall?.copyWith(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  fontSize: 11,
                ),
              ),
              Text(
                '💎 Maximum Quality',
                style: AppTypography.textTheme.bodySmall?.copyWith(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.lg),

          // Target Format Selector
          Text(
            'Target Output Format',
            style: AppTypography.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          Wrap(
            spacing: AppSpacing.xs + 2,
            runSpacing: AppSpacing.xs,
            children: TargetFormat.values.map((fmt) {
              final isSelected = preset.targetFormat == fmt;
              final selectedBg = isDark ? Colors.white : AppColors.lightTextPrimary;
              final selectedFg = isDark ? Colors.black : Colors.white;

              return ChoiceChip(
                label: Text(fmt.label),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) controller.updateTargetFormat(fmt);
                },
                selectedColor: selectedBg,
                labelStyle: AppTypography.textTheme.labelMedium?.copyWith(
                  color: isSelected
                      ? selectedFg
                      : (isDark ? Colors.white70 : Colors.black87),
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.04),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isSelected
                        ? selectedBg
                        : (isDark ? Colors.white10 : Colors.black12),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildResizeTab(
    BuildContext context,
    ImageCompressionController controller,
    CompressionPreset preset,
    bool isDark,
  ) {
    final isNoneSelected = preset.resizeMode.maybeWhen(none: () => true, orElse: () => false);
    final isScaleSelected = preset.resizeMode.maybeWhen(scalePercentage: (_) => true, orElse: () => false);
    final isMaxLongSelected = preset.resizeMode.maybeWhen(maxLongEdge: (_) => true, orElse: () => false);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resize Mode',
            style: AppTypography.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Control exact image dimensions to optimize size for social media or web',
            style: AppTypography.textTheme.bodySmall?.copyWith(
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Resize Modes List
          _buildResizeOptionTile(
            context,
            controller: controller,
            mode: const ImageResizeMode.none(),
            title: 'Original Dimensions',
            subtitle: 'Keep original pixel resolution',
            icon: HugeIcons.strokeRoundedImage01,
            isSelected: isNoneSelected,
            isDark: isDark,
          ),
          const SizedBox(height: AppSpacing.xs),
          _buildResizeOptionTile(
            context,
            controller: controller,
            mode: const ImageResizeMode.scalePercentage(75),
            title: 'Scale Down (75%)',
            subtitle: 'Reduce dimensions by 25%',
            icon: HugeIcons.strokeRoundedMinimize01,
            isSelected: isScaleSelected,
            isDark: isDark,
          ),
          const SizedBox(height: AppSpacing.xs),
          _buildResizeOptionTile(
            context,
            controller: controller,
            mode: const ImageResizeMode.maxLongEdge(1920),
            title: 'Max Long Edge (1920px)',
            subtitle: 'Ideal for Full HD web display',
            icon: HugeIcons.strokeRoundedMaximize01,
            isSelected: isMaxLongSelected,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildResizeOptionTile(
    BuildContext context, {
    required ImageCompressionController controller,
    required ImageResizeMode mode,
    required String title,
    required String subtitle,
    required List<List<dynamic>> icon,
    required bool isSelected,
    required bool isDark,
  }) {
    final activeBorderColor = isDark ? Colors.white : AppColors.lightTextPrimary;
    final activeBgColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.06);

    return GestureDetector(
      onTap: () => controller.updateResizeMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isSelected
              ? activeBgColor
              : (isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.black.withValues(alpha: 0.03)),
          borderRadius: BorderRadius.circular(16),
          border: isSelected ? Border.all(color: activeBorderColor, width: 1.5) : null,
        ),
        child: Row(
          children: [
            HugeIcon(
              icon: icon,
              color: isSelected ? activeBorderColor : AppColors.lightIcon,
              size: 22,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.textTheme.bodySmall?.copyWith(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              HugeIcon(
                icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                color: activeBorderColor,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetsTab(
    BuildContext context,
    ImageCompressionController controller,
    CompressionPreset preset,
    bool isDark,
  ) {
    final presets = [
      CompressionPreset.balanced,
      CompressionPreset.light,
      CompressionPreset.aggressive,
    ];

    final activeBorderColor = isDark ? Colors.white : AppColors.lightTextPrimary;
    final activeBgColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.06);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recommended Presets',
            style: AppTypography.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          ...presets.map((p) {
            final isSelected = preset.id == p.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs + 2),
              child: GestureDetector(
                onTap: () => controller.selectPreset(p),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? activeBgColor
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.04)
                            : Colors.black.withValues(alpha: 0.03)),
                    borderRadius: BorderRadius.circular(16),
                    border: isSelected ? Border.all(color: activeBorderColor, width: 1.5) : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.1))
                              : (isDark ? Colors.white10 : Colors.black12),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          p.id == 'balanced'
                              ? '⚡'
                              : (p.id == 'light' ? '💎' : '📦'),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.label,
                              style: AppTypography.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : AppColors.lightTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              p.description,
                              style: AppTypography.textTheme.bodySmall?.copyWith(
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                          color: activeBorderColor,
                          size: 22,
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
