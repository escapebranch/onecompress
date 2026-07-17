import 'package:flutter_test/flutter_test.dart';
import 'package:onecompress/app/app.dart';
import 'package:onecompress/features/image_compression/application/image_compression_dependencies.dart';
import 'package:onecompress/features/image_compression/data/datasources/file_picker_data_source.dart';
import 'package:onecompress/features/image_compression/data/datasources/raster_image_engine_data_source.dart';
import 'package:onecompress/features/image_compression/data/datasources/share_data_source.dart';
import 'package:onecompress/features/image_compression/data/repositories/image_compression_repository_impl.dart';
import 'package:onecompress/features/image_compression/domain/usecases/compress_images_use_case.dart';
import 'package:onecompress/features/image_compression/domain/usecases/pick_export_directory_use_case.dart';
import 'package:onecompress/features/image_compression/domain/usecases/pick_images_use_case.dart';
import 'package:onecompress/features/image_compression/domain/usecases/save_compressed_images_use_case.dart';
import 'package:onecompress/features/image_compression/domain/usecases/share_compressed_images_use_case.dart';

void main() {
  testWidgets('renders image compression workspace', (tester) async {
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
          compressImages: CompressImagesUseCase(repository),
          saveCompressedImages: SaveCompressedImagesUseCase(repository),
          shareCompressedImages: ShareCompressedImagesUseCase(repository),
        ),
      ),
    );

    expect(find.text('OneCompress'), findsOneWidget);
    expect(find.text('Compression & Engine Settings'), findsOneWidget);
    expect(find.text('Actions'), findsOneWidget);
    expect(find.text('Select images'), findsOneWidget);
  });
}
