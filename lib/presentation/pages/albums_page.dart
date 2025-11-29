import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audio_x/data/models/song_model.dart';
import 'package:audio_x/presentation/controllers/audio_controller.dart';

class AlbumsPage extends StatefulWidget {
  const AlbumsPage({super.key});

  @override
  State<AlbumsPage> createState() => _AlbumsPageState();
}

class _AlbumsPageState extends State<AlbumsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Map<String, List<Song>> _groupByAlbums(List<Song> songs) {
    final albumsMap = <String, List<Song>>{};
    for (final song in songs) {
      final albumName = song.album.trim().isEmpty ? 'Unknown Album' : song.album;
      albumsMap.putIfAbsent(albumName, () => []).add(song);
    }
    return albumsMap;
  }

  List<MapEntry<String, List<Song>>> _filterAlbums(Map<String, List<Song>> albums) {
    final sortedAlbums = albums.entries.toList()..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));

    if (_searchQuery.isEmpty) {
      return sortedAlbums;
    }

    return sortedAlbums.where((entry) => entry.key.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  void _showAlbumSongs(BuildContext context, String albumName, List<Song> songs) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [Colors.blue.shade400, Colors.cyan.shade400]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.album_rounded, color: Colors.white, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            albumName,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${songs.length} ${songs.length == 1 ? 'song' : 'songs'}',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Songs List
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: songs.length,
                  itemBuilder: (context, index) {
                    final song = songs[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.shade50,
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(
                        song.title,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: Icon(Icons.play_circle_outline_rounded, color: Colors.blue.shade700),
                      onTap: () {
                        Provider.of<AudioController>(context, listen: false).playSong(song);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 140,
            floating: false,
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.blue.shade50, Colors.cyan.shade50],
                  ),
                ),
              ),
              titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.blue.shade600, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.album_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Albums',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ),

          // Search Bar
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search albums...',
                    hintStyle: TextStyle(color: Colors.grey.shade600),
                    prefixIcon: Icon(Icons.search_rounded, color: Colors.blue.shade600),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear_rounded, color: Colors.grey.shade600),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
            ),
          ),

          // Albums Grid
          Consumer<AudioController>(
            builder: (context, controller, child) {
              if (controller.songs.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.album_outlined, size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text('No Albums Found', style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                );
              }

              final albumsMap = _groupByAlbums(controller.songs);
              final albums = _filterAlbums(albumsMap);

              if (albums.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Text('No results found', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.85,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final album = albums[index];
                    return GestureDetector(
                      onTap: () => _showAlbumSongs(context, album.key, album.value),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Album Art
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [Colors.blue.shade400, Colors.cyan.shade400],
                                  ),
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                ),
                                child: const Center(child: Icon(Icons.album_rounded, color: Colors.white, size: 48)),
                              ),
                            ),
                            // Album Info
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    album.key,
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${album.value.length} ${album.value.length == 1 ? 'song' : 'songs'}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }, childCount: albums.length),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
