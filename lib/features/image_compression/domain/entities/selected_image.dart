enum SupportedImageFormat { jpeg, png, unsupported }

class SelectedImage {
  const SelectedImage({
    required this.path,
    required this.fileName,
    required this.originalBytes,
    required this.format,
  });

  final String path;
  final String fileName;
  final int originalBytes;
  final SupportedImageFormat format;
}
