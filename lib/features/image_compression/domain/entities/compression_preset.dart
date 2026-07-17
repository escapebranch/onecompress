import 'package:freezed_annotation/freezed_annotation.dart';

part 'compression_preset.freezed.dart';

enum TargetFormat { auto, jpeg, png, webp }

extension TargetFormatX on TargetFormat {
  String get label {
    switch (this) {
      case TargetFormat.auto:
        return 'Auto';
      case TargetFormat.jpeg:
        return 'JPEG';
      case TargetFormat.png:
        return 'PNG';
      case TargetFormat.webp:
        return 'WebP';
    }
  }
}

@freezed
sealed class ImageResizeMode with _$ImageResizeMode {
  const factory ImageResizeMode.none() = _None;
  const factory ImageResizeMode.maxLongEdge(int value) = _MaxLongEdge;
  const factory ImageResizeMode.exactSize({
    required int width,
    required int height,
    @Default(true) bool keepAspectRatio,
  }) = _ExactSize;
  const factory ImageResizeMode.scalePercentage(double percentage) = _ScalePercentage;
}

class CompressionPreset {
  const CompressionPreset({
    required this.id,
    required this.label,
    required this.description,
    required this.quality,
    required this.pngLevel,
    this.targetFormat = TargetFormat.auto,
    this.resizeMode = const ImageResizeMode.none(),
  });

  final String id;
  final String label;
  final String description;
  final int quality;
  final int pngLevel;
  final TargetFormat targetFormat;
  final ImageResizeMode resizeMode;

  static const light = CompressionPreset(
    id: 'light',
    label: 'Light',
    description: 'Keeps more detail with modest size savings.',
    quality: 88,
    pngLevel: 4,
    targetFormat: TargetFormat.auto,
    resizeMode: ImageResizeMode.none(),
  );

  static const balanced = CompressionPreset(
    id: 'balanced',
    label: 'Balanced',
    description: 'Best default for everyday sharing and storage.',
    quality: 76,
    pngLevel: 6,
    targetFormat: TargetFormat.auto,
    resizeMode: ImageResizeMode.maxLongEdge(2560),
  );

  static const aggressive = CompressionPreset(
    id: 'aggressive',
    label: 'Aggressive',
    description: 'Smallest files for bulk cleanup and uploads.',
    quality: 62,
    pngLevel: 8,
    targetFormat: TargetFormat.auto,
    resizeMode: ImageResizeMode.maxLongEdge(1920),
  );

  static const defaults = [light, balanced, aggressive];

  CompressionPreset copyWith({
    String? id,
    String? label,
    String? description,
    int? quality,
    int? pngLevel,
    TargetFormat? targetFormat,
    ImageResizeMode? resizeMode,
  }) {
    return CompressionPreset(
      id: id ?? this.id,
      label: label ?? this.label,
      description: description ?? this.description,
      quality: quality ?? this.quality,
      pngLevel: pngLevel ?? this.pngLevel,
      targetFormat: targetFormat ?? this.targetFormat,
      resizeMode: resizeMode ?? this.resizeMode,
    );
  }
}
