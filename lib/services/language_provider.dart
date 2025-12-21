import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  static const String _kLocaleKey = 'app-locale';
  
  Locale _currentLocale = const Locale('en');
  Locale get currentLocale => _currentLocale;

  LanguageProvider() {
    _loadPreference();
  }

  void setLocale(Locale locale) {
    if (!['en', 'zh'].contains(locale.languageCode)) return;
    
    _currentLocale = locale;
    _savePreference(locale.languageCode);
    notifyListeners();
  }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString(_kLocaleKey);
    if (savedCode != null && ['en', 'zh'].contains(savedCode)) {
      _currentLocale = Locale(savedCode);
      notifyListeners();
    }
  }

  Future<void> _savePreference(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLocaleKey, languageCode);
  }
}
