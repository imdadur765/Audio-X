import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class DeveloperPage extends StatelessWidget {
  const DeveloperPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Developer'),
        leading: IconButton(
          icon: Image.asset('assets/images/back.png', width: 24, height: 24),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Profile Picture
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.deepPurple, width: 3),
                boxShadow: [BoxShadow(color: Colors.deepPurple.withOpacity(0.4), blurRadius: 20, spreadRadius: 5)],
                image: const DecorationImage(
                  image: NetworkImage('https://github.com/imdadur765.png'), // User's GitHub avatar
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Name
            const Text('Imdadur Rahman', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            // Title
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.deepPurple.withOpacity(0.3)),
              ),
              child: const Text(
                'Flutter Developer',
                style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.w600),
              ),
            ),

            const SizedBox(height: 32),

            // Bio
            Text(
              'Passionate about building beautiful, high-performance mobile applications. Audio X is my latest project, aiming to provide the best offline music experience with a modern design.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade400, height: 1.5),
            ),

            const SizedBox(height: 40),

            // Social Links
            _buildSocialButton(
              context,
              'GitHub',
              'Check out my open source projects',
              'https://github.com/imdadur765',
              Icons.code,
              Colors.black, // GitHub color (or white on dark)
            ),
            const SizedBox(height: 16),
            _buildSocialButton(
              context,
              'Audio X Source Code',
              'Star the repo if you like it!',
              'https://github.com/imdadur765/Audio-X', // Assuming repo name
              Icons.star_outline,
              Colors.orange,
            ),
            const SizedBox(height: 16),
            _buildSocialButton(
              context,
              'Email Me',
              'For work or feedback',
              'mailto:imdadurrahman488@gmail.com',
              Icons.email_outlined,
              Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialButton(
    BuildContext context,
    String title,
    String subtitle,
    String url,
    IconData icon,
    Color color,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          final uri = Uri.parse(url);
          if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
            debugPrint('Could not launch $url');
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color == Colors.black ? Colors.white : color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
