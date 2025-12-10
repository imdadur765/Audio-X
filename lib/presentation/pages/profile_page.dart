import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../../data/services/auth_service.dart';
import '../../services/cloud_sync_service.dart';
import '../../services/playlist_service.dart';
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
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;

  @override
  void initState() {
    super.initState();
    _loadLastSyncTime();
    _scrollController.addListener(() => setState(() {}));
    CloudSyncService.lastSyncNotifier.addListener(_onSyncUpdate);
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
                  icon: Image.asset('assets/images/back.png', width: 24, height: 24, color: Colors.white),
                  onPressed: () => context.pop(),
                ),
                title: const Text(
                  'Profile',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.settings_outlined, color: Colors.white),
                    onPressed: () => context.push('/settings'),
                  ),
                ],
                flexibleSpace: ClipRRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: isScrolled ? 20 : 0, sigmaY: isScrolled ? 20 : 0),
                    child: Container(color: Colors.transparent),
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
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }

  Widget _buildProfileCard(bool isLoggedIn, String? photoUrl) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
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
                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 3),
                  boxShadow: [BoxShadow(color: Colors.deepPurple.withOpacity(0.3), blurRadius: 20, spreadRadius: 2)],
                ),
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey.shade800,
                  backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                  child: photoUrl == null
                      ? Image.asset('assets/images/profile.png', width: 50, height: 50, color: Colors.white54)
                      : null,
                ),
              ),
              if (isLoggedIn)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                  child: const Icon(Icons.check, size: 14, color: Colors.white),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Name
          Text(
            _authService.userName,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          if (isLoggedIn && _authService.currentUser?.email != null)
            Text(_authService.currentUser!.email!, style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatItem('assets/images/most_played.png', '$totalPlays', 'Songs Played', Colors.pink),
              ),
              Container(width: 1, height: 50, color: Colors.white.withOpacity(0.1)),
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
          Container(height: 1, color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildStatItem('assets/images/song.png', '$totalSongs', 'Total Songs', Colors.blue)),
              Container(width: 1, height: 50, color: Colors.white.withOpacity(0.1)),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
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
                const Text(
                  'Favorites & Playlists',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                ),
                Text('Last synced: ${_getLastSyncText()}', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
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
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
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
              const Text(
                'Sign in with Google',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
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
              Icon(Icons.logout, color: Colors.red.shade400, size: 22),
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
}
