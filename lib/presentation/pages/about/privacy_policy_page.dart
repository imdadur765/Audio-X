import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        leading: IconButton(
          icon: Image.asset('assets/images/back.png', width: 24, height: 24),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionTitle('Privacy Policy'),
          _buildParagraph(
            'Your privacy is important to us. It is Audio X\'s policy to respect your privacy regarding any information we may collect from you across our application, Audio X.',
          ),

          _buildSectionTitle('Information We Collect'),
          _buildParagraph(
            'Audio X is primarily an offline music player. We do not collect, store, or share any personal data on our servers. All your music files and preferences are stored locally on your device.',
          ),

          _buildSectionTitle('Permissions'),
          _buildPermissionItem(
            'Storage / Photos & Media',
            'Required to access and play music files stored on your device. We only read audio files and related metadata (images for album art).',
          ),
          _buildPermissionItem(
            'Internet',
            'Used to fetch artist metadata (images, biographies) and lyrics from third-party APIs (like Last.fm). No personal user data is sent with these requests.',
          ),

          _buildSectionTitle('Open Source Libraries'),
          _buildParagraph(
            'Audio X uses the following open source libraries. We are grateful to the developers and contributors of these projects:',
          ),
          const SizedBox(height: 8),
          _buildLibraryItem('Flutter', 'Google', 'https://flutter.dev'),
          _buildLibraryItem('Provider', 'Remi Rousselet', 'https://pub.dev/packages/provider'),
          _buildLibraryItem('Go Router', 'Flutter Team', 'https://pub.dev/packages/go_router'),
          _buildLibraryItem('Hive', 'Simon Leier', 'https://pub.dev/packages/hive'),
          _buildLibraryItem('Url Launcher', 'Flutter Team', 'https://pub.dev/packages/url_launcher'),
          _buildLibraryItem('Cached Network Image', 'Rene Floor', 'https://pub.dev/packages/cached_network_image'),
          _buildLibraryItem('Just Audio', 'Ryan Heise', 'https://pub.dev/packages/just_audio'),
          _buildLibraryItem('Audio Service', 'Ryan Heise', 'https://pub.dev/packages/audio_service'),
          _buildLibraryItem('Palette Generator', 'Flutter Team', 'https://pub.dev/packages/palette_generator'),
          _buildLibraryItem('Permission Handler', 'Baseflow', 'https://pub.dev/packages/permission_handler'),
          _buildLibraryItem('Path Provider', 'Flutter Team', 'https://pub.dev/packages/path_provider'),
          _buildLibraryItem('Share Plus', 'Flutter Community', 'https://pub.dev/packages/share_plus'),
          _buildLibraryItem('File Picker', 'Miguel Ruivo', 'https://pub.dev/packages/file_picker'),
          _buildLibraryItem('Firebase Core', 'Firebase Team', 'https://pub.dev/packages/firebase_core'),

          const SizedBox(height: 24),
          _buildSectionTitle('Contact Us'),
          _buildParagraph(
            'If you have any questions or suggestions about our Privacy Policy, do not hesitate to contact us.',
          ),
          Center(
            child: TextButton(
              onPressed: () async {
                final Uri emailLaunchUri = Uri(
                  scheme: 'mailto',
                  path: 'imdadurrahman488@gmail.com',
                  query: 'subject=Audio X Privacy Policy',
                );
                if (!await launchUrl(emailLaunchUri)) {
                  debugPrint('Could not launch email');
                }
              },
              child: const Text('imdadurrahman488@gmail.com'),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple),
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: TextStyle(fontSize: 16, color: Colors.grey.shade300, height: 1.5)),
    );
  }

  Widget _buildPermissionItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 4),
          Text(description, style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildLibraryItem(String name, String author, String url) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.code, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
                Text('by $author', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new, size: 18, color: Colors.deepPurple),
            onPressed: () async {
              final uri = Uri.parse(url);
              if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                debugPrint('Could not launch $url');
              }
            },
          ),
        ],
      ),
    );
  }
}
