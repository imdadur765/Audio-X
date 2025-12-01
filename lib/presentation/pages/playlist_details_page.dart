import 'package:flutter/material.dart';
import '../../data/models/song_model.dart';
import '../pages/player_page.dart';

class PlaylistDetailsPage extends StatelessWidget {
  final String title;
  final List<Song> songs;
  final List<Color> gradientColors;

  const PlaylistDetailsPage({super.key, required this.title, required this.songs, required this.gradientColors});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), backgroundColor: gradientColors.first),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [gradientColors.first.withOpacity(0.3), Colors.white],
          ),
        ),
        child: ListView.builder(
          itemCount: songs.length,
          itemBuilder: (context, index) {
            final song = songs[index];
            return ListTile(
              leading: const Icon(Icons.music_note),
              title: Text(song.title),
              subtitle: Text(song.artist),
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (context) => PlayerPage(song: song)));
              },
            );
          },
        ),
      ),
    );
  }
}
