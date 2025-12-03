import 'package:flutter/material.dart';
import 'package:audio_x/data/models/song_model.dart';
import 'package:go_router/go_router.dart';
import '../presentation/pages/home_page.dart';
import '../presentation/pages/albums_page.dart';
import '../presentation/pages/player_page.dart';
import '../presentation/pages/equalizer_page.dart';
import '../presentation/widgets/scaffold_with_nav_bar.dart';
import '../presentation/pages/artists_list_page.dart';
import '../presentation/pages/playlist_page.dart';
import '../presentation/pages/artist_details_page.dart';
import '../presentation/pages/album_details_page.dart';
import '../presentation/pages/search_page.dart';

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
          pageBuilder: (context, state) => const NoTransitionPage(child: ArtistsListPage()),
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
      pageBuilder: (context, state) {
        Song song;
        String? heroTag;

        if (state.extra is Map<String, dynamic>) {
          final extras = state.extra as Map<String, dynamic>;
          song = extras['song'] as Song;
          heroTag = extras['heroTag'] as String?;
        } else if (state.extra is Song) {
          song = state.extra as Song;
          heroTag = null;
        } else {
          // Fallback for safety
          return const NoTransitionPage(child: SizedBox());
        }

        return CustomTransitionPage(
          key: state.pageKey,
          child: PlayerPage(song: song, heroTag: heroTag),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(0.0, 1.0);
            const end = Offset.zero;
            const curve = Curves.easeOutCubic;

            var slideTween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            var fadeTween = Tween(begin: 0.0, end: 1.0);

            return SlideTransition(
              position: animation.drive(slideTween),
              child: FadeTransition(opacity: animation.drive(fadeTween), child: child),
            );
          },
        );
      },
    ),
    GoRoute(
      path: '/artist/:name',
      name: 'artist_details',
      pageBuilder: (context, state) {
        final artistName = state.pathParameters['name']!;
        final heroTag = state.extra as String?;
        return CustomTransitionPage(
          key: state.pageKey,
          child: ArtistDetailsPage(artistName: artistName, heroTag: heroTag),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(0.0, 0.1);
            const end = Offset.zero;
            const curve = Curves.easeOutCubic;

            var slideTween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            var fadeTween = Tween(begin: 0.0, end: 1.0);

            return SlideTransition(
              position: animation.drive(slideTween),
              child: FadeTransition(opacity: animation.drive(fadeTween), child: child),
            );
          },
        );
      },
    ),
    GoRoute(
      path: '/album/:name',
      name: 'album_details',
      pageBuilder: (context, state) {
        final albumName = state.pathParameters['name']!;
        final extra = state.extra as Map<String, dynamic>?;
        final songs = extra?['songs'] as List<Song>? ?? [];
        final heroTag = extra?['heroTag'] as String?;

        return CustomTransitionPage(
          key: state.pageKey,
          child: AlbumDetailsPage(albumName: albumName, songs: songs, heroTag: heroTag),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(0.0, 0.1);
            const end = Offset.zero;
            const curve = Curves.easeOutCubic;

            var slideTween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            var fadeTween = Tween(begin: 0.0, end: 1.0);

            return SlideTransition(
              position: animation.drive(slideTween),
              child: FadeTransition(opacity: animation.drive(fadeTween), child: child),
            );
          },
        );
      },
    ),
    GoRoute(path: '/equalizer', name: 'equalizer', builder: (context, state) => const EqualizerPage()),
    GoRoute(path: '/search', name: 'search', builder: (context, state) => const SearchPage()),
  ],
);
