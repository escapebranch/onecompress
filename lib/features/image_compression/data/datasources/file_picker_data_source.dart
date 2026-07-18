import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../../../core/errors/app_failure.dart';
import '../../domain/entities/selected_image.dart';

class FilePickerDataSource {
  final ImagePicker _imagePicker = ImagePicker();

  Future<List<SelectedImage>> pickImages() async {
    // 1. Try native System Photo Picker (pickMultiImage) first
    try {
      final xFiles = await _imagePicker.pickMultiImage();
      if (xFiles.isNotEmpty) {
        final images = <SelectedImage>[];
        for (final xFile in xFiles) {
          final filePath = xFile.path;
          final imageFile = File(filePath);
          if (!await imageFile.exists()) continue;

          final bytes = await imageFile.length();
          final format = _resolveFormat(filePath);
          images.add(
            SelectedImage(
              path: filePath,
              fileName: xFile.name.isNotEmpty ? xFile.name : path.basename(filePath),
              originalBytes: bytes,
              format: format,
            ),
          );
        }
        if (images.isNotEmpty) {
          return images;
        }
      }
    } catch (_) {
      // Fallback to FilePicker if ImagePicker fails
    }

    // 2. Fallback to FilePicker with allowMultiple: true
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
      final pathStr = file.path;
      if (pathStr == null) {
        continue;
      }

      final imageFile = File(pathStr);
      if (!await imageFile.exists()) {
        continue;
      }

      final bytes = await imageFile.length();
      final format = _resolveFormat(pathStr);
      images.add(
        SelectedImage(
          path: pathStr,
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
    if (lower.endsWith('.webp')) {
      return SupportedImageFormat.webp;
    }
    return SupportedImageFormat.unsupported;
  }
}

class FilePickerFailure extends AppFailure {
  const FilePickerFailure(super.message, {super.details});
}
