import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../controllers/audio_controller.dart';

class AlbumInfoPage extends StatefulWidget {
  final String albumName;
  final String artistName;
  final Widget? albumArt;

  const AlbumInfoPage({super.key, required this.albumName, required this.artistName, this.albumArt});

  @override
  State<AlbumInfoPage> createState() => _AlbumInfoPageState();
}

class _AlbumInfoPageState extends State<AlbumInfoPage> {
  Future<Map<String, dynamic>?>? _albumInfoFuture;

  @override
  void initState() {
    super.initState();
    _loadAlbumInfo();
  }

  void _loadAlbumInfo() {
    final controller = Provider.of<AudioController>(context, listen: false);
    _albumInfoFuture = controller.getAlbumInfo(widget.albumName, widget.artistName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background with blur
          if (widget.albumArt != null) Positioned.fill(child: widget.albumArt!),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(color: Colors.white.withOpacity(0.6)),
            ),
          ),

          // Content
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: FutureBuilder<Map<String, dynamic>?>(
                    future: _albumInfoFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: Colors.deepPurple));
                      }

                      if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
                        return _buildErrorState();
                      }

                      return _buildInfoContent(snapshot.data!);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.5)),
              ),
              child: Center(
                child: Image.asset('assets/images/back.png', width: 20, height: 20, color: Colors.deepPurple),
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Text(
            'Album Info',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoContent(Map<String, dynamic> data) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Album Art & Title
          Center(
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.deepPurple.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: widget.albumArt ?? Container(color: Colors.deepPurple.shade100),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              data['collectionName'] ?? widget.albumName,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              data['artistName'] ?? widget.artistName,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.deepPurple.shade700),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),

          // Info Grid
          _buildInfoGrid(data),

          const SizedBox(height: 24),

          // Copyright
          if (data['copyright'] != null)
            Text(
              data['copyright'],
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),

          const SizedBox(height: 32),

          // iTunes Button
          if (data['collectionViewUrl'] != null)
            Center(
              child: GestureDetector(
                onTap: () => _launchUrl(data['collectionViewUrl']),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Colors.deepPurple.shade600, Colors.purple.shade600]),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(color: Colors.deepPurple.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/images/itunes_logo.png', width: 24, height: 24, color: Colors.white),
                      const SizedBox(width: 12),
                      const Text(
                        'View on iTunes',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoGrid(Map<String, dynamic> data) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.6, // Even taller to fix 2px overflow
      children: [
        _buildInfoTile('Genre', data['primaryGenreName'] ?? 'Unknown'),
        _buildInfoTile('Year', (data['releaseDate'] as String?)?.substring(0, 4) ?? 'Unknown'),
        _buildInfoTile('Track Count', '${data['trackCount'] ?? 0} Songs'),
        _buildInfoTile('Price', '${data['collectionPrice'] ?? '-'} ${data['currency'] ?? ''}'),
      ],
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.deepPurple.shade400, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, size: 60, color: Colors.deepPurple.shade200),
          const SizedBox(height: 16),
          Text(
            'Could not load album info',
            style: TextStyle(fontSize: 18, color: Colors.deepPurple.shade700, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text('Please check your internet connection', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String urlString) async {
    final url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}
