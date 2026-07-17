import 'dart:async';

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

  DateTime? _compressionStartTime;
  int _elapsedMilliseconds = 0;
  double _processingSpeedMBps = 0.0;
  StreamSubscription? _compressionSubscription;

  List<SelectedImage> get selectedImages => _selectedImages;
  List<CompressedImage> get compressedImages => _compressedImages;
  CompressionPreset get preset => _preset;
  bool get isCompressing => _isCompressing;
  double get progress => _progress;
  String? get statusMessage => _statusMessage;
  String? get errorMessage => _errorMessage;
  int get elapsedMilliseconds => _elapsedMilliseconds;
  double get processingSpeedMBps => _processingSpeedMBps;

  int get totalOriginalBytes =>
      _selectedImages.fold(0, (sum, image) => sum + image.originalBytes);
  int get totalCompressedBytes =>
      _compressedImages.fold(0, (sum, image) => sum + image.compressedBytes);

  double get savedPercentage {
    if (totalOriginalBytes == 0 || _compressedImages.isEmpty) return 0;
    final processedOriginalBytes = _compressedImages.fold(
      0,
      (sum, item) => sum + item.originalBytes,
    );
    if (processedOriginalBytes == 0) return 0;
    final saved = processedOriginalBytes - totalCompressedBytes;
    return ((saved / processedOriginalBytes) * 100).clamp(0, 100);
  }

  void selectPreset(CompressionPreset preset) {
    _preset = preset;
    notifyListeners();
  }

  void updateQuality(double quality) {
    _preset = _preset.copyWith(
      id: 'custom',
      label: 'Custom',
      description: 'Fine-tuned custom parameters.',
      quality: quality.round(),
      pngLevel: _mapPngLevel(quality.round()),
    );
    notifyListeners();
  }

  void updateResizeMode(ImageResizeMode mode) {
    _preset = _preset.copyWith(
      id: 'custom',
      label: 'Custom',
      description: 'Fine-tuned custom parameters.',
      resizeMode: mode,
    );
    notifyListeners();
  }

  void updateTargetFormat(TargetFormat format) {
    _preset = _preset.copyWith(
      id: 'custom',
      label: 'Custom',
      description: 'Fine-tuned custom parameters.',
      targetFormat: format,
    );
    notifyListeners();
  }

  void removeSelectedImage(SelectedImage image) {
    _selectedImages = _selectedImages.where((i) => i.path != image.path).toList();
    _compressedImages = _compressedImages.where((i) => i.source.path != image.path).toList();
    _statusMessage = _selectedImages.isEmpty
        ? 'No images selected.'
        : '${_selectedImages.length} image${_selectedImages.length == 1 ? '' : 's'} ready.';
    notifyListeners();
  }

  void clearAll() {
    cancelCompression();
    _selectedImages = const [];
    _compressedImages = const [];
    _progress = 0;
    _statusMessage = null;
    _errorMessage = null;
    _processingSpeedMBps = 0;
    _elapsedMilliseconds = 0;
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
    _statusMessage = 'Launching multi-threaded parallel engine...';
    _compressionStartTime = DateTime.now();
    _elapsedMilliseconds = 0;
    _processingSpeedMBps = 0;
    notifyListeners();

    final stream = compressImagesUseCase(
      images: _selectedImages,
      preset: _preset,
    );

    _compressionSubscription = stream.listen(
      (update) {
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

        final now = DateTime.now();
        if (_compressionStartTime != null) {
          _elapsedMilliseconds = now.difference(_compressionStartTime!).inMilliseconds;
          final elapsedSeconds = _elapsedMilliseconds / 1000.0;
          if (elapsedSeconds > 0.05) {
            final processedOriginalBytes = _compressedImages.fold(
              0,
              (sum, img) => sum + img.originalBytes,
            );
            final processedMB = processedOriginalBytes / (1024 * 1024);
            _processingSpeedMBps = processedMB / elapsedSeconds;
          }
        }

        notifyListeners();
      },
      onError: (error) {
        _setError('Engine stream error: $error');
        _isCompressing = false;
        notifyListeners();
      },
      onDone: () {
        _isCompressing = false;
        final now = DateTime.now();
        if (_compressionStartTime != null) {
          _elapsedMilliseconds = now.difference(_compressionStartTime!).inMilliseconds;
        }
        _statusMessage = _compressedImages.isEmpty
            ? 'No files were compressed.'
            : 'Finished in ${_elapsedMilliseconds}ms (${_processingSpeedMBps.toStringAsFixed(1)} MB/s). ${_compressedImages.length} output file${_compressedImages.length == 1 ? '' : 's'} ready.';
        notifyListeners();
      },
    );
  }

  void cancelCompression() {
    if (_compressionSubscription != null) {
      _compressionSubscription!.cancel();
      _compressionSubscription = null;
    }
    if (_isCompressing) {
      _isCompressing = false;
      _statusMessage = 'Compression cancelled by user.';
      notifyListeners();
    }
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

  @override
  void dispose() {
    _compressionSubscription?.cancel();
    super.dispose();
  }
}
