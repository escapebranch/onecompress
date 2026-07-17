class NativeImageEngineBridge {
  const NativeImageEngineBridge._();

  static const instance = NativeImageEngineBridge._();

  bool get isSupportedPlatform => false;
  bool get isAvailable => false;

  Future<NativeCompressionResponse> compress({
    required String inputPath,
    required String outputPath,
    required int quality,
    required int pngLevel,
    required int? maxLongEdge,
    required String outputFormat,
  }) {
    throw UnsupportedError(
      'Native image engine is not available on this platform.',
    );
  }
}

class NativeCompressionResponse {
  const NativeCompressionResponse({
    required this.outputPath,
    required this.originalBytes,
    required this.compressedBytes,
  });

  final String outputPath;
  final int originalBytes;
  final int compressedBytes;
}
