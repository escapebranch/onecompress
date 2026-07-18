import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/extensions/iterable_extensions.dart';
import '../../../../core/utils/app_log.dart';
import '../../domain/entities/compressed_image.dart';
import '../../domain/entities/compression_preset.dart';
import '../../domain/entities/selected_image.dart';
import '../../domain/usecases/compress_images_use_case.dart';
import '../../domain/usecases/get_default_export_directory_use_case.dart';
import '../../domain/usecases/pick_export_directory_use_case.dart';
import '../../domain/usecases/pick_images_use_case.dart';
import '../../domain/usecases/save_compressed_images_use_case.dart';
import '../../domain/usecases/share_compressed_images_use_case.dart';

class ImageCompressionController extends ChangeNotifier {
  ImageCompressionController({
    required this.pickImagesUseCase,
    required this.pickExportDirectoryUseCase,
    required this.getDefaultExportDirectoryUseCase,
    required this.compressImagesUseCase,
    required this.saveCompressedImagesUseCase,
    required this.shareCompressedImagesUseCase,
  });

  final PickImagesUseCase pickImagesUseCase;
  final PickExportDirectoryUseCase pickExportDirectoryUseCase;
  final GetDefaultExportDirectoryUseCase getDefaultExportDirectoryUseCase;
  final CompressImagesUseCase compressImagesUseCase;
  final SaveCompressedImagesUseCase saveCompressedImagesUseCase;
  final ShareCompressedImagesUseCase shareCompressedImagesUseCase;

  // ─── State ─────────────────────────────────────────────────────────────────

  List<SelectedImage> _selectedImages = const [];

  // Use a growable list for O(1) append instead of O(n) spread on every update.
  final List<CompressedImage> _compressedImages = [];

  CompressionPreset _preset = CompressionPreset.balanced;
  bool _isCompressing = false;
  String? _statusMessage;
  String? _errorMessage;

  // ─── Progress Telemetry ────────────────────────────────────────────────────

  int _completedCount = 0;
  int _totalCount = 0;
  DateTime? _compressionStartTime;
  int _elapsedMilliseconds = 0;
  double _processingSpeedMBps = 0.0;
  // Running sum of processed original bytes for speed calculation (avoids re-folding the list).
  int _processedOriginalBytes = 0;
  StreamSubscription<dynamic>? _compressionSubscription;

  // ─── Getters ────────────────────────────────────────────────────────────────

  List<SelectedImage> get selectedImages => _selectedImages;
  List<CompressedImage> get compressedImages => List.unmodifiable(_compressedImages);
  CompressionPreset get preset => _preset;
  bool get isCompressing => _isCompressing;
  int get completedCount => _completedCount;
  int get totalCount => _totalCount;
  String? get statusMessage => _statusMessage;
  String? get errorMessage => _errorMessage;
  int get elapsedMilliseconds => _elapsedMilliseconds;
  double get processingSpeedMBps => _processingSpeedMBps;

  /// Progress as 0.0–1.0. Returns 0 when no compression is running.
  double get progress => _totalCount == 0 ? 0 : (_completedCount / _totalCount).clamp(0.0, 1.0);

  /// Estimated seconds remaining based on current throughput.
  /// Returns null when there is no meaningful data.
  double? get estimatedSecondsRemaining {
    if (!_isCompressing || _completedCount == 0 || _totalCount == 0) return null;
    if (_elapsedMilliseconds <= 0) return null;
    final elapsedSec = _elapsedMilliseconds / 1000.0;
    final rate = _completedCount / elapsedSec; // images per second
    final remaining = _totalCount - _completedCount;
    if (rate <= 0) return null;
    return remaining / rate;
  }

  int get totalOriginalBytes =>
      _selectedImages.fold(0, (sum, image) => sum + image.originalBytes);

  int get totalCompressedBytes =>
      _compressedImages.fold(0, (sum, image) => sum + image.compressedBytes);

  double get savedPercentage {
    if (_processedOriginalBytes == 0 || _compressedImages.isEmpty) return 0;
    final saved = _processedOriginalBytes - totalCompressedBytes;
    return ((saved / _processedOriginalBytes) * 100).clamp(0.0, 100.0);
  }

  // ─── Preset / Settings ─────────────────────────────────────────────────────

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

  // ─── Image Management ──────────────────────────────────────────────────────

  void removeSelectedImage(SelectedImage image) {
    _selectedImages = _selectedImages.where((i) => i.path != image.path).toList();
    _compressedImages.removeWhere((i) => i.source.path == image.path);
    _statusMessage = _selectedImages.isEmpty
        ? 'No images selected.'
        : '${_selectedImages.length} image${_selectedImages.length == 1 ? '' : 's'} ready.';
    notifyListeners();
  }

  void clearAll() {
    cancelCompression();
    _selectedImages = const [];
    _compressedImages.clear();
    _resetTelemetry();
    _statusMessage = null;
    _errorMessage = null;
    notifyListeners();
  }

  // ─── Pick Images ───────────────────────────────────────────────────────────

  Future<void> pickImages() async {
    AppLog.info('Controller', 'pickImages() called');
    _setError(null);
    try {
      final images = await pickImagesUseCase();
      _selectedImages = images;
      _compressedImages.clear();
      _resetTelemetry();
      _statusMessage = images.isEmpty
          ? 'No images selected yet.'
          : '${images.length} image${images.length == 1 ? '' : 's'} ready to compress.';
      AppLog.info('Controller', 'pickImages() done — selected=${images.length} images');
      notifyListeners();
    } on AppFailure catch (failure) {
      AppLog.error('Controller', 'pickImages() AppFailure: ${failure.message}');
      _setError(failure.message);
    } catch (error) {
      AppLog.error('Controller', 'pickImages() unexpected error', error: error);
      _setError('Unable to pick images: $error');
    }
  }

  Future<void> addMoreImages() async {
    AppLog.info('Controller', 'addMoreImages() called');
    _setError(null);
    try {
      final newImages = await pickImagesUseCase();
      if (newImages.isEmpty) return;
      final existingPaths = _selectedImages.map((i) => i.path).toSet();
      final filteredNew = newImages.where((i) => !existingPaths.contains(i.path)).toList();
      if (filteredNew.isEmpty) return;
      _selectedImages = [..._selectedImages, ...filteredNew];
      _statusMessage = '${_selectedImages.length} image${_selectedImages.length == 1 ? '' : 's'} in batch ready.';
      AppLog.info('Controller', 'addMoreImages() done — total now ${_selectedImages.length}');
      notifyListeners();
    } on AppFailure catch (failure) {
      AppLog.error('Controller', 'addMoreImages() AppFailure: ${failure.message}');
      _setError(failure.message);
    } catch (error) {
      AppLog.error('Controller', 'addMoreImages() unexpected error', error: error);
      _setError('Unable to add more images: $error');
    }
  }

  // ─── Compress ─────────────────────────────────────────────────────────────

  Future<void> compress() async {
    if (_selectedImages.isEmpty || _isCompressing) {
      AppLog.warn('Controller', 'compress() called but images=${_selectedImages.length} isCompressing=$_isCompressing — skipped');
      return;
    }

    AppLog.info(
      'Controller',
      'compress() START images=${_selectedImages.length} '
      'preset=${_preset.id} quality=${_preset.quality} '
      'pngLevel=${_preset.pngLevel} targetFormat=${_preset.targetFormat} '
      'resizeMode=${_preset.resizeMode}',
    );

    _isCompressing = true;
    _compressedImages.clear();
    _resetTelemetry();
    _totalCount = _selectedImages.length;
    _setError(null, notify: false);
    _statusMessage = 'Firing up ${_selectedImages.length} image${_selectedImages.length == 1 ? '' : 's'} on Rayon engine...';
    _compressionStartTime = DateTime.now();
    notifyListeners();

    final stream = compressImagesUseCase(images: _selectedImages, preset: _preset);
    AppLog.info('Controller', 'compress() stream obtained — subscribing');

    DateTime? lastNotify;
    int notifyCount = 0;
    int suppressedCount = 0;

    _compressionSubscription = stream.listen(
      (update) {
        _completedCount = update.completed;

        if (update.result != null) {
          _compressedImages.add(update.result!);
          _processedOriginalBytes += update.result!.originalBytes;
        }

        if (update.failure != null && _errorMessage == null) {
          _errorMessage = update.failure!.message;
          AppLog.warn('Controller', 'stream event failure for ${update.currentImageName}: ${update.failure!.message}');
        }

        final now = DateTime.now();
        if (_compressionStartTime != null) {
          _elapsedMilliseconds = now.difference(_compressionStartTime!).inMilliseconds;
          final elapsedSeconds = _elapsedMilliseconds / 1000.0;
          if (elapsedSeconds > 0.05 && _processedOriginalBytes > 0) {
            _processingSpeedMBps = (_processedOriginalBytes / (1024 * 1024)) / elapsedSeconds;
          }
        }

        _statusMessage = update.failure == null
            ? '${update.currentImageName}'
            : 'Skipped ${update.currentImageName}: ${update.failure!.message}';

        // Throttle: only push to UI at ~60fps (16ms gate)
        if (lastNotify == null || now.difference(lastNotify!).inMilliseconds >= 16) {
          lastNotify = now;
          notifyCount++;
          notifyListeners();
          AppLog.debug(
            'Controller',
            'stream event NOTIFY #$notifyCount '
            'completed=$_completedCount/$_totalCount '
            'progress=${(progress * 100).toStringAsFixed(1)}% '
            'speed=${_processingSpeedMBps.toStringAsFixed(1)}MB/s '
            'elapsed=${_elapsedMilliseconds}ms '
            'suppressed_since_last=$suppressedCount',
          );
          suppressedCount = 0;
        } else {
          suppressedCount++;
        }
      },
      onError: (Object error, StackTrace st) {
        AppLog.error('Controller', 'compress() stream onError', error: error, stackTrace: st);
        _setError('Engine error: $error');
        _isCompressing = false;
        notifyListeners();
      },
      onDone: () {
        _isCompressing = false;
        final now = DateTime.now();
        if (_compressionStartTime != null) {
          _elapsedMilliseconds = now.difference(_compressionStartTime!).inMilliseconds;
        }
        final count = _compressedImages.length;
        final ms = _elapsedMilliseconds;
        final mbps = _processingSpeedMBps.toStringAsFixed(1);
        _statusMessage = count == 0
            ? 'No files were compressed.'
            : '✅ $count file${count == 1 ? '' : 's'} done in ${ms}ms · $mbps MB/s';
        notifyListeners();
      },
    );
  }

  // ─── Cancel ────────────────────────────────────────────────────────────────

  void cancelCompression() {
    AppLog.info('Controller', 'cancelCompression() called isCompressing=$_isCompressing');
    _compressionSubscription?.cancel();
    _compressionSubscription = null;
    if (_isCompressing) {
      _isCompressing = false;
      _statusMessage = 'Compression cancelled.';
      notifyListeners();
    }
  }

  // ─── Save / Share ──────────────────────────────────────────────────────────

  Future<String?> saveCompressedImages({String? customDirectory}) async {
    if (_compressedImages.isEmpty) return null;
    final directory = customDirectory ?? await getDefaultExportDirectoryUseCase();
    try {
      await saveCompressedImagesUseCase(images: _compressedImages, destinationDirectory: directory);
      _statusMessage = 'Saved ${_compressedImages.length} compressed image(s) to OneCompress folder.';
      notifyListeners();
      return directory;
    } on AppFailure catch (failure) {
      _setError(failure.message);
      return null;
    } catch (error) {
      _setError('Unable to save files: $error');
      return null;
    }
  }

  Future<void> shareCompressedImages() async {
    if (_compressedImages.isEmpty) return;
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

  // ─── Lookups ────────────────────────────────────────────────────────────────

  CompressedImage? resultFor(String path) {
    return _compressedImages.firstWhereOrNull(
      (result) => result.source.path == path,
    );
  }

  // ─── Private Helpers ───────────────────────────────────────────────────────

  void _resetTelemetry() {
    _completedCount = 0;
    _totalCount = 0;
    _elapsedMilliseconds = 0;
    _processingSpeedMBps = 0;
    _processedOriginalBytes = 0;
    _compressionStartTime = null;
  }

  int _mapPngLevel(int quality) {
    if (quality >= 85) return 4;
    if (quality >= 70) return 6;
    return 8;
  }

  void _setError(String? value, {bool notify = true}) {
    _errorMessage = value;
    if (notify) notifyListeners();
  }

  @override
  void dispose() {
    _compressionSubscription?.cancel();
    super.dispose();
  }
}
