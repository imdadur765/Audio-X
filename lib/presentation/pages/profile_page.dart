import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../../data/services/auth_service.dart';
import '../../data/services/artist_service.dart';
import '../../services/cloud_sync_service.dart';
import '../../services/playlist_service.dart';
import '../../services/listening_stats_service.dart';
import '../../services/achievements_service.dart';
import '../controllers/audio_controller.dart';
import '../widgets/glass_background.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthService _authService = AuthService();
  final CloudSyncService _cloudSync = CloudSyncService();
  final ListeningStatsService _statsService = ListeningStatsService();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;

  // Streak data
  int _currentStreak = 0;
  int _bestStreak = 0;
  List<bool> _weeklyActivity = List.filled(7, false);

  // Achievements data
  final AchievementsService _achievementsService = AchievementsService();
  List<Map<String, dynamic>> _achievements = [];

  @override
  void initState() {
    super.initState();
    _loadLastSyncTime();
    _loadStreakData();
    _scrollController.addListener(() => setState(() {}));
    CloudSyncService.lastSyncNotifier.addListener(_onSyncUpdate);
    // Load achievements after a delay to get fresh data
    Future.delayed(const Duration(milliseconds: 500), _loadAchievements);
  }

  void _onSyncUpdate() {
    if (mounted) {
      setState(() => _lastSyncTime = CloudSyncService.lastSyncNotifier.value);
    }
  }

  Future<void> _loadLastSyncTime() async {
    if (CloudSyncService.lastSyncNotifier.value != null) {
      setState(() => _lastSyncTime = CloudSyncService.lastSyncNotifier.value);
      return;
    }
    final time = await _cloudSync.getLastSyncTime();
    if (mounted) setState(() => _lastSyncTime = time);
  }

  Future<void> _loadStreakData() async {
    final current = await _statsService.getCurrentStreak();
    final best = await _statsService.getBestStreak();
    final weekly = await _statsService.getWeeklyActivity();
    if (mounted) {
      setState(() {
        _currentStreak = current;
        _bestStreak = best;
        _weeklyActivity = weekly;
      });
    }
  }

  Future<void> _loadAchievements() async {
    if (!mounted) return;
    final audioController = Provider.of<AudioController>(context, listen: false);
    final playlistService = PlaylistService();
    final playlists = await playlistService.getCustomPlaylists();

    final totalPlays = audioController.allSongs.fold<int>(0, (sum, s) => sum + s.playCount);
    final favoritesCount = audioController.allSongs.where((s) => s.isFavorite).length;

    final achievements = await _achievementsService.getAchievementsWithStatus(
      totalPlays: totalPlays,
      favoritesCount: favoritesCount,
      playlistsCount: playlists.length,
      currentStreak: _currentStreak,
      bestStreak: _bestStreak,
    );

    if (mounted) {
      setState(() => _achievements = achievements);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    CloudSyncService.lastSyncNotifier.removeListener(_onSyncUpdate);
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    final user = await _authService.signInWithGoogle();
    if (mounted) {
      setState(() => _isLoading = false);
      if (user != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Welcome, ${user.displayName}!')));
        _handleSync();
      }
    }
  }

  Future<void> _handleSignOut() async {
    setState(() => _isLoading = true);
    await _authService.signOut();
    if (mounted) {
      setState(() {
        _isLoading = false;
        _lastSyncTime = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signed out successfully')));
    }
  }

  Future<void> _handleSync() async {
    if (!_authService.isLoggedIn) return;
    setState(() => _isSyncing = true);

    final audioController = Provider.of<AudioController>(context, listen: false);
    final playlistService = PlaylistService();

    final success = await _cloudSync.syncOnLogin(
      onFavoritesDownloaded: (ids) => audioController.applyCloudFavorites(ids),
      onPlaylistsDownloaded: (pls) => playlistService.mergeCloudPlaylists(pls),
    );

    if (mounted) {
      setState(() => _isSyncing = false);
      if (success) {
        _loadLastSyncTime();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sync completed!')));
      }
    }
  }

  String _getLastSyncText() {
    if (_lastSyncTime == null) return 'Never synced';
    final diff = DateTime.now().difference(_lastSyncTime!);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    return '${diff.inDays} days ago';
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = _authService.isLoggedIn;
    final photoUrl = _authService.userPhotoUrl;
    final audioController = Provider.of<AudioController>(context);

    // Calculate stats
    final totalPlays = audioController.allSongs.fold<int>(0, (sum, s) => sum + s.playCount);
    final avgDuration = audioController.allSongs.isEmpty
        ? 0
        : audioController.allSongs.fold<int>(0, (sum, s) => sum + s.duration) ~/ audioController.allSongs.length;
    final hoursListened = (totalPlays * avgDuration) / 3600000;

    // Check if scrolled for blur effect
    final isScrolled = _scrollController.hasClients && _scrollController.offset > 10;

    return Stack(
      children: [
        // Glass Background (matching other pages)
        GlassBackground(
          artworkPath: audioController.currentSong?.localArtworkPath,
          accentColor: audioController.accentColor,
          isDark: Theme.of(context).brightness == Brightness.dark,
        ),

        Scaffold(
          backgroundColor: Colors.transparent,
          body: CustomScrollView(
            controller: _scrollController,
            slivers: [
              // SliverAppBar with blur effect
              SliverAppBar(
                pinned: true,
                floating: false,
                backgroundColor: isScrolled ? Colors.black.withOpacity(0.4) : Colors.transparent,
                elevation: 0,
                systemOverlayStyle: SystemUiOverlayStyle.light,
                leading: IconButton(
                  icon: Image.asset(
                    'assets/images/back.png',
                    width: 24,
                    height: 24,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  onPressed: () => context.pop(),
                ),
                title: Text(
                  'Profile',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                ),
                actions: [
                  IconButton(
                    icon: Image.asset(
                      'assets/images/settings.png',
                      width: 24,
                      height: 24,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    onPressed: () => context.push('/settings'),
                  ),
                ],
                flexibleSpace: ClipRRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: isScrolled ? 20 : 0, sigmaY: isScrolled ? 20 : 0),
                    child: Container(color: Theme.of(context).colorScheme.surface.withOpacity(0.1)),
                  ),
                ),
              ),

              // Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Profile Card
                      _buildProfileCard(isLoggedIn, photoUrl),

                      const SizedBox(height: 24),

                      // Sign In / Out Button
                      if (_isLoading)
                        const Center(child: CircularProgressIndicator())
                      else if (!isLoggedIn)
                        _buildGoogleSignInButton()
                      else
                        _buildSignOutButton(),

                      const SizedBox(height: 24),

                      // Listening Stats Section
                      _buildSectionTitle('Your Stats'),
                      const SizedBox(height: 12),

                      _buildStatsCard(
                        totalPlays: totalPlays,
                        hoursListened: hoursListened,
                        totalSongs: audioController.allSongs.length,
                        favorites: audioController.allSongs.where((s) => s.isFavorite).length,
                      ),

                      const SizedBox(height: 24),

                      // Music Streak Section
                      _buildSectionTitle('Music Streak'),
                      const SizedBox(height: 12),
                      _buildStreakCard(),

                      const SizedBox(height: 24),

                      // Top Artists Section
                      _buildSectionTitle('Your Top Artists'),
                      const SizedBox(height: 12),
                      _buildTopArtistsSection(audioController),

                      const SizedBox(height: 24),

                      // Achievements Section
                      _buildSectionTitle('Achievements'),
                      const SizedBox(height: 12),
                      _buildAchievementsSection(),

                      // Cloud Sync Section (only if logged in)
                      if (isLoggedIn) ...[
                        const SizedBox(height: 24),
                        _buildSectionTitle('Cloud Sync'),
                        const SizedBox(height: 12),
                        _buildCloudSyncCard(),
                      ],

                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return SizedBox(
      width: double.infinity,
      child: Text(
        title,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
      ),
    );
  }

  Widget _buildProfileCard(bool isLoggedIn, String? photoUrl) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surface.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.onSurface.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          // Avatar
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: colorScheme.onSurface.withOpacity(0.3), width: 3),
                  boxShadow: [BoxShadow(color: Colors.deepPurple.withOpacity(0.3), blurRadius: 20, spreadRadius: 2)],
                ),
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                  child: photoUrl == null
                      ? Image.asset(
                          'assets/images/profile.png',
                          width: 50,
                          height: 50,
                          color: colorScheme.onSurface.withOpacity(0.5),
                        )
                      : null,
                ),
              ),
              if (isLoggedIn)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: colorScheme.surface, width: 2),
                  ),
                  child: Icon(Icons.check, size: 14, color: Theme.of(context).colorScheme.onSurface),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Name
          Text(
            _authService.userName,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
          ),
          if (isLoggedIn && _authService.currentUser?.email != null)
            Text(
              _authService.currentUser!.email!,
              style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6), fontSize: 14),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsCard({
    required int totalPlays,
    required double hoursListened,
    required int totalSongs,
    required int favorites,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.onSurface.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatItem('assets/images/most_played.png', '$totalPlays', 'Songs Played', Colors.pink),
              ),
              Container(width: 1, height: 50, color: colorScheme.onSurface.withOpacity(0.1)),
              Expanded(
                child: _buildStatItem(
                  'assets/images/duration.png',
                  hoursListened.toStringAsFixed(1),
                  'Hours',
                  Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: colorScheme.onSurface.withOpacity(0.1)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildStatItem('assets/images/song.png', '$totalSongs', 'Total Songs', Colors.blue)),
              Container(width: 1, height: 50, color: colorScheme.onSurface.withOpacity(0.1)),
              Expanded(child: _buildStatItem('assets/images/favorite.png', '$favorites', 'Favorites', Colors.red)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String iconPath, String value, String label, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
          child: Image.asset(iconPath, width: 22, height: 22, color: color),
        ),
        const SizedBox(height: 10),
        Text(
          value,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
        ),
        Text(label, style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
      ],
    );
  }

  Widget _buildCloudSyncCard() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.cloud_done, color: Colors.blue, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Favorites & Playlists',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: colorScheme.onSurface),
                ),
                Text(
                  'Last synced: ${_getLastSyncText()}',
                  style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6), fontSize: 12),
                ),
              ],
            ),
          ),
          _isSyncing
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue),
                )
              : IconButton(
                  icon: const Icon(Icons.sync, color: Colors.blue),
                  onPressed: _handleSync,
                ),
        ],
      ),
    );
  }

  Widget _buildGoogleSignInButton() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        color: colorScheme.surface.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.onSurface.withOpacity(0.2)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _handleGoogleSignIn,
          borderRadius: BorderRadius.circular(14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/images/google.png', width: 24, height: 24),
              const SizedBox(width: 12),
              Text(
                'Sign in with Google',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignOutButton() {
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _handleSignOut,
          borderRadius: BorderRadius.circular(14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/images/signout.png', width: 22, height: 22, color: Colors.red.shade400),
              const SizedBox(width: 12),
              Text(
                'Sign Out',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.red.shade400),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStreakCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.orange.withOpacity(0.2), Colors.deepOrange.withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          // Streak Info Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Current Streak
              Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/images/day_streak.png', width: 32, height: 32, color: Colors.orange),
                      const SizedBox(width: 8),
                      Text(
                        '$_currentStreak',
                        style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.orange),
                      ),
                    ],
                  ),
                  Text(
                    'Day Streak',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 14),
                  ),
                ],
              ),
              // Divider
              Container(width: 1, height: 60, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1)),
              // Best Streak
              Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/images/best_streak.png', width: 28, height: 28, color: Colors.amber),
                      const SizedBox(width: 8),
                      Text(
                        '$_bestStreak',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.amber),
                      ),
                    ],
                  ),
                  Text(
                    'Best Streak',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 14),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Weekly Activity
          Column(
            children: [
              Text(
                'This Week',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 12),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(7, (index) {
                  final dayLabels = ['T', 'Y', '2d', '3d', '4d', '5d', '6d'];
                  final isActive = _weeklyActivity[index];
                  return Column(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isActive
                              ? Colors.orange.withOpacity(0.8)
                              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isActive
                                ? Colors.orange
                                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24),
                            width: 2,
                          ),
                        ),
                        child: isActive
                            ? Icon(Icons.music_note, size: 16, color: Theme.of(context).colorScheme.onSurface)
                            : null,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dayLabels[index],
                        style: TextStyle(
                          color: isActive ? Colors.orange : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                          fontSize: 10,
                          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopArtistsSection(AudioController audioController) {
    final topArtists = ListeningStatsService.getTopArtists(audioController.allSongs, limit: 5);

    if (topArtists.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
        ),
        child: Center(
          child: Text(
            'Play some songs to see your top artists!',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
          ),
        ),
      );
    }

    return SizedBox(
      height: 130,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: topArtists.length,
        itemBuilder: (context, index) {
          final artist = topArtists[index];
          final colors = [Colors.purple, Colors.blue, Colors.teal, Colors.orange, Colors.pink];
          final color = colors[index % colors.length];

          return Container(
            width: 100,
            margin: EdgeInsets.only(right: index < topArtists.length - 1 ? 12 : 0),
            child: Column(
              children: [
                // Avatar with cached artist image
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: color.withOpacity(0.5), width: 2),
                    boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 10, spreadRadius: 1)],
                  ),
                  child: ClipOval(child: _buildArtistAvatar(artist['name'], color)),
                ),
                const SizedBox(height: 8),
                // Name
                Text(
                  artist['name'],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                // Play count
                Text('${artist['playCount']} plays', style: TextStyle(color: color, fontSize: 10)),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Build artist avatar with cached image from Spotify or fallback initial
  Widget _buildArtistAvatar(String artistName, Color fallbackColor) {
    final artistService = ArtistService();
    final cachedArtist = artistService.getCachedArtist(artistName);
    final imageUrl = cachedArtist?.imageUrl;

    if (imageUrl != null && imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        width: 70,
        height: 70,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildFallbackAvatar(artistName, fallbackColor),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildFallbackAvatar(artistName, fallbackColor);
        },
      );
    }

    return _buildFallbackAvatar(artistName, fallbackColor);
  }

  Widget _buildFallbackAvatar(String artistName, Color color) {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.6), color.withOpacity(0.3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          artistName.isNotEmpty ? artistName.substring(0, 1).toUpperCase() : '?',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
        ),
      ),
    );
  }

  Widget _buildAchievementsSection() {
    if (_achievements.isEmpty) {
      return Container(
        width: double.infinity,
        height: 160,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      );
    }

    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _achievements.length,
        itemBuilder: (context, index) {
          final data = _achievements[index];
          final achievement = data['achievement'] as Achievement;
          final isUnlocked = data['isUnlocked'] as bool;
          final progress = data['progress'] as int;

          return Container(
            width: 110,
            margin: EdgeInsets.only(right: index < _achievements.length - 1 ? 12 : 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isUnlocked
                          ? [Colors.amber.withOpacity(0.2), Colors.orange.withOpacity(0.1)]
                          : [Colors.grey.withOpacity(0.1), Colors.grey.withOpacity(0.05)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isUnlocked
                          ? Colors.amber.withOpacity(0.4)
                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                    ),
                    boxShadow: isUnlocked
                        ? [BoxShadow(color: Colors.amber.withOpacity(0.2), blurRadius: 12, spreadRadius: 1)]
                        : null,
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Badge Icon
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: isUnlocked ? Colors.amber.withOpacity(0.15) : Colors.grey.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: ColorFiltered(
                                colorFilter: ColorFilter.mode(
                                  isUnlocked ? Colors.amber : Colors.grey.shade600,
                                  BlendMode.srcIn,
                                ),
                                child: Image.asset(achievement.iconPath, width: 28, height: 28),
                              ),
                            ),
                          ),
                          if (!isUnlocked)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(color: Colors.grey.shade800, shape: BoxShape.circle),
                                child: Icon(
                                  Icons.lock,
                                  size: 12,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Name
                      Text(
                        achievement.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isUnlocked
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Progress or Description
                      if (!isUnlocked)
                        Text(
                          '$progress/${achievement.requiredValue}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                            fontSize: 10,
                          ),
                        )
                      else
                        const Icon(Icons.check_circle, size: 14, color: Colors.amber),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
