import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => false;

  Future<void> toggleTheme(bool dark) async {
    // Disabled as per user request to remove dark theme
    _themeMode = ThemeMode.light;
    notifyListeners();
  }
}
