import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_theme.dart'; // make sure you have this path correct

class ThemeProvider with ChangeNotifier {
  static const String _themePreferenceKey = 'theme_preference';
  ColorBlindMode _currentMode = ColorBlindMode.normal;
  bool _isDarkMode = false;
  late SharedPreferences _prefs;

  ThemeProvider() {
    _initializeTheme();
  }

  bool get isDarkMode => _isDarkMode;

  Future<void> _initializeTheme() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final savedTheme = _prefs.getBool(_themePreferenceKey);
      if (savedTheme != null) {
        _isDarkMode = savedTheme;
      }
      notifyListeners();
    } catch (e) {
      print('Error initializing theme: $e');
      _isDarkMode = false;
    }
  }

  Future<void> setDarkMode(bool value) async {
    try {
      if (_isDarkMode != value) {
        _isDarkMode = value;
        await _prefs.setBool(_themePreferenceKey, value);
        notifyListeners();
      }
    } catch (e) {
      print('Error setting dark mode: $e');
    }
  }

  ColorBlindMode get currentMode => _currentMode;

  ThemeData get themeData {
    if (_isDarkMode) {
      return AppTheme.darkTheme;
    }
    return AppThemeManager.getCurrentTheme();
  }

  void setColorBlindMode(ColorBlindMode mode) {
    if (_currentMode != mode) {
      _currentMode = mode;
      AppThemeManager.currentMode = mode;
      notifyListeners();
    }
  }
}
