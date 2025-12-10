import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/services/artist_service.dart';
import 'package:hive/hive.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: Image.asset('assets/images/back.png', width: 24, height: 24),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Playback Section
          _buildSectionHeader('Playback'),
          _buildSettingsTile(
            icon: Icons.timer_outlined,
            iconColor: Colors.orange,
            title: 'Sleep Timer',
            subtitle: 'Coming Soon',
            isComingSoon: true,
          ),
          _buildSettingsTile(
            icon: Icons.speed,
            iconColor: Colors.blue,
            title: 'Crossfade',
            subtitle: 'Coming Soon',
            isComingSoon: true,
          ),
          _buildSettingsTile(
            icon: Icons.equalizer,
            iconColor: Colors.purple,
            title: 'Equalizer Presets',
            subtitle: 'Coming Soon',
            isComingSoon: true,
          ),

          const SizedBox(height: 24),

          // Appearance Section
          _buildSectionHeader('Appearance'),
          _buildSettingsTile(
            icon: Icons.palette_outlined,
            iconColor: Colors.pink,
            title: 'Theme',
            subtitle: 'Coming Soon',
            isComingSoon: true,
          ),
          _buildSettingsTile(
            icon: Icons.text_fields,
            iconColor: Colors.teal,
            title: 'Font Size',
            subtitle: 'Coming Soon',
            isComingSoon: true,
          ),

          const SizedBox(height: 24),

          // Data Section
          _buildSectionHeader('Data & Storage'),
          _buildSettingsTile(
            icon: Icons.delete_outline,
            iconColor: Colors.red,
            title: 'Clear Metadata Cache',
            subtitle: 'Fix missing images or incorrect info',
            onTap: () => _showClearCacheDialog(context),
          ),
          _buildSettingsTile(
            icon: Icons.backup_outlined,
            iconColor: Colors.green,
            title: 'Backup & Restore',
            subtitle: 'Coming Soon',
            isComingSoon: true,
          ),

          const SizedBox(height: 24),

          // About Section
          _buildSectionHeader('About'),
          _buildSettingsTile(
            icon: Icons.info_outline,
            iconColor: Colors.blueGrey,
            title: 'App Version',
            subtitle: '1.0.0',
          ),
          _buildSettingsTile(icon: Icons.code, iconColor: Colors.grey, title: 'Developer', subtitle: 'Imdadur Rahman'),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    bool isComingSoon = false,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: Colors.grey.shade900, borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: iconColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Row(
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
            if (isComingSoon) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Soon',
                  style: TextStyle(fontSize: 10, color: Colors.deepPurple, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
        trailing: isComingSoon ? null : const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: isComingSoon ? null : onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text(
          'This will delete all downloaded artist images and details. They will be fetched again when you view them.\n\nUseful if you see missing images.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performClearCache(context);
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _performClearCache(BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final artistService = ArtistService();
      await artistService.clearCache();

      if (Hive.isBoxOpen('album_info_cache')) {
        await Hive.box('album_info_cache').clear();
      }

      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Cache cleared successfully!')));
    } catch (e) {
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}
