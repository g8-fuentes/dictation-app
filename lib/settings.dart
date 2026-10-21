import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide preferences, persisted on the device.
class AppSettings extends ChangeNotifier {
  static const models = {
    'claude-sonnet-5-5': 'Equilibrado (Sonnet 5.5)',
    'claude-opus-5-5': 'Mais preciso (Opus 5.5)',
  };

  SharedPreferences? _store;

  String apiKey = '';
  String model = 'claude-sonnet-5-5';
  ThemeMode themeMode = ThemeMode.system;
  bool britishVoice = true;
  double speechRate = 0.42;

  Future<void> load() async {
    _store = await SharedPreferences.getInstance();
    apiKey = _store!.getString('apiKey') ?? '';
    final m = _store!.getString('model');
    if (m != null && models.containsKey(m)) model = m;
    themeMode = ThemeMode.values[_store!.getInt('themeMode') ?? ThemeMode.system.index];
    britishVoice = _store!.getBool('britishVoice') ?? true;
    speechRate = _store!.getDouble('speechRate') ?? 0.42;
  }

  bool get hasKey => apiKey.trim().isNotEmpty;

  Future<void> setApiKey(String v) async {
    apiKey = v.trim();
    await _store?.setString('apiKey', apiKey);
    notifyListeners();
  }

  Future<void> setModel(String v) async {
    model = v;
    await _store?.setString('model', v);
    notifyListeners();
  }

  /// Flips between light and dark, starting from whatever is on screen now.
  Future<void> toggleTheme(Brightness current) async {
    themeMode = current == Brightness.dark ? ThemeMode.light : ThemeMode.dark;
    await _store?.setInt('themeMode', themeMode.index);
    notifyListeners();
  }

  Future<void> setBritishVoice(bool v) async {
    britishVoice = v;
    await _store?.setBool('britishVoice', v);
    notifyListeners();
  }

  Future<void> setSpeechRate(double v) async {
    speechRate = v;
    await _store?.setDouble('speechRate', v);
    notifyListeners();
  }
}
