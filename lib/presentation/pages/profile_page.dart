import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/services/artist_service.dart';
import '../../data/services/itunes_service.dart';
import 'package:hive/hive.dart';

class ProfilePage extends StatefulWidget {
  final String userName;
  final Function(String) onNameUpdate;

  const ProfilePage({super.key, required this.userName, required this.onNameUpdate});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.userName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        leading: IconButton(
          icon: Image.asset('assets/images/back.png', width: 24, height: 24),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const CircleAvatar(radius: 50, child: Icon(Icons.person, size: 50)),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Your Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 30),

            // Settings Section
            const SizedBox(
              width: double.infinity,
              child: Text('Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 10),

            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.delete_outline, color: Colors.red.shade600),
              ),
              title: const Text('Clear Metadata Cache'),
              subtitle: const Text('Fix missing images or incorrect info'),
              onTap: _showClearCacheDialog,
              trailing: const Icon(Icons.chevron_right),
              contentPadding: EdgeInsets.zero,
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  widget.onNameUpdate(_nameController.text);
                  Navigator.pop(context);
                },
                child: const Text('Save Profile', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showClearCacheDialog() {
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
              await _performClearCache();
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _performClearCache() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      // Clear Artists Cache
      final artistService = ArtistService();
      await artistService.clearCache();

      // Clear iTunes/Album Cache (Optional, manual box opening)
      if (Hive.isBoxOpen('album_info_cache')) {
        await Hive.box('album_info_cache').clear();
      }

      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Cache cleared successfully! Restart app to refresh.')),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error clearing cache: $e')));
    }
  }
}
