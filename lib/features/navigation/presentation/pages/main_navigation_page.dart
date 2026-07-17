import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../image_compression/application/image_compression_dependencies.dart';
import '../../../image_compression/presentation/controllers/image_compression_controller.dart';
import '../../../image_compression/presentation/pages/home_page.dart';
import '../../../image_compression/presentation/pages/image_compression_page.dart';
import '../../../image_compression/presentation/pages/history_page.dart';
import '../../../image_compression/presentation/pages/settings_page.dart';

class MainNavigationPage extends StatefulWidget {
  final ImageCompressionDependencies dependencies;

  const MainNavigationPage({required this.dependencies, super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _currentIndex = 0;
  late final ImageCompressionController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ImageCompressionController(
      pickImagesUseCase: widget.dependencies.pickImages,
      pickExportDirectoryUseCase: widget.dependencies.pickExportDirectory,
      compressImagesUseCase: widget.dependencies.compressImages,
      saveCompressedImagesUseCase: widget.dependencies.saveCompressedImages,
      shareCompressedImagesUseCase: widget.dependencies.shareCompressedImages,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _navigateToCompress() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ImageCompressionPage(controller: _controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      HomePage(
        controller: _controller,
        onOpenCompress: _navigateToCompress,
        onOpenHistory: () => setState(() => _currentIndex = 1),
      ),
      HistoryPage(controller: _controller),
      const SettingsPage(),
      const SettingsPage(), // Placeholder for 4th tab
    ];

    return Scaffold(
      extendBody: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: SafeArea(
        bottom: true,
        child: Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
          child: _FloatingNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
          ),
        ),
      ),
    );
  }
}

class _FloatingNavigationBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _FloatingNavigationBar({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceColor = Theme.of(context).colorScheme.surface;
    final outlineColor = Theme.of(context).colorScheme.outline;

    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(36),
        border: Border.all(
          color: outlineColor.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 32,
            spreadRadius: 4,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = constraints.maxWidth / 4;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutBack, // Spring animation
                left: currentIndex * itemWidth,
                top: 0,
                bottom: 0,
                width: itemWidth,
                child: Center(
                  child: Container(
                    height: 52,
                    width: itemWidth - 16, // Allowing constraints for inner pill
                    decoration: BoxDecoration(
                      color: surfaceColor.withValues(alpha: 0.8), // Slightly brighter surface overlay logic
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 12,
                          spreadRadius: 2,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _NavItem(
                    title: 'Home',
                    icon: HugeIcons.strokeRoundedHome01,
                    isSelected: currentIndex == 0,
                    onTap: () => onTap(0),
                    width: itemWidth,
                  ),
                  _NavItem(
                    title: 'History',
                    icon: HugeIcons.strokeRoundedTime02,
                    isSelected: currentIndex == 1,
                    onTap: () => onTap(1),
                    width: itemWidth,
                  ),
                  _NavItem(
                    title: 'Tools',
                    icon: HugeIcons.strokeRoundedDashboardSquare01,
                    isSelected: currentIndex == 2,
                    onTap: () => onTap(2),
                    width: itemWidth,
                  ),
                  _NavItem(
                    title: 'Profile',
                    icon: HugeIcons.strokeRoundedUser,
                    isSelected: currentIndex == 3,
                    onTap: () => onTap(3),
                    width: itemWidth,
                    badgeCount: 3,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String title;
  final List<List<dynamic>> icon;
  final bool isSelected;
  final VoidCallback onTap;
  final double width;
  final int badgeCount;

  const _NavItem({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.width,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeColor = colorScheme.primary;
    final inactiveColor = colorScheme.onSurface.withValues(alpha: 0.75);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 24,
              width: 32, // to give room for badge
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  AnimatedScale(
                    scale: isSelected ? 1.06 : 1.0,
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutBack,
                    child: HugeIcon(
                      icon: icon,
                      size: 24,
                      color: isSelected ? activeColor : inactiveColor,
                    ),
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.rectangle,
                          borderRadius: BorderRadius.all(Radius.circular(9)),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          badgeCount > 99 ? '99+' : badgeCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            height: 1,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 240),
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? activeColor : inactiveColor,
              ),
              child: Text(title),
            ),
          ],
        ),
      ),
    );
  }
}
