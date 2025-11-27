import 'package:flutter/material.dart';
import '../../data/services/auth_service.dart';

class ProfilePage extends StatefulWidget {
  final String userName;
  final Function(String) onNameUpdate;

  const ProfilePage({super.key, required this.userName, required this.onNameUpdate});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    try {
      final userCredential = await _authService.signInWithGoogle();

      if (userCredential != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Welcome, ${_authService.userName}!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sign in failed. Please try again.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleSignOut() async {
    setState(() => _isLoading = true);

    try {
      await _authService.signOut();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Signed out successfully'), behavior: SnackBarBehavior.floating));
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sign out failed. Please try again.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = _authService.isLoggedIn;
    final userName = isLoggedIn ? _authService.userName : widget.userName;

    String greeting = _authService.getGreeting(includeUserName: false);
    if (userName.isNotEmpty && userName != 'Guest') {
      final firstName = userName.split(' ').first;
      greeting = '$greeting, $firstName';
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Profile & Settings',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Profile Header with Greeting
                  Center(
                    child: Column(
                      children: [
                        // Profile Picture
                        Stack(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.deepPurple.withOpacity(0.3),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: isLoggedIn && _authService.userPhotoUrl != null
                                  ? CircleAvatar(
                                      radius: 50,
                                      backgroundImage: NetworkImage(_authService.userPhotoUrl!),
                                      backgroundColor: Colors.grey[200],
                                    )
                                  : Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [Colors.deepPurple.shade400, Colors.purple.shade300],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                      child: const Icon(Icons.person_rounded, size: 50, color: Colors.white),
                                    ),
                            ),
                            if (isLoggedIn)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                                    child: const Icon(Icons.check, size: 12, color: Colors.white),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Personalized Greeting
                        Text(
                          greeting,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            foreground: Paint()
                              ..shader = LinearGradient(
                                colors: [Colors.deepPurple.shade600, Colors.purple.shade400],
                              ).createShader(const Rect.fromLTWH(0, 0, 300, 70)),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Email or Subtitle
                        Text(
                          isLoggedIn ? _authService.userEmail : 'Music Lover',
                          style: const TextStyle(color: Colors.grey, fontSize: 14),
                        ),

                        // Login Benefits Badge
                        if (isLoggedIn) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [Colors.deepPurple.shade400, Colors.purple.shade300]),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.deepPurple.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified_user, color: Colors.white, size: 16),
                                SizedBox(width: 6),
                                Text(
                                  'Premium Member',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Authentication Section
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 15),

                  if (!isLoggedIn) ...[
                    _buildAuthButton(
                      icon: Icons.g_mobiledata_rounded,
                      label: 'Sign in with Google',
                      color: Colors.red.shade50,
                      textColor: Colors.red.shade700,
                      onTap: _handleGoogleSignIn,
                    ),
                    const SizedBox(height: 12),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'We only use your name and photo for personalization. Your data is secure and never shared.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildBenefitsCard(),
                  ] else ...[
                    _buildAuthButton(
                      icon: Icons.logout_rounded,
                      label: 'Sign Out',
                      color: Colors.grey.shade100,
                      textColor: Colors.grey.shade700,
                      onTap: _handleSignOut,
                    ),
                    const SizedBox(height: 16),
                    _buildLoggedInBenefitsCard(),
                  ],

                  const SizedBox(height: 30),

                  // Settings Section
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 15),
                  _buildSettingTile(
                    icon: Icons.dark_mode_rounded,
                    title: 'Dark Mode',
                    subtitle: 'Switch to dark theme',
                    trailing: Switch(value: false, onChanged: (value) {}, activeThumbColor: Colors.deepPurple),
                  ),
                  _buildSettingTile(
                    icon: Icons.notifications_active_rounded,
                    title: 'Notifications',
                    subtitle: 'Get updates about new songs',
                    trailing: Switch(value: true, onChanged: (value) {}, activeThumbColor: Colors.deepPurple),
                  ),
                  _buildSettingTile(
                    icon: Icons.equalizer_rounded,
                    title: 'Audio Quality',
                    subtitle: 'High (320kbps)',
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
                  ),

                  const SizedBox(height: 30),

                  // About Developer Section
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('About', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(color: Colors.deepPurple.withOpacity(0.1), shape: BoxShape.circle),
                          child: const Icon(Icons.code_rounded, color: Colors.deepPurple),
                        ),
                        const SizedBox(width: 15),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Developed by', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            Text('Imdadur Rahman', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text('Version 1.0.0', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _buildAuthButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: textColor.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: textColor, size: 28),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepPurple.shade50, Colors.purple.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.deepPurple.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.star_rounded, color: Colors.deepPurple.shade600, size: 20),
              const SizedBox(width: 8),
              Text(
                'Benefits of Signing In',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepPurple.shade800),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildBenefitItem('Personalized greetings with your name'),
          _buildBenefitItem('Sync your preferences across devices'),
          _buildBenefitItem('Access to cloud playlists (coming soon)'),
          _buildBenefitItem('Premium features and updates'),
        ],
      ),
    );
  }

  Widget _buildLoggedInBenefitsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade50, Colors.teal.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.green.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'You\'re Enjoying Premium',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green.shade800),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildActiveBenefitItem('Personalized experience'),
          _buildActiveBenefitItem('Synced preferences'),
          _buildActiveBenefitItem('Priority support'),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, size: 16, color: Colors.deepPurple.shade400),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveBenefitItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 16, color: Colors.green.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: Colors.black87, size: 22),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
