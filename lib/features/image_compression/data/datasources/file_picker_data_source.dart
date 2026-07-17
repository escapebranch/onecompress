import 'dart:io';

import 'package:file_picker/file_picker.dart';

import '../../../../core/errors/app_failure.dart';
import '../../domain/entities/selected_image.dart';

class FilePickerDataSource {
  Future<List<SelectedImage>> pickImages() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.image,
      withData: false,
    );

    if (result == null) {
      return const [];
    }

    final images = <SelectedImage>[];

    for (final file in result.files) {
      final path = file.path;
      if (path == null) {
        continue;
      }

      final imageFile = File(path);
      if (!await imageFile.exists()) {
        continue;
      }

      final bytes = await imageFile.length();
      final format = _resolveFormat(path);
      images.add(
        SelectedImage(
          path: path,
          fileName: file.name,
          originalBytes: bytes,
          format: format,
        ),
      );
    }

    return images;
  }

  Future<String?> pickExportDirectory() {
    return FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose where to save compressed images',
    );
  }

  SupportedImageFormat _resolveFormat(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return SupportedImageFormat.jpeg;
    }
    if (lower.endsWith('.png')) {
      return SupportedImageFormat.png;
    }
    return SupportedImageFormat.unsupported;
  }
}

class FilePickerFailure extends AppFailure {
  const FilePickerFailure(super.message, {super.details});
}
