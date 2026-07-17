import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;

import '../../../../core/errors/app_failure.dart';
import '../../domain/entities/compressed_image.dart';
import '../../domain/entities/compression_preset.dart';
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
        'Unsupported image format. Current phase supports JPEG and PNG.',
      );
    }

    final sourceFile = File(image.path);
    final inputBytes = await sourceFile.readAsBytes();
    final decoded = img.decodeImage(inputBytes);

    if (decoded == null) {
      throw AppFailure('Unable to decode ${image.fileName}.');
    }

    final transformed = _resizeIfNeeded(decoded, preset.maxLongEdge);
    final encoded = switch (image.format) {
      SupportedImageFormat.jpeg => img.encodeJpg(
        transformed,
        quality: preset.quality,
      ),
      SupportedImageFormat.png => img.encodePng(
        transformed,
        level: preset.pngLevel,
      ),
      SupportedImageFormat.unsupported => throw const AppFailure(
        'Unsupported image format. Current phase supports JPEG and PNG.',
      ),
    };

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

  img.Image _resizeIfNeeded(img.Image image, int? maxLongEdge) {
    if (maxLongEdge == null) {
      return image;
    }

    final longEdge = math.max(image.width, image.height);
    if (longEdge <= maxLongEdge) {
      return image;
    }

    final scale = maxLongEdge / longEdge;
    final width = (image.width * scale).round();
    final height = (image.height * scale).round();
    return img.copyResize(image, width: width, height: height);
  }
}
