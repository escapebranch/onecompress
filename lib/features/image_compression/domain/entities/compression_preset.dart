class CompressionPreset {
  const CompressionPreset({
    required this.id,
    required this.label,
    required this.description,
    required this.quality,
    required this.pngLevel,
    this.maxLongEdge,
  });

  final String id;
  final String label;
  final String description;
  final int quality;
  final int pngLevel;
  final int? maxLongEdge;

  static const light = CompressionPreset(
    id: 'light',
    label: 'Light',
    description: 'Keeps more detail with modest size savings.',
    quality: 88,
    pngLevel: 4,
    maxLongEdge: null,
  );

  static const balanced = CompressionPreset(
    id: 'balanced',
    label: 'Balanced',
    description: 'Best default for everyday sharing and storage.',
    quality: 76,
    pngLevel: 6,
    maxLongEdge: 2560,
  );

  static const aggressive = CompressionPreset(
    id: 'aggressive',
    label: 'Aggressive',
    description: 'Smallest files for bulk cleanup and uploads.',
    quality: 62,
    pngLevel: 8,
    maxLongEdge: 1920,
  );

  static const defaults = [light, balanced, aggressive];

  CompressionPreset copyWith({
    String? id,
    String? label,
    String? description,
    int? quality,
    int? pngLevel,
    int? maxLongEdge,
  }) {
    return CompressionPreset(
      id: id ?? this.id,
      label: label ?? this.label,
      description: description ?? this.description,
      quality: quality ?? this.quality,
      pngLevel: pngLevel ?? this.pngLevel,
      maxLongEdge: maxLongEdge ?? this.maxLongEdge,
    );
  }
}
