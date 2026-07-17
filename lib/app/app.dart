import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/image_compression/application/image_compression_dependencies.dart';
import '../features/navigation/presentation/pages/main_navigation_page.dart';

class OneCompressApp extends StatelessWidget {
  const OneCompressApp({required this.dependencies, super.key});

  final ImageCompressionDependencies dependencies;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OneCompress',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: MainNavigationPage(dependencies: dependencies),
    );
  }
}
