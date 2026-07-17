import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as path;

import '../../../../core/errors/app_failure.dart';
import '../../domain/entities/compressed_image.dart';
import '../../domain/entities/compression_preset.dart';
import '../../domain/entities/compression_task_update.dart';
import '../../domain/entities/selected_image.dart';
import '../../domain/repositories/image_compression_repository.dart';
import '../datasources/file_picker_data_source.dart';
import '../datasources/image_engine_data_source.dart';
import '../datasources/share_data_source.dart';

class ImageCompressionRepositoryImpl implements ImageCompressionRepository {
  const ImageCompressionRepositoryImpl({
    required this.filePickerDataSource,
    required this.imageEngineDataSource,
    required this.shareDataSource,
  });

  final FilePickerDataSource filePickerDataSource;
  final ImageEngineDataSource imageEngineDataSource;
  final ShareDataSource shareDataSource;

  @override
  Future<List<SelectedImage>> pickImages() {
    return filePickerDataSource.pickImages();
  }

  @override
  Future<String?> pickExportDirectory() {
    return filePickerDataSource.pickExportDirectory();
  }

  @override
  Stream<CompressionTaskUpdate> compressImages({
    required List<SelectedImage> images,
    required CompressionPreset preset,
  }) async* {
    var completed = 0;
    final total = images.length;

    for (final image in images) {
      try {
        final result = await imageEngineDataSource.compressImage(
          image: image,
          preset: preset,
        );
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

  @override
  Future<void> saveCompressedImages({
    required List<CompressedImage> images,
    required String destinationDirectory,
  }) async {
    final destination = Directory(destinationDirectory);
    await destination.create(recursive: true);

    for (final image in images) {
      final targetPath = path.join(destination.path, image.outputFileName);
      await File(image.outputPath).copy(targetPath);
    }
  }

  @override
  Future<void> shareCompressedImages(List<CompressedImage> images) {
    return shareDataSource.shareCompressedImages(images);
  }
}
