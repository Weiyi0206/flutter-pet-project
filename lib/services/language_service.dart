import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageService extends ChangeNotifier {
  static const String _languageKey = 'selected_language';
  String _selectedLanguage = 'English';

  LanguageService() {
    _loadLanguage();
  }

  String get selectedLanguage => _selectedLanguage;

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedLanguage = prefs.getString(_languageKey) ?? 'English';
    notifyListeners();
  }

  Future<void> changeLanguage(String language) async {
    _selectedLanguage = language;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, language);
    notifyListeners();
  }

  Locale getLocale() {
    switch (_selectedLanguage) {
      case 'Malay':
        return const Locale('ms', 'MY');
      case 'Mandarin':
        return const Locale('zh', 'CN');
      default:
        return const Locale('en', 'US');
    }
  }
}
