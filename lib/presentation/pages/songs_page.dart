import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audio_x/data/models/song_model.dart';
import 'package:audio_x/presentation/controllers/audio_controller.dart';

class SongsPage extends StatefulWidget {
  const SongsPage({super.key});

  @override
  State<SongsPage> createState() => _SongsPageState();
}

class _SongsPageState extends State<SongsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _sortMode = 0; // 0: A-Z, 1: Recent, 2: Most Played

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Song> _filterAndSortSongs(List<Song> songs) {
    var filteredSongs = songs.where((song) {
      if (_searchQuery.isEmpty) return true;
      return song.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          song.artist.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    switch (_sortMode) {
      case 0: // A-Z
        filteredSongs.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case 1: // Recent (reversed list)
        filteredSongs = filteredSongs.reversed.toList();
        break;
      case 2: // Most Played (would need play count data)
        // For now, just use A-Z
        filteredSongs.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
    }

    return filteredSongs;
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
                    colors: [Colors.purple.shade50, Colors.pink.shade50],
                  ),
                ),
              ),
              titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.deepPurple, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Songs',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ),

          // Search & Sort Bar
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  // Search Field
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search songs...',
                          hintStyle: TextStyle(color: Colors.grey.shade600),
                          prefixIcon: Icon(Icons.search_rounded, color: Colors.deepPurple),
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
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
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
                  const SizedBox(width: 12),
                  // Sort Button
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: PopupMenuButton<int>(
                      icon: Icon(Icons.sort_rounded, color: Colors.deepPurple),
                      onSelected: (value) {
                        setState(() {
                          _sortMode = value;
                        });
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(value: 0, child: Text('A-Z')),
                        PopupMenuItem(value: 1, child: Text('Recently Added')),
                        PopupMenuItem(value: 2, child: Text('Most Played')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Songs List
          Consumer<AudioController>(
            builder: (context, controller, child) {
              if (controller.songs.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.music_off_rounded, size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text('No Songs Found', style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                );
              }

              final songs = _filterAndSortSongs(controller.songs);

              if (songs.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Text('No results found', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final song = songs[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [Colors.purple.shade400, Colors.pink.shade400]),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.music_note_rounded, color: Colors.white),
                        ),
                        title: Text(
                          song.title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: Icon(Icons.play_circle_outline_rounded, color: Colors.deepPurple),
                        onTap: () {
                          controller.playSong(song);
                        },
                      ),
                    );
                  }, childCount: songs.length),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
