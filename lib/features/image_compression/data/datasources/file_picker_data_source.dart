import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

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

  Future<String> getDefaultExportDirectory() async {
    Directory? baseDir;
    try {
      if (Platform.isAndroid) {
        final pictures = Directory('/storage/emulated/0/Pictures');
        if (await pictures.exists()) {
          baseDir = pictures;
        } else {
          final downloads = Directory('/storage/emulated/0/Download');
          if (await downloads.exists()) {
            baseDir = downloads;
          } else {
            baseDir = await getExternalStorageDirectory();
          }
        }
      } else if (Platform.isIOS) {
        baseDir = await getApplicationDocumentsDirectory();
      } else {
        baseDir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      }
    } catch (_) {
      baseDir = await getApplicationDocumentsDirectory();
    }

    final folder = Directory(path.join(baseDir?.path ?? '.', 'OneCompress'));
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    return folder.path;
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
