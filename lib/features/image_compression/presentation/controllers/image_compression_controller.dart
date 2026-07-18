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
    _setError(null);
    try {
      final images = await pickImagesUseCase();
      _selectedImages = images;
      _compressedImages.clear();
      _resetTelemetry();
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

  // ─── Compress ─────────────────────────────────────────────────────────────

  Future<void> compress() async {
    if (_selectedImages.isEmpty || _isCompressing) return;

    _isCompressing = true;
    _compressedImages.clear();
    _resetTelemetry();
    _totalCount = _selectedImages.length;
    _setError(null, notify: false);
    _statusMessage = 'Firing up ${_selectedImages.length} image${_selectedImages.length == 1 ? '' : 's'} on Rayon engine…';
    _compressionStartTime = DateTime.now();
    notifyListeners();

    final stream = compressImagesUseCase(images: _selectedImages, preset: _preset);

    // Throttle gate: only notify listeners at ~60 FPS to avoid flooding the UI thread.
    DateTime? lastNotify;

    _compressionSubscription = stream.listen(
      (update) {
        _completedCount = update.completed;

        if (update.result != null) {
          // O(1) append — no list spread allocation.
          _compressedImages.add(update.result!);
          _processedOriginalBytes += update.result!.originalBytes;
        }

        if (update.failure != null && _errorMessage == null) {
          _errorMessage = update.failure!.message;
        }

        // Update telemetry
        final now = DateTime.now();
        if (_compressionStartTime != null) {
          _elapsedMilliseconds = now.difference(_compressionStartTime!).inMilliseconds;
          final elapsedSeconds = _elapsedMilliseconds / 1000.0;
          if (elapsedSeconds > 0.05 && _processedOriginalBytes > 0) {
            _processingSpeedMBps = (_processedOriginalBytes / (1024 * 1024)) / elapsedSeconds;
          }
        }

        _statusMessage = update.failure == null
            ? '⚡ ${update.currentImageName}'
            : 'Skipped ${update.currentImageName}: ${update.failure!.message}';

        // Throttle: only push to UI at ~60fps (16ms gate)
        if (lastNotify == null || now.difference(lastNotify!).inMilliseconds >= 16) {
          lastNotify = now;
          notifyListeners();
        }
      },
      onError: (error) {
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
    _compressionSubscription?.cancel();
    _compressionSubscription = null;
    if (_isCompressing) {
      _isCompressing = false;
      _statusMessage = 'Compression cancelled.';
      notifyListeners();
    }
  }

  // ─── Save / Share ──────────────────────────────────────────────────────────

  Future<void> saveCompressedImages() async {
    if (_compressedImages.isEmpty) return;
    final directory = await pickExportDirectoryUseCase();
    if (directory == null) return;
    try {
      await saveCompressedImagesUseCase(images: _compressedImages, destinationDirectory: directory);
      _statusMessage = 'Saved ${_compressedImages.length} compressed image(s).';
      notifyListeners();
    } on AppFailure catch (failure) {
      _setError(failure.message);
    } catch (error) {
      _setError('Unable to save files: $error');
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
