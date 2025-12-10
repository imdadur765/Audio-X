import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/services/artist_service.dart';
import '../../data/services/auth_service.dart';
import 'package:hive/hive.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late TextEditingController _nameController;
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: _authService.userName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    final user = await _authService.signInWithGoogle();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (user != null) {
          _nameController.text = user.displayName ?? 'Music Lover';
        }
      });
      if (user != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Welcome, ${user.displayName}!')));
      }
    }
  }

  Future<void> _handleSignOut() async {
    setState(() => _isLoading = true);
    await _authService.signOut();
    if (mounted) {
      setState(() {
        _isLoading = false;
        _nameController.text = 'Music Lover';
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signed out successfully')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = _authService.isLoggedIn;
    final photoUrl = _authService.userPhotoUrl;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        leading: IconButton(
          icon: Image.asset('assets/images/back.png', width: 24, height: 24),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Profile Avatar
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey[800],
                  backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                  child: photoUrl == null ? const Icon(Icons.person, size: 50, color: Colors.white54) : null,
                ),
                if (isLoggedIn)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                    child: const Icon(Icons.check, size: 16, color: Colors.white),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // User Name / Email
            Text(_authService.userName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            if (isLoggedIn && _authService.currentUser?.email != null)
              Text(_authService.currentUser!.email!, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
            const SizedBox(height: 20),

            // Google Sign-In / Sign-Out Button
            if (_isLoading)
              const CircularProgressIndicator()
            else if (!isLoggedIn)
              _buildSignInButton()
            else
              _buildSignOutButton(),

            const SizedBox(height: 30),

            // Name Edit Section (only if logged in)
            if (isLoggedIn) ...[
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Display Name',
                  border: OutlineInputBorder(),
                  hintText: 'Enter your name',
                ),
              ),
              const SizedBox(height: 20),
            ],

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

            const SizedBox(height: 30),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  if (isLoggedIn) {
                    await _authService.updateUserName(_nameController.text);
                  }
                  // Return the name to the caller via go_router pop
                  if (mounted) context.pop(_nameController.text);
                },
                child: const Text('Save Profile', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignInButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.grey),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: Image.asset(
          'assets/images/google_logo.png', // Add this asset
          width: 24,
          height: 24,
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.account_circle, size: 24),
        ),
        label: const Text('Sign in with Google', style: TextStyle(fontSize: 16)),
        onPressed: _handleGoogleSignIn,
      ),
    );
  }

  Widget _buildSignOutButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.red.shade300),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: Icon(Icons.logout, color: Colors.red.shade600),
        label: Text('Sign Out', style: TextStyle(fontSize: 16, color: Colors.red.shade600)),
        onPressed: _handleSignOut,
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
