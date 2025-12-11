import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../data/services/artist_service.dart';
import '../controllers/audio_controller.dart';
import '../controllers/theme_controller.dart';
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
            subtitle: context.watch<AudioController>().isSleepTimerActive
                ? 'Stops in ${_formatDuration(context.watch<AudioController>().sleepTimerRemaining)}'
                : 'Off',
            onTap: () => _showSleepTimerDialog(context),
          ),
          _buildSwitchTile(
            context,
            icon: Icons.speed,
            iconColor: Colors.blue,
            title: 'Crossfade',
            subtitle: 'Smooth transitions',
            value: context.watch<AudioController>().isCrossfadeEnabled,
            onChanged: (val) => context.read<AudioController>().setCrossfade(val),
          ),
          _buildSettingsTile(
            icon: Icons.equalizer,
            iconColor: Colors.purple,
            title: 'Equalizer Presets',
            subtitle: 'Adjust audio frequencies',
            onTap: () => context.push('/equalizer'),
          ),

          const SizedBox(height: 24),

          // Appearance Section
          _buildSectionHeader('Appearance'),
          _buildSettingsTile(
            icon: Icons.palette_outlined,
            iconColor: Colors.pink,
            title: 'Theme',
            subtitle: _getThemeName(context.watch<ThemeController>().themeMode),
            onTap: () => _showThemeDialog(context),
          ),
          if (context.watch<ThemeController>().themeMode == ThemeMode.dark)
            _buildSwitchTile(
              context,
              icon: Icons.brightness_2_outlined,
              iconColor: Colors.grey,
              title: 'OLED Mode',
              subtitle: 'Pure black background',
              value: context.watch<ThemeController>().isOledMode,
              onChanged: (val) => context.read<ThemeController>().toggleOledMode(val),
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
          _buildSettingsTile(
            icon: Icons.code,
            iconColor: Colors.grey,
            title: 'Developer',
            subtitle: 'Imdadur Rahman\ngithub.com/imdadur765',
            onTap: () {
              /* Open URL */
            },
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '';
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}m ${seconds}s';
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

  Widget _buildSwitchTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: Colors.grey.shade900, borderRadius: BorderRadius.circular(12)),
      child: SwitchListTile(
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: iconColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
        value: value,
        onChanged: onChanged,
        activeThumbColor: Colors.deepPurple,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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

  void _showSleepTimerDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Sleep Timer'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSleepTimerOption(context, 15),
              _buildSleepTimerOption(context, 30),
              _buildSleepTimerOption(context, 45),
              _buildSleepTimerOption(context, 60),
              ListTile(
                title: const Text('Turn Off Timer', style: TextStyle(color: Colors.red)),
                leading: const Icon(Icons.close, color: Colors.red),
                onTap: () {
                  context.read<AudioController>().cancelSleepTimer();
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSleepTimerOption(BuildContext context, int minutes) {
    return ListTile(
      title: Text('$minutes minutes'),
      leading: const Icon(Icons.timer),
      onTap: () {
        context.read<AudioController>().scheduleSleepTimer(Duration(minutes: minutes));
        Navigator.pop(context);
      },
    );
  }

  String _getThemeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System Default';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }

  void _showThemeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Theme'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildThemeOption(context, 'System Default', ThemeMode.system),
              _buildThemeOption(context, 'Light', ThemeMode.light),
              _buildThemeOption(context, 'Dark', ThemeMode.dark),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThemeOption(BuildContext context, String title, ThemeMode mode) {
    final currentMode = context.read<ThemeController>().themeMode;
    final isSelected = currentMode == mode;

    return ListTile(
      title: Text(title),
      leading: Radio<ThemeMode>(
        value: mode,
        groupValue: currentMode,
        onChanged: (val) {
          if (val != null) {
            context.read<ThemeController>().setThemeMode(val);
            Navigator.pop(context);
          }
        },
        activeColor: Colors.deepPurple,
      ),
      onTap: () {
        context.read<ThemeController>().setThemeMode(mode);
        Navigator.pop(context);
      },
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
