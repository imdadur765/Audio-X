import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class ThemeController extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark; // Default to Dark Mode

  /// If true, use pure black for dark mode backgrounds (OLED save)
  bool _isOledMode = false;

  /// Font scale factor (0.85 = Small, 0.9 = Default, 0.95 = Large)
  double _fontScale = 0.9; // Default is current look

  ThemeMode get themeMode => _themeMode;
  bool get isOledMode => _isOledMode;
  double get fontScale => _fontScale;

  ThemeController() {
    loadSettings();
  }

  Future<void> loadSettings() async {
    final box = await Hive.openBox('settings');
    final modeString = box.get('themeMode', defaultValue: 'dark'); // Default to dark
    _isOledMode = box.get('isOledMode', defaultValue: false);
    _fontScale = box.get('fontScale', defaultValue: 0.9); // Default to 0.9

    switch (modeString) {
      case 'light':
        _themeMode = ThemeMode.light;
        break;
      case 'dark':
      default: // Fallback to dark for any unknown value
        _themeMode = ThemeMode.dark;
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final box = await Hive.openBox('settings');
    String modeString;
    switch (mode) {
      case ThemeMode.light:
        modeString = 'light';
        break;
      case ThemeMode.dark:
      default: // Save as dark for any mode including system
        modeString = 'dark';
    }
    await box.put('themeMode', modeString);
    notifyListeners();
  }

  Future<void> toggleOledMode(bool enabled) async {
    _isOledMode = enabled;
    final box = await Hive.openBox('settings');
    await box.put('isOledMode', enabled);
    notifyListeners();
  }

  Future<void> setFontScale(double scale) async {
    _fontScale = scale.clamp(0.85, 1.0); // Tight range
    final box = await Hive.openBox('settings');
    await box.put('fontScale', _fontScale);
    notifyListeners();
  }

  // Define Themes
  ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.light),
      useMaterial3: true,
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0),
    );
  }

  ThemeData get darkTheme {
    final bgColor = _isOledMode ? Colors.black : const Color(0xFF121212);
    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.deepPurple,
        brightness: Brightness.dark,
        surface: _isOledMode ? Colors.black : const Color(0xFF1E1E1E),
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: bgColor,
      appBarTheme: AppBarTheme(backgroundColor: bgColor, foregroundColor: Colors.white, elevation: 0),
    );
  }
}
