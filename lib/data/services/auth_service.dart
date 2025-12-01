import 'package:hive/hive.dart';
//import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  String _userName = 'Music Lover';
  String? _userPhotoUrl;

  String get userName => _userName;
  String? get userPhotoUrl => _userPhotoUrl;
  bool get isLoggedIn => true; // Mocking logged in state for now

  Future<void> updateUserName(String name) async {
    _userName = name;
    // In a real app, save to preferences or backend
  }

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

    if (includeUserName) {
      return '$greeting, $_userName';
    }
    return greeting;
  }
}
