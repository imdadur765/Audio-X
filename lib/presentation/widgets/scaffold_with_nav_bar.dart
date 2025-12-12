import 'package:audio_x/presentation/widgets/mini_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../controllers/audio_controller.dart';

class ScaffoldWithNavBar extends StatelessWidget {
  final Widget child;

  const ScaffoldWithNavBar({required this.child, super.key});

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/songs')) return 1;
    if (location.startsWith('/artists')) return 2;
    if (location.startsWith('/albums')) return 3;
    if (location.startsWith('/playlists')) return 4;
    return 0;
  }

  void _onItemTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/songs');
        break;
      case 2:
        context.go('/artists');
        break;
      case 3:
        context.go('/albums');
        break;
      case 4:
        context.go('/playlists');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final int selectedIndex = _calculateSelectedIndex(context);

    // Listen to AudioController for dynamic colors
    return Consumer<AudioController>(
      builder: (context, controller, _) {
        final accentColor = controller.accentColor;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;

            // If on home tab, minimize app using native method
            if (selectedIndex == 0) {
              const platform = MethodChannel('com.example.audio_x/audio');
              try {
                await platform.invokeMethod('minimizeApp');
              } catch (e) {
                debugPrint("Failed to minimize app: $e");
                // Fallback to standard pop if native method fails
                await SystemChannels.platform.invokeMethod('SystemNavigator.pop');
              }
            } else {
              // Go back to home tab
              if (context.mounted) {
                context.go('/home');
              }
            }
          },
          child: Scaffold(
            extendBody: true, // Important for glass effect to show content behind
            body: child,
            bottomNavigationBar: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Mini Player
                MiniPlayer(),

                // Custom Modern Bottom Navigation Bar
                ClipRRect(
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.black.withValues(alpha: 0.6)
                            : Colors.white.withValues(alpha: 0.8), // Adaptive Glass
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                        border: Border(
                          top: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, -5),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildNavItem(
                              context,
                              index: 0,
                              selectedIndex: selectedIndex,
                              activeImage: 'assets/images/home_open.png',
                              inactiveImage: 'assets/images/home_close.png',
                              label: 'Home',
                              accentColor: accentColor,
                            ),
                            _buildNavItem(
                              context,
                              index: 1,
                              selectedIndex: selectedIndex,
                              activeImage: 'assets/images/song.png',
                              inactiveImage: 'assets/images/song.png',
                              label: 'Songs',
                              accentColor: accentColor,
                            ),
                            _buildNavItem(
                              context,
                              index: 2,
                              selectedIndex: selectedIndex,
                              activeImage: 'assets/images/artist_open.png',
                              inactiveImage: 'assets/images/artist_close.png',
                              label: 'Artists',
                              accentColor: accentColor,
                            ),
                            _buildNavItem(
                              context,
                              index: 3,
                              selectedIndex: selectedIndex,
                              activeImage: 'assets/images/album_list_open.png',
                              inactiveImage: 'assets/images/album_list_close.png',
                              label: 'Albums',
                              accentColor: accentColor,
                            ),
                            _buildNavItem(
                              context,
                              index: 4,
                              selectedIndex: selectedIndex,
                              activeImage: 'assets/images/playlist_open.png',
                              inactiveImage: 'assets/images/playlist_close.png',
                              label: 'Playlists',
                              accentColor: accentColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required int index,
    required int selectedIndex,
    required String activeImage,
    required String inactiveImage,
    required String label,
    required Color accentColor,
  }) {
    final isActive = selectedIndex == index;

    return GestureDetector(
      onTap: () => _onItemTapped(context, index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? accentColor.withValues(alpha: 0.15) : Colors.transparent, // Dynamic Background
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isActive ? accentColor : Colors.transparent, // Dynamic Circle
                shape: BoxShape.circle,
                boxShadow: isActive
                    ? [BoxShadow(color: accentColor.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 2))]
                    : null,
              ),
              child: Image.asset(
                isActive ? activeImage : inactiveImage,
                width: 20,
                height: 20,
                color: isActive ? Colors.white : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive
                    ? accentColor
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), // Dynamic Text
              ),
            ),
          ],
        ),
      ),
    );
  }
}
