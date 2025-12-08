import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../data/models/artist_model.dart';
import '../../data/services/artist_service.dart';
import 'dart:ui';
import '../widgets/glass_background.dart';
import '../controllers/audio_controller.dart';

enum SortOrder { aToZ, zToA }

enum ViewMode { grid, list }

class ArtistsListPage extends StatefulWidget {
  const ArtistsListPage({super.key});

  @override
  State<ArtistsListPage> createState() => _ArtistsListPageState();
}

class _ArtistsListPageState extends State<ArtistsListPage> {
  final ArtistService _artistService = ArtistService();
  final Map<String, Future<Artist?>> _artistFutures = {};
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  SortOrder _sortOrder = SortOrder.aToZ;
  ViewMode _viewMode = ViewMode.grid;
  ConnectivityResult _connectivityResult = ConnectivityResult.none;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  double _scrollOffset = 0;
  double _lastScrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _initConnectivity();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(_updateConnectionStatus);
    _scrollController.addListener(_onScroll);

    // Pre-load artist data in batches for faster rendering
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadArtistData();
    });
  }

  void _onScroll() {
    // Throttle scroll updates - only update if difference > 10 pixels
    final currentOffset = _scrollController.offset;
    if ((currentOffset - _lastScrollOffset).abs() > 10) {
      setState(() {
        _scrollOffset = currentOffset;
        _lastScrollOffset = currentOffset;
      });
    }
  }

  Future<void> _initConnectivity() async {
    try {
      final results = await Connectivity().checkConnectivity();
      if (results.isNotEmpty) {
        _updateConnectionStatus(results);
      }
    } catch (e) {
      setState(() {
        _connectivityResult = ConnectivityResult.none;
      });
    }
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    if (results.isNotEmpty) {
      setState(() {
        _connectivityResult = results.first;
      });
    }
  }

  bool get _isOnline => _connectivityResult != ConnectivityResult.none;

  Future<void> _preloadArtistData() async {
    final controller = Provider.of<AudioController>(context, listen: false);
    final allArtists = controller.songs.map((s) => s.artist).toSet().toList();

    const batchSize = 25; // Adjusted to 25 to balance speed and reliability (prevent 429s)

    for (int i = 0; i < allArtists.length; i += batchSize) {
      final batch = allArtists.skip(i).take(batchSize).toList();

      // Load batch in parallel
      await Future.wait(
        batch.map((artistName) {
          if (!_artistFutures.containsKey(artistName)) {
            _artistFutures[artistName] = _artistService.getArtistInfo(artistName);
          }
          return _artistFutures[artistName]!;
        }),
        eagerError: false,
      ).timeout(Duration(seconds: 30), onTimeout: () => []);

      // Update UI after each batch
      if (mounted) {
        setState(() {});
      }

      // Removed delay to maximize throughput
      // await Future.delayed(Duration(milliseconds: 100));
    }
  }

  @override
  void dispose() {
    _artistFutures.clear();
    _scrollController.dispose();
    _searchController.dispose();
    _connectivitySubscription.cancel();
    super.dispose();
  }

  List<String> _getSortedAndFilteredArtists(List<String> artists) {
    var filtered = artists;

    // Filter by search query
    if (_searchController.text.isNotEmpty) {
      filtered = artists
          .where((artist) => artist.toLowerCase().contains(_searchController.text.toLowerCase()))
          .toList();
    }

    // Sort
    if (_sortOrder == SortOrder.aToZ) {
      filtered.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    } else {
      filtered.sort((a, b) => b.toLowerCase().compareTo(a.toLowerCase()));
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<AudioController>(context);
    final allArtists = controller.songs.map((s) => s.artist).toSet().toList();
    final artists = _getSortedAndFilteredArtists(allArtists);

    final currentSong = controller.currentSong;

    return Stack(
      children: [
        GlassBackground(artworkPath: currentSong?.localArtworkPath),

        Scaffold(
          backgroundColor: Colors.transparent,
          body: CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              _buildHeader(),
              if (artists.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Text(_searchController.text.isNotEmpty ? "No artists found" : "No artists available"),
                  ),
                )
              else if (_viewMode == ViewMode.grid)
                _buildGridView(artists)
              else
                _buildListView(artists),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    final opacity = (_scrollOffset / 100).clamp(0.0, 1.0);

    return SliverAppBar(
      expandedHeight: 220,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      actions: [
        // View toggle buttons - in app bar
        Container(
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Consumer<AudioController>(
            builder: (context, controller, child) {
              return Row(
                children: [
                  _buildViewButton(
                    imagePath: 'assets/images/girdview.png',
                    isSelected: _viewMode == ViewMode.grid,
                    onTap: () => setState(() => _viewMode = ViewMode.grid),
                    isCompact: false,
                    accentColor: controller.accentColor,
                  ),
                  _buildViewButton(
                    imagePath: 'assets/images/listview.png',
                    isSelected: _viewMode == ViewMode.list,
                    onTap: () => setState(() => _viewMode = ViewMode.list),
                    isCompact: false,
                    accentColor: controller.accentColor,
                  ),
                ],
              );
            },
          ),
        ),
        // Sort button
        PopupMenuButton<SortOrder>(
          icon: Consumer<AudioController>(
            builder: (context, controller, _) {
              return Image.asset(
                'assets/images/sort.png',
                width: 24,
                height: 24,
                color: controller.accentColor, // Dynamic color
              );
            },
          ),
          onSelected: (order) {
            setState(() {
              _sortOrder = order;
            });
          },
          offset: const Offset(0, 40),
          itemBuilder: (context) => [
            const PopupMenuItem(value: SortOrder.aToZ, child: Text('A to Z')),
            const PopupMenuItem(value: SortOrder.zToA, child: Text('Z to A')),
          ],
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        title: AnimatedOpacity(
          opacity: opacity,
          duration: const Duration(milliseconds: 200),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Artists',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(width: 8),
              _buildConnectivityBadge(compact: true),
            ],
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.2), // Base dark glass
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Image.asset(
                              'assets/images/artist_open.png',
                              width: 28,
                              height: 28,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Text(
                            'Artists',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              shadows: [Shadow(offset: Offset(0, 2), blurRadius: 8, color: Colors.black26)],
                            ),
                          ),
                          const SizedBox(width: 12),
                          _buildConnectivityBadge(compact: false),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text('Your music collection', style: TextStyle(color: Colors.white70, fontSize: 16)),
                      const SizedBox(height: 16),
                      // Search bar in gradient
                      Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(fontSize: 15, color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Search artists...',
                            hintStyle: const TextStyle(color: Colors.white60),
                            prefixIcon: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Image.asset(
                                'assets/images/search.png',
                                width: 20,
                                height: 20,
                                color: Colors.white70,
                              ),
                            ),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                                    onPressed: () {
                                      setState(() {
                                        _searchController.clear();
                                      });
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          ),
                          onChanged: (value) {
                            setState(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectivityBadge({required bool compact}) {
    if (compact) {
      return Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: _isOnline ? Colors.greenAccent : Colors.redAccent, shape: BoxShape.circle),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: _isOnline ? Colors.greenAccent : Colors.redAccent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            _isOnline ? 'Online' : 'Offline',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildViewButton({
    required String imagePath,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isCompact,
    required Color accentColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withOpacity(0.3) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Image.asset(imagePath, width: 20, height: 20, color: isSelected ? accentColor : Colors.white60),
      ),
    );
  }

  Widget _buildGridView(List<String> artists) {
    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.85,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final artistName = artists[index];
            // Future is pre-loaded in _preloadArtistData, just use it
            return RepaintBoundary(key: ValueKey('artist_$artistName'), child: _buildArtistCard(artistName));
          },
          childCount: artists.length,
          addAutomaticKeepAlives: true,
        ),
      ),
    );
  }

  Widget _buildListView(List<String> artists) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final artistName = artists[index];
            // Future is pre-loaded in _preloadArtistData, just use it
            return RepaintBoundary(key: ValueKey('artist_list_$artistName'), child: _buildArtistListTile(artistName));
          },
          childCount: artists.length,
          addAutomaticKeepAlives: true,
        ),
      ),
    );
  }

  Widget _buildArtistCard(String artistName) {
    // Lazy load if not already loading (Fix for missing shimmer)
    if (!_artistFutures.containsKey(artistName)) {
      _artistFutures[artistName] = _artistService.getArtistInfo(artistName);
    }

    return FutureBuilder<Artist?>(
      future: _artistFutures[artistName],
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final artist = snapshot.data;
        final imageUrl = artist?.imageUrl;

        if (isLoading) {
          return _buildShimmerCard();
        }

        return GestureDetector(
          onTap: () async {
            await context.pushNamed(
              'artist_details',
              pathParameters: {'name': artistName},
              extra: 'artist_list_$artistName',
            );
            // Refresh artist data when returning (in case image was loaded in details page)
            if (mounted) {
              setState(() {
                _artistFutures.remove(artistName);
              });
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2), // Glass style
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (imageUrl != null && imageUrl.isNotEmpty)
                    Hero(
                      tag: 'artist_list_$artistName',
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlaceholderBackground(),
                      ),
                    )
                  else
                    _buildPlaceholderBackground(),

                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withOpacity(0.2), Colors.black.withOpacity(0.8)],
                        stops: const [0.5, 0.7, 1.0],
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          artistName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            shadows: [Shadow(color: Colors.black45, offset: Offset(0, 1), blurRadius: 2)],
                          ),
                        ),
                        if (artist?.tags.isNotEmpty == true) ...[
                          const SizedBox(height: 4),
                          Text(
                            artist!.tags.first,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildArtistListTile(String artistName) {
    // Lazy load if not already loading (Fix for missing shimmer)
    if (!_artistFutures.containsKey(artistName)) {
      _artistFutures[artistName] = _artistService.getArtistInfo(artistName);
    }

    return FutureBuilder<Artist?>(
      future: _artistFutures[artistName],
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final artist = snapshot.data;
        final imageUrl = artist?.imageUrl;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.2), // Glass style
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            leading: Hero(
              tag: 'artist_list_$artistName',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlaceholderAvatar(),
                      )
                    : _buildPlaceholderAvatar(),
              ),
            ),
            title: Text(artistName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            subtitle: artist?.tags.isNotEmpty == true
                ? Text(
                    artist!.tags.take(2).join(", "),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  )
                : Text(
                    isLoading ? "Loading..." : "Unknown Genre",
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
            trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
            onTap: () async {
              await context.pushNamed(
                'artist_details',
                pathParameters: {'name': artistName},
                extra: 'artist_list_$artistName',
              );
              // Refresh artist data when returning
              if (mounted) {
                setState(() {
                  _artistFutures.remove(artistName);
                });
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildPlaceholderAvatar() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.deepPurple.shade200, Colors.pink.shade300],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Image.asset('assets/images/artist_open.png', width: 28, height: 28, color: Colors.white54),
    );
  }

  Widget _buildShimmerCard() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  Widget _buildPlaceholderBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.deepPurple.shade300, Colors.pink.shade400],
        ),
      ),
      child: Center(child: Image.asset('assets/images/artist_open.png', width: 40, height: 40, color: Colors.white54)),
    );
  }
}
