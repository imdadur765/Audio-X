import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audio_x/presentation/controllers/audio_controller.dart';
import 'package:audio_x/presentation/pages/home_page.dart';
import 'package:audio_x/presentation/pages/artists_list_page.dart';
import 'package:audio_x/presentation/pages/albums_page.dart';
import 'package:audio_x/presentation/pages/playlists_page.dart';
import 'package:audio_x/presentation/pages/favorites_page.dart';
import 'package:audio_x/presentation/widgets/mini_player.dart';

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomePage(),
    ArtistsListPage(),
    AlbumsPage(),
    PlaylistsPage(),
    FavoritesPage()
  ];

  @override
  void initState() {
    super.initState();
    // Load songs when app starts
    Future.microtask(() => Provider.of<AudioController>(context, listen: false).loadSongs());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mini Player
          const MiniPlayer(),

          // Custom Modern Bottom Navigation Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(0, Icons.home_rounded, Icons.home_outlined, 'Home'),
                  _buildNavItem(1, Icons.person_rounded, Icons.person_outline_rounded, 'Artists'),
                  _buildNavItem(2, Icons.album_rounded, Icons.album_outlined, 'Albums'),
                  _buildNavItem(3, Icons.playlist_play_rounded, Icons.playlist_play_outlined, 'Playlists'),
                  _buildNavItem(4, Icons.favorite_rounded, Icons.favorite_outline_rounded, 'Favorites'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData activeIcon, IconData inactiveIcon, String label) {
    final isActive = _currentIndex == index;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.deepPurple.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isActive ? Colors.deepPurple : Colors.transparent,
                shape: BoxShape.circle,
                boxShadow: isActive ? [
                  BoxShadow(
                    color: Colors.deepPurple.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ] : null,
              ),
              child: Icon(
                isActive ? activeIcon : inactiveIcon,
                color: isActive ? Colors.white : Colors.grey.shade600,
                size: 20,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive ? Colors.deepPurple : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}