import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Returns the current logged-in Firebase user, or null if not logged in.
  User? get currentUser => _firebaseAuth.currentUser;

  /// Stream that emits when the auth state changes (login/logout).
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  /// Returns the user's display name from Firebase or a default.
  String get userName => currentUser?.displayName ?? 'Music Lover';

  /// Returns the user's photo URL from Google account.
  String? get userPhotoUrl => currentUser?.photoURL;

  /// Returns true if a user is logged in via Firebase.
  bool get isLoggedIn => currentUser != null;

  /// Signs in the user with their Google account.
  /// Returns the [User] on success, or null on failure/cancellation.
  Future<User?> signInWithGoogle() async {
    try {
      // Trigger the Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User cancelled the sign-in
        debugPrint('Google Sign-In cancelled by user.');
        return null;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final UserCredential userCredential = await _firebaseAuth.signInWithCredential(credential);

      debugPrint('Signed in as: ${userCredential.user?.displayName}');
      return userCredential.user;
    } catch (e) {
      debugPrint('Error during Google Sign-In: $e');
      return null;
    }
  }

  /// Signs out the current user from both Firebase and Google.
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _firebaseAuth.signOut();
      debugPrint('User signed out.');
    } catch (e) {
      debugPrint('Error during sign out: $e');
    }
  }

  /// Updates the user's display name in Firebase Auth profile.
  Future<void> updateUserName(String name) async {
    if (currentUser != null) {
      await currentUser!.updateDisplayName(name);
      await currentUser!.reload();
    }
  }

  /// Returns a time-based greeting with optional user name.
  String getGreeting({bool includeUserName = true}) {
    final hour = DateTime.now().hour;
    String greeting;

    if (hour < 12) {
      greeting = 'Good Morning';
    } else if (hour < 17) {
      greeting = 'Good Afternoon';
    } else {
      greeting = 'Good Evening';
    }

    if (includeUserName && isLoggedIn) {
      return '$greeting, ${userName.split(' ').first}'; // Use first name only
    }
    return greeting;
  }
}
