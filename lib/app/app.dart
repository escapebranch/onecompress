import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/image_compression/application/image_compression_dependencies.dart';
import '../features/image_compression/presentation/controllers/image_compression_controller.dart';
import '../features/image_compression/presentation/pages/image_compression_page.dart';

class OneCompressApp extends StatelessWidget {
  const OneCompressApp({required this.dependencies, super.key});

  final ImageCompressionDependencies dependencies;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OneCompress',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: ImageCompressionPage(
        controller: ImageCompressionController(
          pickImagesUseCase: dependencies.pickImages,
          pickExportDirectoryUseCase: dependencies.pickExportDirectory,
          compressImagesUseCase: dependencies.compressImages,
          saveCompressedImagesUseCase: dependencies.saveCompressedImages,
          shareCompressedImagesUseCase: dependencies.shareCompressedImages,
        ),
      ),
    );
  }
}
