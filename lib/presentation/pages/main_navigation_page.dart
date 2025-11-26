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

  final List<Widget> _pages = const [HomePage(), ArtistsListPage(), AlbumsPage(), PlaylistsPage(), FavoritesPage()];

  @override
  void initState() {
    super.initState();
    // Load songs when app starts
    Future.microtask(() => Provider.of<AudioController>(context, listen: false).loadSongs());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mini Player
          const MiniPlayer(),

          // Navigation Bar
          NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Artists',
              ),
              NavigationDestination(icon: Icon(Icons.album_outlined), selectedIcon: Icon(Icons.album), label: 'Albums'),
              NavigationDestination(
                icon: Icon(Icons.playlist_play_outlined),
                selectedIcon: Icon(Icons.playlist_play),
                label: 'Playlists',
              ),
              NavigationDestination(
                icon: Icon(Icons.favorite_outline),
                selectedIcon: Icon(Icons.favorite),
                label: 'Favorites',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
