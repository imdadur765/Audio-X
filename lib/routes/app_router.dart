import 'package:flutter/material.dart';
import 'package:audio_x/data/models/song_model.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../presentation/controllers/audio_controller.dart';
import '../presentation/pages/home_page.dart';
import '../presentation/pages/albums_page.dart';
import '../presentation/pages/player_page.dart';
import '../presentation/pages/equalizer_page.dart';
import '../presentation/widgets/scaffold_with_nav_bar.dart';
import '../presentation/pages/artists_list_page.dart';
import '../presentation/pages/playlist_page.dart';
import '../presentation/pages/artist_details_page.dart';
import '../presentation/pages/album_details_page.dart';
import '../presentation/pages/album_info_page.dart';
import '../presentation/pages/search_page.dart';
import '../presentation/pages/recently_added_page.dart';
import '../presentation/pages/most_played_page.dart';
import '../presentation/pages/favorites_page.dart';
import '../presentation/pages/all_songs_page.dart';
import '../presentation/pages/recently_played_page.dart';
import '../presentation/pages/playlist_details_page.dart';
import '../presentation/pages/profile_page.dart';

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
          path: '/songs',
          name: 'songs',
          pageBuilder: (context, state) {
            return NoTransitionPage(
              child: Consumer<AudioController>(
                builder: (context, controller, child) => AllSongsPage(songs: controller.allSongs),
              ),
            );
          },
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
          routes: [
            GoRoute(
              path: 'recently_added',
              name: 'recently_added',
              pageBuilder: (context, state) {
                final songs = state.extra as List<Song>;
                return CustomTransitionPage(
                  child: RecentlyAddedPage(songs: songs),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return SlideTransition(
                      position: Tween(begin: const Offset(1.0, 0.0), end: Offset.zero).animate(animation),
                      child: child,
                    );
                  },
                );
              },
            ),
            GoRoute(
              path: 'most_played',
              name: 'most_played',
              pageBuilder: (context, state) {
                final songs = state.extra as List<Song>;
                return CustomTransitionPage(
                  child: MostPlayedPage(songs: songs),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return SlideTransition(
                      position: Tween(begin: const Offset(1.0, 0.0), end: Offset.zero).animate(animation),
                      child: child,
                    );
                  },
                );
              },
            ),
            GoRoute(
              path: 'favorites',
              name: 'favorites',
              pageBuilder: (context, state) {
                final songs = state.extra as List<Song>;
                return CustomTransitionPage(
                  child: FavoritesPage(songs: songs),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return SlideTransition(
                      position: Tween(begin: const Offset(1.0, 0.0), end: Offset.zero).animate(animation),
                      child: child,
                    );
                  },
                );
              },
            ),
            GoRoute(
              path: 'all_songs',
              name: 'all_songs',
              pageBuilder: (context, state) {
                final songs = state.extra as List<Song>;
                return CustomTransitionPage(
                  child: AllSongsPage(songs: songs),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return SlideTransition(
                      position: Tween(begin: const Offset(1.0, 0.0), end: Offset.zero).animate(animation),
                      child: child,
                    );
                  },
                );
              },
            ),
            GoRoute(
              path: 'recently_played',
              name: 'recently_played',
              pageBuilder: (context, state) {
                final songs = state.extra as List<Song>;
                return CustomTransitionPage(
                  child: RecentlyPlayedPage(songs: songs),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return SlideTransition(
                      position: Tween(begin: const Offset(1.0, 0.0), end: Offset.zero).animate(animation),
                      child: child,
                    );
                  },
                );
              },
            ),
            GoRoute(
              path: 'details/:id',
              name: 'playlist_details',
              pageBuilder: (context, state) {
                final extra = state.extra as Map<String, dynamic>;
                return CustomTransitionPage(
                  child: PlaylistDetailsPage(
                    playlistId: state.pathParameters['id']!,
                    title: extra['title'],
                    songs: extra['songs'],
                    gradientColors: extra['gradientColors'],
                    isAuto: extra['isAuto'],
                  ),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return SlideTransition(
                      position: Tween(begin: const Offset(1.0, 0.0), end: Offset.zero).animate(animation),
                      child: child,
                    );
                  },
                );
              },
            ),
          ],
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
    GoRoute(path: '/profile', name: 'profile', builder: (context, state) => const ProfilePage()),
    GoRoute(path: '/equalizer', name: 'equalizer', builder: (context, state) => const EqualizerPage()),
    GoRoute(path: '/search', name: 'search', builder: (context, state) => const SearchPage()),
    GoRoute(
      path: '/album_info',
      name: 'album_info',
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return CustomTransitionPage(
          key: state.pageKey,
          child: AlbumInfoPage(
            albumName: extra['albumName'],
            artistName: extra['artistName'],
            albumArt: extra['albumArt'],
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        );
      },
    ),
  ],
);
