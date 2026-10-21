import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide preferences, persisted on the device.
class AppSettings extends ChangeNotifier {
  static const models = {
    'claude-sonnet-5-5': 'Equilibrado (Sonnet 5.5)',
    'claude-opus-5-5': 'Mais preciso (Opus 5.5)',
  };

  late SharedPreferences _prefs;

  String apiKey = '';
  String model = 'claude-sonnet-5-5';
  ThemeMode themeMode = ThemeMode.system;
  bool britishVoice = true;
  double speechRate = 0.42;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    apiKey = _prefs.getString('apiKey') ?? '';
    final m = _prefs.getString('model');
    if (m != null && models.containsKey(m)) model = m;
    themeMode = ThemeMode.values[_prefs.getInt('themeMode') ?? ThemeMode.system.index];
    britishVoice = _prefs.getBool('britishVoice') ?? true;
    speechRate = _prefs.getDouble('speechRate') ?? 0.42;
  }

  bool get hasKey => apiKey.trim().isNotEmpty;

  Future<void> setApiKey(String v) async {
    apiKey = v.trim();
    await _prefs.setString('apiKey', apiKey);
    notifyListeners();
  }

  Future<void> setModel(String v) async {
    model = v;
    await _prefs.setString('model', v);
    notifyListeners();
  }

  /// Flips between light and dark, starting from whatever is on screen now.
  Future<void> toggleTheme(Brightness current) async {
    themeMode = current == Brightness.dark ? ThemeMode.light : ThemeMode.dark;
    await _prefs.setInt('themeMode', themeMode.index);
    notifyListeners();
  }

  Future<void> setBritishVoice(bool v) async {
    britishVoice = v;
    await _prefs.setBool('britishVoice', v);
    notifyListeners();
  }

  Future<void> setSpeechRate(double v) async {
    speechRate = v;
    await _prefs.setDouble('speechRate', v);
    notifyListeners();
  }
}
