import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'features/image_compression/application/image_compression_dependencies.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final dependencies = ImageCompressionDependencies.create();
  runApp(OneCompressApp(dependencies: dependencies));
}
