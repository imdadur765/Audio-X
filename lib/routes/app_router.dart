import 'package:audio_x/data/models/song_model.dart';
import 'package:go_router/go_router.dart';
import '../presentation/pages/home_page.dart';
import '../presentation/pages/albums_page.dart';
import '../presentation/pages/player_page.dart';
import '../presentation/pages/equalizer_page.dart';
import '../presentation/widgets/scaffold_with_nav_bar.dart';
import '../presentation/pages/artist_page.dart';
import '../presentation/pages/playlist_page.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/home',
  routes: [
    // Shell route for bottom navigation
    ShellRoute(
      builder: (context, state, child) {
        return ScaffoldWithNavBar(child: child);
      },
      routes: [
        GoRoute(
          path: '/home',
          name: 'home',
          pageBuilder: (context, state) => const NoTransitionPage(child: HomePage()),
        ),
        GoRoute(
          path: '/albums',
          name: 'albums',
          pageBuilder: (context, state) => const NoTransitionPage(child: AlbumsPage()),
        ),
        GoRoute(
          path: '/artists',
          name: 'artists',
          pageBuilder: (context, state) => const NoTransitionPage(child: ArtistPage()),
        ),
        GoRoute(
          path: '/playlists',
          name: 'playlists',
          pageBuilder: (context, state) => const NoTransitionPage(child: PlaylistPage()),
        ),
      ],
    ),

    // Full-screen routes (no bottom nav)
    GoRoute(
      path: '/player',
      name: 'player',
      builder: (context, state) => PlayerPage(song: state.extra as Song),
    ),
    GoRoute(path: '/equalizer', name: 'equalizer', builder: (context, state) => const EqualizerPage()),
  ],
);
