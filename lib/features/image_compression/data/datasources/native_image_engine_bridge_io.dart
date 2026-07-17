import 'dart:io';

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:path/path.dart' as path;

import '../../../../src/rust/api/image_engine.dart' as frb;
import '../../../../src/rust/frb_generated.dart';

class NativeImageEngineBridge {
  const NativeImageEngineBridge._();

  static const instance = NativeImageEngineBridge._();
  static bool _initialized = false;

  bool get isSupportedPlatform =>
      Platform.isAndroid ||
      Platform.isIOS ||
      Platform.isLinux ||
      Platform.isMacOS ||
      Platform.isWindows;

  bool get isAvailable => isSupportedPlatform;

  Future<void> ensureInitialized() async {
    if (_initialized) return;

    if (Platform.isIOS || Platform.isMacOS || Platform.isAndroid) {
      await RustLib.init();
    } else {
      final libraryPath = _findLibraryPath();
      if (libraryPath != null) {
        await RustLib.init(
          externalLibrary: ExternalLibrary.open(libraryPath),
        );
      } else {
        await RustLib.init();
      }
    }
    _initialized = true;
  }

  Future<NativeCompressionResponse> compress({
    required String id,
    required String inputPath,
    required String outputPath,
    required int quality,
    required int pngLevel,
    required frb.ResizeMode resizeMode,
    required frb.OutputFormat outputFormat,
  }) async {
    await ensureInitialized();

    final request = frb.CompressionRequest(
      id: id,
      inputPath: inputPath,
      outputPath: outputPath,
      quality: quality,
      pngLevel: pngLevel,
      resizeMode: resizeMode,
      outputFormat: outputFormat,
    );

    final response = await frb.compressImage(request: request);

    return NativeCompressionResponse(
      id: response.id,
      outputPath: response.outputPath,
      originalBytes: response.originalBytes,
      compressedBytes: response.compressedBytes,
      width: response.width,
      height: response.height,
      format: response.format,
    );
  }

  Stream<frb.CompressionTaskProgress> compressStream({
    required List<frb.CompressionRequest> requests,
  }) async* {
    await ensureInitialized();
    yield* frb.compressImagesStream(requests: requests);
  }
}

class NativeCompressionResponse {
  const NativeCompressionResponse({
    required this.id,
    required this.outputPath,
    required this.originalBytes,
    required this.compressedBytes,
    required this.width,
    required this.height,
    required this.format,
  });

  final String id;
  final String outputPath;
  final int originalBytes;
  final int compressedBytes;
  final int width;
  final int height;
  final String format;
}

String? _findLibraryPath() {
  final fileName = _libraryFileName();
  if (fileName == null) {
    return null;
  }

  final environmentOverride =
      Platform.environment['ONECOMPRESS_IMAGE_ENGINE_LIB'];
  if (environmentOverride != null && File(environmentOverride).existsSync()) {
    return environmentOverride;
  }

  final executableDirectory = File(Platform.resolvedExecutable).parent.path;
  final candidates = <String>{
    path.join(Directory.current.path, fileName),
    path.join(executableDirectory, fileName),
    path.join(executableDirectory, 'lib', fileName),
    path.join(
      Directory.current.path,
      'rust',
      'image_engine',
      'target',
      'debug',
      fileName,
    ),
    path.join(
      Directory.current.path,
      'rust',
      'image_engine',
      'target',
      'release',
      fileName,
    ),
  };

  for (final candidate in candidates) {
    if (File(candidate).existsSync()) {
      return candidate;
    }
  }

  return null;
}

String? _libraryFileName() {
  if (Platform.isAndroid) {
    return 'libimage_engine.so';
  }
  if (Platform.isLinux) {
    return 'libimage_engine.so';
  }
  if (Platform.isMacOS) {
    return null;
  }
  if (Platform.isIOS) {
    return null;
  }
  if (Platform.isWindows) {
    return 'image_engine.dll';
  }
  return null;
}
