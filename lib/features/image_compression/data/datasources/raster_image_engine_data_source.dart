import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;

import '../../../../core/errors/app_failure.dart';
import '../../domain/entities/compressed_image.dart';
import '../../domain/entities/compression_preset.dart';
import '../../domain/entities/compression_task_update.dart';
import '../../domain/entities/selected_image.dart';
import 'image_engine_data_source.dart';

class RasterImageEngineDataSource implements ImageEngineDataSource {
  @override
  Future<CompressedImage> compressImage({
    required SelectedImage image,
    required CompressionPreset preset,
  }) async {
    if (image.format == SupportedImageFormat.unsupported) {
      throw const AppFailure(
        'Unsupported image format. Supports JPEG, PNG, and WebP.',
      );
    }

    final sourceFile = File(image.path);
    final inputBytes = await sourceFile.readAsBytes();
    final decoded = img.decodeImage(inputBytes);

    if (decoded == null) {
      throw AppFailure('Unable to decode ${image.fileName}.');
    }

    final transformed = _resizeIfNeeded(decoded, preset.resizeMode);
    final targetExt = _resolveExtension(image.format, preset.targetFormat);
    final encoded = _encodeImage(transformed, targetExt, preset);

    final outputDirectory = await Directory.systemTemp.createTemp(
      'onecompress',
    );
    final fileNameWithoutExtension = path.basenameWithoutExtension(
      image.fileName,
    );
    final outputFileName = '${fileNameWithoutExtension}_compressed$targetExt';
    final outputPath = path.join(outputDirectory.path, outputFileName);
    final outputFile = File(outputPath);

    await outputFile.writeAsBytes(encoded, flush: true);

    return CompressedImage(
      source: image,
      outputPath: outputPath,
      outputFileName: outputFileName,
      originalBytes: image.originalBytes,
      compressedBytes: encoded.length,
    );
  }

  @override
  Stream<CompressionTaskUpdate> compressBatchStream({
    required List<SelectedImage> images,
    required CompressionPreset preset,
  }) async* {
    var completed = 0;
    final total = images.length;

    for (final image in images) {
      try {
        final result = await compressImage(image: image, preset: preset);
        completed++;
        yield CompressionTaskUpdate(
          total: total,
          completed: completed,
          currentImageName: image.fileName,
          result: result,
          source: image,
        );
      } on AppFailure catch (failure) {
        completed++;
        yield CompressionTaskUpdate(
          total: total,
          completed: completed,
          currentImageName: image.fileName,
          failure: failure,
          source: image,
        );
      } catch (error) {
        completed++;
        yield CompressionTaskUpdate(
          total: total,
          completed: completed,
          currentImageName: image.fileName,
          source: image,
          failure: AppFailure(
            'Compression failed for ${image.fileName}.',
            details: error.toString(),
          ),
        );
      }
    }
  }

  List<int> _encodeImage(
    img.Image image,
    String ext,
    CompressionPreset preset,
  ) {
    if (ext == '.png') {
      return img.encodePng(image, level: preset.pngLevel);
    }
    return img.encodeJpg(image, quality: preset.quality);
  }

  String _resolveExtension(
    SupportedImageFormat inputFormat,
    TargetFormat targetFormat,
  ) {
    switch (targetFormat) {
      case TargetFormat.jpeg:
        return '.jpg';
      case TargetFormat.png:
        return '.png';
      case TargetFormat.webp:
        return '.webp';
      case TargetFormat.auto:
        switch (inputFormat) {
          case SupportedImageFormat.png:
            return '.png';
          case SupportedImageFormat.webp:
            return '.webp';
          default:
            return '.jpg';
        }
    }
  }

  img.Image _resizeIfNeeded(img.Image image, ImageResizeMode mode) {
    return mode.when(
      none: () => image,
      maxLongEdge: (maxLongEdge) {
        final longEdge = math.max(image.width, image.height);
        if (longEdge <= maxLongEdge) {
          return image;
        }

        final scale = maxLongEdge / longEdge;
        final width = (image.width * scale).round();
        final height = (image.height * scale).round();
        return img.copyResize(image, width: width, height: height);
      },
      exactSize: (width, height, keepAspectRatio) {
        return img.copyResize(
          image,
          width: width,
          height: height,
          maintainAspect: keepAspectRatio,
        );
      },
      scalePercentage: (percentage) {
        final scale = percentage / 100.0;
        final width = math.max(1, (image.width * scale).round());
        final height = math.max(1, (image.height * scale).round());
        return img.copyResize(image, width: width, height: height);
      },
    );
  }
}
