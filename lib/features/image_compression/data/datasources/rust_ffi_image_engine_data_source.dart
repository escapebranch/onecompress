import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as path;

import '../../../../core/errors/app_failure.dart';
import '../../../../src/rust/api/image_engine.dart' as frb;
import '../../domain/entities/compressed_image.dart';
import '../../domain/entities/compression_preset.dart';
import '../../domain/entities/compression_task_update.dart';
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
        'Unsupported image format. Supports JPEG, PNG, and WebP.',
      );
    }

    if (!_bridge.isAvailable) {
      return fallbackDataSource.compressImage(image: image, preset: preset);
    }

    final outputDirectory = await Directory.systemTemp.createTemp(
      'onecompress',
    );

    final ext = _resolveExtension(image.format, preset.targetFormat);
    final fileNameWithoutExt = path.basenameWithoutExtension(image.fileName);
    final outputFileName = '${fileNameWithoutExt}_compressed$ext';
    final outputPath = path.join(outputDirectory.path, outputFileName);

    try {
      final result = await _bridge.compress(
        id: image.path,
        inputPath: image.path,
        outputPath: outputPath,
        quality: preset.quality,
        pngLevel: preset.pngLevel,
        resizeMode: _mapResizeMode(preset.resizeMode),
        outputFormat: _mapOutputFormat(image.format, preset.targetFormat),
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

  @override
  Stream<CompressionTaskUpdate> compressBatchStream({
    required List<SelectedImage> images,
    required CompressionPreset preset,
  }) async* {
    if (!_bridge.isAvailable) {
      yield* fallbackDataSource.compressBatchStream(images: images, preset: preset);
      return;
    }

    final outputDirectory = await Directory.systemTemp.createTemp(
      'onecompress_batch',
    );

    final imageMap = <String, SelectedImage>{};
    final requests = <frb.CompressionRequest>[];

    for (var i = 0; i < images.length; i++) {
      final img = images[i];
      final id = '${img.path}_$i';
      imageMap[id] = img;

      final ext = _resolveExtension(img.format, preset.targetFormat);
      final fileNameWithoutExt = path.basenameWithoutExtension(img.fileName);
      final outputFileName = '${fileNameWithoutExt}_compressed$ext';
      final outputPath = path.join(outputDirectory.path, outputFileName);

      requests.add(
        frb.CompressionRequest(
          id: id,
          inputPath: img.path,
          outputPath: outputPath,
          quality: preset.quality,
          pngLevel: preset.pngLevel,
          resizeMode: _mapResizeMode(preset.resizeMode),
          outputFormat: _mapOutputFormat(img.format, preset.targetFormat),
        ),
      );
    }

    var completedCount = 0;
    final totalCount = images.length;

    try {
      await for (final progress in _bridge.compressStream(requests: requests)) {
        completedCount++;
        final source = imageMap[progress.id];
        if (source == null) continue;

        if (progress.success && progress.response != null) {
          final resp = progress.response!;
          final result = CompressedImage(
            source: source,
            outputPath: resp.outputPath,
            outputFileName: path.basename(resp.outputPath),
            originalBytes: resp.originalBytes,
            compressedBytes: resp.compressedBytes,
          );
          yield CompressionTaskUpdate(
            total: totalCount,
            completed: completedCount,
            currentImageName: source.fileName,
            result: result,
            source: source,
          );
        } else {
          // Fallback single image if Rayon fails on it
          try {
            final fallbackResult = await fallbackDataSource.compressImage(
              image: source,
              preset: preset,
            );
            yield CompressionTaskUpdate(
              total: totalCount,
              completed: completedCount,
              currentImageName: source.fileName,
              result: fallbackResult,
              source: source,
            );
          } on AppFailure catch (failure) {
            yield CompressionTaskUpdate(
              total: totalCount,
              completed: completedCount,
              currentImageName: source.fileName,
              failure: failure,
              source: source,
            );
          } catch (err) {
            yield CompressionTaskUpdate(
              total: totalCount,
              completed: completedCount,
              currentImageName: source.fileName,
              source: source,
              failure: AppFailure(
                'Compression failed for ${source.fileName}',
                details: err.toString(),
              ),
            );
          }
        }
      }
    } catch (e) {
      // Fallback for remaining items if stream breaks
      yield* fallbackDataSource.compressBatchStream(images: images, preset: preset);
    }
  }

  frb.ResizeMode _mapResizeMode(ImageResizeMode mode) {
    return mode.when(
      none: () => const frb.ResizeMode.none(),
      maxLongEdge: (value) => frb.ResizeMode.maxLongEdge(value: value),
      exactSize: (w, h, ratio) => frb.ResizeMode.exactSize(
        width: w,
        height: h,
        keepAspectRatio: ratio,
      ),
      scalePercentage: (percentage) => frb.ResizeMode.scalePercentage(
        percentage: percentage,
      ),
    );
  }

  frb.OutputFormat _mapOutputFormat(
    SupportedImageFormat inputFormat,
    TargetFormat targetFormat,
  ) {
    switch (targetFormat) {
      case TargetFormat.jpeg:
        return frb.OutputFormat.jpeg;
      case TargetFormat.png:
        return frb.OutputFormat.png;
      case TargetFormat.webp:
        return frb.OutputFormat.webp;
      case TargetFormat.auto:
        switch (inputFormat) {
          case SupportedImageFormat.png:
            return frb.OutputFormat.png;
          case SupportedImageFormat.webp:
            return frb.OutputFormat.webp;
          default:
            return frb.OutputFormat.jpeg;
        }
    }
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
}
