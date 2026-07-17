import 'package:share_plus/share_plus.dart';

import '../../domain/entities/compressed_image.dart';

class ShareDataSource {
  Future<void> shareCompressedImages(List<CompressedImage> images) {
    return SharePlus.instance.share(
      ShareParams(
        text: 'Compressed with OneCompress',
        files: images.map((image) => XFile(image.outputPath)).toList(),
      ),
    );
  }
}
