import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audio_x/presentation/controllers/audio_controller.dart';
import 'package:audio_x/presentation/pages/home_page.dart';
import 'package:audio_x/presentation/pages/artists_screen.dart';
import 'package:audio_x/presentation/pages/albums_page.dart';
import 'package:audio_x/presentation/pages/playlists_page.dart';
import 'package:audio_x/presentation/pages/favorites_page.dart';
import 'package:audio_x/presentation/widgets/mini_player.dart';

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> with WidgetsBindingObserver {
  int _currentIndex = 0;
  SharedPreferences? _prefs;

  final List<Widget> _pages = const [HomePage(), ArtistsScreen(), AlbumsPage(), PlaylistsPage(), FavoritesPage()];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSavedState();

    // Only load songs if not already loaded to prevent resetting player state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final audioController = Provider.of<AudioController>(context, listen: false);
      if (audioController.songs.isEmpty) {
        audioController.loadSongs();
      }
    });
  }

  Future<void> _loadSavedState() async {
    _prefs = await SharedPreferences.getInstance();
    final savedIndex = _prefs?.getInt('nav_index') ?? 0;

    // Validate saved index is in valid range
    if (savedIndex >= 0 && savedIndex < _pages.length) {
      setState(() {
        _currentIndex = savedIndex;
      });
    }
  }

  Future<void> _saveState() async {
    await _prefs?.setInt('nav_index', _currentIndex);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Save state when app goes to background or becomes inactive
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _saveState();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;

        // Minimize app instead of closing
        const platform = MethodChannel('com.example.audio_x/audio');
        try {
          await platform.invokeMethod('minimizeApp');
        } catch (e) {
          print("Failed to minimize app: $e");
        }
      },
      child: Scaffold(
        body: IndexedStack(index: _currentIndex, children: _pages),
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
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, -5)),
                ],
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
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
        _saveState(); // Save immediately when user changes tab
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
                boxShadow: isActive
                    ? [BoxShadow(color: Colors.deepPurple.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))]
                    : null,
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
