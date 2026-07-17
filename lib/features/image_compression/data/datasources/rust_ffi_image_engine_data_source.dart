import 'dart:io';

import 'package:path/path.dart' as path;

import '../../../../core/errors/app_failure.dart';
import '../../domain/entities/compressed_image.dart';
import '../../domain/entities/compression_preset.dart';
import '../../domain/entities/selected_image.dart';
import 'image_engine_data_source.dart';
import 'native_image_engine_bridge.dart';

class RustFfiImageEngineDataSource implements ImageEngineDataSource {
  RustFfiImageEngineDataSource({required this.fallbackDataSource});

  final ImageEngineDataSource fallbackDataSource;
  static const _bridge = NativeImageEngineBridge.instance;

  static bool isSupportedPlatform() => _bridge.isSupportedPlatform;

  @override
  Future<CompressedImage> compressImage({
    required SelectedImage image,
    required CompressionPreset preset,
  }) async {
    if (image.format == SupportedImageFormat.unsupported) {
      throw const AppFailure(
        'Unsupported image format. Current phase supports JPEG and PNG.',
      );
    }

    if (!_bridge.isAvailable) {
      return fallbackDataSource.compressImage(image: image, preset: preset);
    }

    final outputDirectory = await Directory.systemTemp.createTemp(
      'onecompress',
    );
    final extension = image.format == SupportedImageFormat.png
        ? '.png'
        : '.jpg';
    final fileNameWithoutExtension = path.basenameWithoutExtension(
      image.fileName,
    );
    final outputFileName = '${fileNameWithoutExtension}_compressed$extension';
    final outputPath = path.join(outputDirectory.path, outputFileName);

    try {
      final result = await _bridge.compress(
        inputPath: image.path,
        outputPath: outputPath,
        quality: preset.quality,
        pngLevel: preset.pngLevel,
        maxLongEdge: preset.maxLongEdge,
        outputFormat: image.format == SupportedImageFormat.png ? 'png' : 'jpeg',
      );

      return CompressedImage(
        source: image,
        outputPath: result.outputPath,
        outputFileName: outputFileName,
        originalBytes: result.originalBytes,
        compressedBytes: result.compressedBytes,
      );
    } catch (_) {
      return fallbackDataSource.compressImage(image: image, preset: preset);
    }
  }
}
