import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/extensions/iterable_extensions.dart';
import '../../domain/entities/compressed_image.dart';
import '../../domain/entities/compression_preset.dart';
import '../../domain/entities/selected_image.dart';
import '../../domain/usecases/compress_images_use_case.dart';
import '../../domain/usecases/pick_export_directory_use_case.dart';
import '../../domain/usecases/pick_images_use_case.dart';
import '../../domain/usecases/save_compressed_images_use_case.dart';
import '../../domain/usecases/share_compressed_images_use_case.dart';

class ImageCompressionController extends ChangeNotifier {
  ImageCompressionController({
    required this.pickImagesUseCase,
    required this.pickExportDirectoryUseCase,
    required this.compressImagesUseCase,
    required this.saveCompressedImagesUseCase,
    required this.shareCompressedImagesUseCase,
  });

  final PickImagesUseCase pickImagesUseCase;
  final PickExportDirectoryUseCase pickExportDirectoryUseCase;
  final CompressImagesUseCase compressImagesUseCase;
  final SaveCompressedImagesUseCase saveCompressedImagesUseCase;
  final ShareCompressedImagesUseCase shareCompressedImagesUseCase;

  List<SelectedImage> _selectedImages = const [];
  List<CompressedImage> _compressedImages = const [];
  CompressionPreset _preset = CompressionPreset.balanced;
  bool _isCompressing = false;
  double _progress = 0;
  String? _statusMessage;
  String? _errorMessage;

  List<SelectedImage> get selectedImages => _selectedImages;
  List<CompressedImage> get compressedImages => _compressedImages;
  CompressionPreset get preset => _preset;
  bool get isCompressing => _isCompressing;
  double get progress => _progress;
  String? get statusMessage => _statusMessage;
  String? get errorMessage => _errorMessage;
  int get totalOriginalBytes =>
      _selectedImages.fold(0, (sum, image) => sum + image.originalBytes);
  int get totalCompressedBytes =>
      _compressedImages.fold(0, (sum, image) => sum + image.compressedBytes);

  void selectPreset(CompressionPreset preset) {
    _preset = preset;
    notifyListeners();
  }

  void updateQuality(double quality) {
    _preset = _preset.copyWith(
      id: 'custom',
      label: 'Custom',
      description: 'Fine-tuned for this batch.',
      quality: quality.round(),
      pngLevel: _mapPngLevel(quality.round()),
    );
    notifyListeners();
  }

  Future<void> pickImages() async {
    _setError(null);

    try {
      final images = await pickImagesUseCase();
      _selectedImages = images;
      _compressedImages = const [];
      _progress = 0;
      _statusMessage = images.isEmpty
          ? 'No images selected yet.'
          : '${images.length} image${images.length == 1 ? '' : 's'} ready to compress.';
      notifyListeners();
    } on AppFailure catch (failure) {
      _setError(failure.message);
    } catch (error) {
      _setError('Unable to pick images: $error');
    }
  }

  Future<void> compress() async {
    if (_selectedImages.isEmpty || _isCompressing) {
      return;
    }

    _isCompressing = true;
    _compressedImages = const [];
    _progress = 0;
    _setError(null, notify: false);
    _statusMessage = 'Preparing compression queue...';
    notifyListeners();

    await for (final update in compressImagesUseCase(
      images: _selectedImages,
      preset: _preset,
    )) {
      _progress = update.progress;
      _statusMessage = update.failure == null
          ? 'Compressed ${update.currentImageName}'
          : 'Skipped ${update.currentImageName}: ${update.failure!.message}';

      if (update.result != null) {
        _compressedImages = [..._compressedImages, update.result!];
      }

      if (update.failure != null && _errorMessage == null) {
        _errorMessage = update.failure!.message;
      }

      notifyListeners();
    }

    _isCompressing = false;
    _statusMessage = _compressedImages.isEmpty
        ? 'No files were compressed.'
        : 'Compression finished. ${_compressedImages.length} output file${_compressedImages.length == 1 ? '' : 's'} ready.';
    notifyListeners();
  }

  Future<void> saveCompressedImages() async {
    if (_compressedImages.isEmpty) {
      return;
    }

    final directory = await pickExportDirectoryUseCase();
    if (directory == null) {
      return;
    }

    try {
      await saveCompressedImagesUseCase(
        images: _compressedImages,
        destinationDirectory: directory,
      );
      _statusMessage = 'Saved ${_compressedImages.length} compressed image(s).';
      notifyListeners();
    } on AppFailure catch (failure) {
      _setError(failure.message);
    } catch (error) {
      _setError('Unable to save files: $error');
    }
  }

  Future<void> shareCompressedImages() async {
    if (_compressedImages.isEmpty) {
      return;
    }

    try {
      await shareCompressedImagesUseCase(_compressedImages);
      _statusMessage = 'Share sheet opened.';
      notifyListeners();
    } on AppFailure catch (failure) {
      _setError(failure.message);
    } catch (error) {
      _setError('Unable to share files: $error');
    }
  }

  CompressedImage? resultFor(String path) {
    return _compressedImages.firstWhereOrNull(
      (result) => result.source.path == path,
    );
  }

  int _mapPngLevel(int quality) {
    if (quality >= 85) {
      return 4;
    }
    if (quality >= 70) {
      return 6;
    }
    return 8;
  }

  void _setError(String? value, {bool notify = true}) {
    _errorMessage = value;
    if (notify) {
      notifyListeners();
    }
  }
}
