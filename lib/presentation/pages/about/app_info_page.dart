import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppInfoPage extends StatelessWidget {
  const AppInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Info'),
        leading: IconButton(
          icon: Image.asset('assets/images/back.png', width: 24, height: 24),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Header
          Center(
            child: Column(
              children: [
                Image.asset(
                  'assets/images/app_logo.png',
                  width: 80,
                  height: 80,
                  errorBuilder: (_, __, ___) => const Icon(Icons.music_note, size: 80, color: Colors.deepPurple),
                ),
                const SizedBox(height: 16),
                const Text('Audio X', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const Text('Version 1.0.0', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),

          const SizedBox(height: 40),

          _buildSectionTitle('Key Features'),
          const SizedBox(height: 16),
          _buildFeatureItem(Icons.wifi_off, 'Offline First', 'Play your local music library without internet.'),
          _buildFeatureItem(Icons.lyrics, 'Synchronized Lyrics', 'View real-time lyrics that scroll with the music.'),
          _buildFeatureItem(
            Icons.graphic_eq,
            'Audio Enhancements',
            'Customizable Equalizer, Bass Boost, and Virtualizer.',
          ),
          _buildFeatureItem(Icons.backup, 'Backup & Restore', 'Keep your favorites and settings safe.'),
          _buildFeatureItem(Icons.palette, 'Adaptive UI', 'Beautiful glassmorphism design that adapts to your theme.'),

          const SizedBox(height: 32),

          _buildSectionTitle('Tech Stack'),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildTechChip('Flutter'),
              _buildTechChip('Dart'),
              _buildTechChip('Hive DB'),
              _buildTechChip('Provider'),
              _buildTechChip('Go Router'),
              _buildTechChip('Firebase'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepPurple),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.deepPurple, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                const SizedBox(height: 4),
                Text(description, style: TextStyle(color: Colors.grey.shade400, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTechChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade700),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
    );
  }
}
