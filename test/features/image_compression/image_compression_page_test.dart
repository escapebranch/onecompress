import 'package:flutter_test/flutter_test.dart';
import 'package:onecompress/app/app.dart';
import 'package:onecompress/features/image_compression/application/image_compression_dependencies.dart';
import 'package:onecompress/features/image_compression/data/datasources/file_picker_data_source.dart';
import 'package:onecompress/features/image_compression/data/datasources/raster_image_engine_data_source.dart';
import 'package:onecompress/features/image_compression/data/datasources/share_data_source.dart';
import 'package:onecompress/features/image_compression/data/repositories/image_compression_repository_impl.dart';
import 'package:onecompress/features/image_compression/domain/usecases/compress_images_use_case.dart';
import 'package:onecompress/features/image_compression/domain/usecases/get_default_export_directory_use_case.dart';
import 'package:onecompress/features/image_compression/domain/usecases/pick_export_directory_use_case.dart';
import 'package:onecompress/features/image_compression/domain/usecases/pick_images_use_case.dart';
import 'package:onecompress/features/image_compression/domain/usecases/save_compressed_images_use_case.dart';
import 'package:onecompress/features/image_compression/domain/usecases/share_compressed_images_use_case.dart';

void main() {
  testWidgets('renders OneCompress home dashboard and floating nav bar', (tester) async {
    final repository = ImageCompressionRepositoryImpl(
      filePickerDataSource: FilePickerDataSource(),
      imageEngineDataSource: RasterImageEngineDataSource(),
      shareDataSource: ShareDataSource(),
    );

    await tester.pumpWidget(
      OneCompressApp(
        dependencies: ImageCompressionDependencies(
          pickImages: PickImagesUseCase(repository),
          pickExportDirectory: PickExportDirectoryUseCase(repository),
          getDefaultExportDirectory: GetDefaultExportDirectoryUseCase(repository),
          compressImages: CompressImagesUseCase(repository),
          saveCompressedImages: SaveCompressedImagesUseCase(repository),
          shareCompressedImages: ShareCompressedImagesUseCase(repository),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('OneCompress'), findsOneWidget);
    expect(find.text('Compress'), findsOneWidget);
    expect(find.text('Upscale'), findsOneWidget);
    expect(find.text('SOON'), findsOneWidget);
    expect(find.text('Recents'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
  });
}
