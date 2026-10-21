import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'settings.dart';
import 'theme.dart';
import 'tts.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = AppSettings();
  await settings.load();
  runApp(DictationApp(settings: settings, speaker: Speaker(settings)));
}

class DictationApp extends StatelessWidget {
  const DictationApp({super.key, required this.settings, required this.speaker});

  final AppSettings settings;
  final Speaker speaker;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp(
        title: 'Dictation',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: settings.themeMode,
        home: HomeScreen(settings: settings, speaker: speaker),
      ),
    );
  }
}
