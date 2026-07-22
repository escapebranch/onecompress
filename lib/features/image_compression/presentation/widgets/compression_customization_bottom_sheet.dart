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

  static Future<void> show(
    BuildContext context,
    ImageCompressionController controller,
  ) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (context) =>
          CompressionCustomizationBottomSheet(controller: controller),
    );
  }

  @override
  State<CompressionCustomizationBottomSheet> createState() =>
      _CompressionCustomizationBottomSheetState();
}

class _CompressionCustomizationBottomSheetState
    extends State<CompressionCustomizationBottomSheet> {
  int _modeIndex = 0; // 0: Target File Size, 1: Quality Percentage
  bool _isMB = true;
  double _targetValue = 1.0;
  late TextEditingController _targetSizeController;

  @override
  void initState() {
    super.initState();
    final preset = widget.controller.preset;
    final originalBytes = widget.controller.detectedOriginalBytes;

    if (preset.isTargetSizeMode) {
      _modeIndex = 0;
      final bytes = preset.targetSizeBytes!;
      if (bytes >= 1024 * 1024) {
        _isMB = true;
        _targetValue = (bytes / (1024 * 1024)).clamp(0.1, 100.0);
      } else {
        _isMB = false;
        _targetValue = (bytes / 1024).clamp(10.0, 10240.0);
      }
    } else {
      _modeIndex = 0; // Default to Target File Size mode as requested by user
      if (originalBytes > 0) {
        if (originalBytes >= 1024 * 1024) {
          _isMB = true;
          final originalMB = originalBytes / (1024 * 1024);
          _targetValue = (originalMB * 0.5).clamp(0.2, 50.0);
        } else {
          _isMB = false;
          final originalKB = originalBytes / 1024;
          _targetValue = (originalKB * 0.5).clamp(20.0, 2048.0);
        }
      } else {
        _isMB = true;
        _targetValue = 1.0;
      }
    }

    _targetSizeController = TextEditingController(
      text: _targetValue % 1 == 0
          ? _targetValue.toInt().toString()
          : _targetValue.toStringAsFixed(1),
    );
  }

  @override
  void dispose() {
    _targetSizeController.dispose();
    super.dispose();
  }

  int get _computedTargetSizeBytes {
    if (_isMB) {
      return (_targetValue * 1024 * 1024).round();
    } else {
      return (_targetValue * 1024).round();
    }
  }

  void _onTargetValueUpdated(double value) {
    setState(() {
      _targetValue = value;
      _targetSizeController.text = value % 1 == 0
          ? value.toInt().toString()
          : value.toStringAsFixed(1);
    });
    widget.controller.updateTargetSizeBytes(_computedTargetSizeBytes);
  }

  void _onTargetTextSubmitted(String text) {
    final parsed = double.tryParse(text);
    if (parsed != null && parsed > 0) {
      setState(() {
        _targetValue = parsed;
      });
      widget.controller.updateTargetSizeBytes(_computedTargetSizeBytes);
    }
  }

  void _onUnitChanged(bool isMB) {
    if (_isMB == isMB) return;
    setState(() {
      _isMB = isMB;
      if (_isMB) {
        // KB -> MB
        _targetValue = (_targetValue / 1024).clamp(0.1, 100.0);
      } else {
        // MB -> KB
        _targetValue = (_targetValue * 1024).clamp(10.0, 10240.0);
      }
      _targetSizeController.text = _targetValue % 1 == 0
          ? _targetValue.toInt().toString()
          : _targetValue.toStringAsFixed(1);
    });
    widget.controller.updateTargetSizeBytes(_computedTargetSizeBytes);
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
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.82,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurface.withValues(alpha: 0.90)
                    : Colors.white.withValues(alpha: 0.96),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(32)),
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                children: [
                  _buildHeader(context, isDark, controller),

                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. MODE SELECTOR TABS
                          _buildModeSelector(isDark),

                          const SizedBox(height: AppSpacing.lg),

                          // 2. MODE BODY
                          if (_modeIndex == 0)
                            _buildTargetSizeSection(context, controller, isDark)
                          else
                            _buildQualitySection(context, controller, preset, isDark),

                          const SizedBox(height: AppSpacing.xl),

                          // 3. FORMAT SELECTOR
                          _buildSectionTitle('Target Format', isDark),
                          const SizedBox(height: AppSpacing.sm),
                          _buildFormatSection(controller, preset, isDark),

                          const SizedBox(height: AppSpacing.xxl),
                        ],
                      ),
                    ),
                  ),

                  _buildApplyButton(context, isDark, controller, preset),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(
    BuildContext context,
    bool isDark,
    ImageCompressionController controller,
  ) {
    return Column(
      children: [
        const SizedBox(height: AppSpacing.sm),
        Container(
          width: 38,
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
                      'Compression Settings',
                      style: AppTypography.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: isDark ? Colors.white : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      controller.selectedImages.isEmpty
                          ? 'Set target size or quality'
                          : 'Selected: ${controller.selectedImages.length} file${controller.selectedImages.length == 1 ? '' : 's'} (${controller.detectedOriginalSizeFormatted})',
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
                  backgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.05),
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
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildModeSelector(bool isDark) {
    final activeBg = isDark ? Colors.white : AppColors.lightTextPrimary;
    final activeText = isDark ? Colors.black : Colors.white;
    final inactiveText = isDark ? Colors.white70 : Colors.black87;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black12,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _modeIndex = 0);
                widget.controller.updateTargetSizeBytes(_computedTargetSizeBytes);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _modeIndex == 0 ? activeBg : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedTarget02,
                      color: _modeIndex == 0 ? activeText : inactiveText,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Target File Size',
                      style: AppTypography.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: _modeIndex == 0 ? activeText : inactiveText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _modeIndex = 1);
                widget.controller.updateQuality(widget.controller.preset.quality.toDouble());
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _modeIndex == 1 ? activeBg : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedSparkles,
                      color: _modeIndex == 1 ? activeText : inactiveText,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Quality %',
                      style: AppTypography.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: _modeIndex == 1 ? activeText : inactiveText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetSizeSection(
    BuildContext context,
    ImageCompressionController controller,
    bool isDark,
  ) {
    final originalBytes = widget.controller.detectedOriginalBytes;
    final originalMB = originalBytes > 0 ? originalBytes / (1024 * 1024) : 20.0;
    final originalKB = originalBytes > 0 ? originalBytes / 1024 : 20480.0;
    final maxSlider = _isMB
        ? (originalMB * 1.2).clamp(10.0, 200.0)
        : (originalKB * 1.2).clamp(500.0, 50000.0);
    final minSlider = _isMB ? 0.1 : 10.0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Target Size',
                style: AppTypography.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
                ),
              ),
              const Spacer(),
              // Unit Switcher (MB / KB)
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    _buildUnitChip('MB', _isMB, isDark),
                    _buildUnitChip('KB', !_isMB, isDark),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // Value Input & Display Box
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white24 : Colors.black26,
                    ),
                  ),
                  child: TextField(
                    controller: _targetSizeController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: AppTypography.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : AppColors.lightTextPrimary,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      suffixText: _isMB ? 'MB' : 'KB',
                      suffixStyle: AppTypography.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                    onSubmitted: _onTargetTextSubmitted,
                    onChanged: (val) {
                      final p = double.tryParse(val);
                      if (p != null && p > 0) {
                        setState(() => _targetValue = p);
                        widget.controller
                            .updateTargetSizeBytes(_computedTargetSizeBytes);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // Slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: isDark ? Colors.white : AppColors.lightTextPrimary,
              inactiveTrackColor: isDark ? Colors.white12 : Colors.black12,
              thumbColor: isDark ? Colors.white : AppColors.lightTextPrimary,
              overlayColor: isDark
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.1),
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
            ),
            child: Slider(
              value: _targetValue.clamp(minSlider, maxSlider),
              min: minSlider,
              max: maxSlider,
              onChanged: _onTargetValueUpdated,
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          // Quick Presets Chips
          _buildQuickTargetChips(isDark),
        ],
      ),
    );
  }

  Widget _buildUnitChip(String label, bool isSelected, bool isDark) {
    return GestureDetector(
      onTap: () => _onUnitChanged(label == 'MB'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.white : AppColors.lightTextPrimary)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected
                ? (isDark ? Colors.black : Colors.white)
                : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickTargetChips(bool isDark) {
    final presets = _isMB
        ? [0.5, 1.0, 2.0, 5.0, 10.0]
        : [100.0, 250.0, 500.0, 750.0, 1000.0];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: presets.map((presetVal) {
        final isSelected = (_targetValue - presetVal).abs() < 0.05;
        final label = presetVal % 1 == 0
            ? '${presetVal.toInt()} ${_isMB ? 'MB' : 'KB'}'
            : '$presetVal ${_isMB ? 'MB' : 'KB'}';

        return GestureDetector(
          onTap: () => _onTargetValueUpdated(presetVal),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark ? Colors.white : AppColors.lightTextPrimary)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? Colors.transparent
                    : (isDark ? Colors.white24 : Colors.black26),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? (isDark ? Colors.black : Colors.white)
                    : (isDark ? Colors.white : Colors.black87),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildQualitySection(
    BuildContext context,
    ImageCompressionController controller,
    CompressionPreset preset,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Quality Percentage',
                style: AppTypography.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${preset.quality}%',
                  style: AppTypography.textTheme.labelMedium?.copyWith(
                    color: isDark ? Colors.black : Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: isDark ? Colors.white : AppColors.lightTextPrimary,
              inactiveTrackColor: isDark ? Colors.white12 : Colors.black12,
              thumbColor: isDark ? Colors.white : AppColors.lightTextPrimary,
              overlayColor: isDark
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.1),
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
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _buildQualityPresetChip(
                controller,
                CompressionPreset.light,
                preset,
                isDark,
              ),
              const SizedBox(width: AppSpacing.xs),
              _buildQualityPresetChip(
                controller,
                CompressionPreset.balanced,
                preset,
                isDark,
              ),
              const SizedBox(width: AppSpacing.xs),
              _buildQualityPresetChip(
                controller,
                CompressionPreset.aggressive,
                preset,
                isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQualityPresetChip(
    ImageCompressionController controller,
    CompressionPreset item,
    CompressionPreset current,
    bool isDark,
  ) {
    final isSelected = current.id == item.id;
    return Expanded(
      child: GestureDetector(
        onTap: () => controller.selectPreset(item),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? Colors.white : AppColors.lightTextPrimary)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? Colors.transparent
                  : (isDark ? Colors.white24 : Colors.black26),
            ),
          ),
          child: Column(
            children: [
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? (isDark ? Colors.black : Colors.white)
                      : (isDark ? Colors.white : Colors.black),
                ),
              ),
              Text(
                '${item.quality}%',
                style: TextStyle(
                  fontSize: 10,
                  color: isSelected
                      ? (isDark ? Colors.black87 : Colors.white70)
                      : (isDark ? Colors.white60 : Colors.black54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormatSection(
    ImageCompressionController controller,
    CompressionPreset preset,
    bool isDark,
  ) {
    return Row(
      children: TargetFormat.values.map((fmt) {
        final isSelected = preset.targetFormat == fmt;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: GestureDetector(
              onTap: () => controller.updateTargetFormat(fmt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? Colors.white : AppColors.lightTextPrimary)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? Colors.transparent
                        : (isDark ? Colors.white24 : Colors.black26),
                  ),
                ),
                child: Text(
                  fmt.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected
                        ? (isDark ? Colors.black : Colors.white)
                        : (isDark ? Colors.white : Colors.black),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildApplyButton(
    BuildContext context,
    bool isDark,
    ImageCompressionController controller,
    CompressionPreset preset,
  ) {
    final labelText = preset.isTargetSizeMode
        ? 'Compress to ${preset.formattedTargetSize}'
        : 'Apply ${preset.quality}% Quality';

    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.md,
        bottom: MediaQuery.of(context).padding.bottom + AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurface.withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white10 : Colors.black12,
          ),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedCheckmarkCircle02,
            color: isDark ? Colors.black : Colors.white,
            size: 20,
          ),
          label: Text(labelText),
          style: ElevatedButton.styleFrom(
            backgroundColor: isDark ? Colors.white : AppColors.lightTextPrimary,
            foregroundColor: isDark ? Colors.black : Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(27),
            ),
            textStyle: AppTypography.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}
