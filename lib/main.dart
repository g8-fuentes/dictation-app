import 'package:flutter/material.dart';

import 'app_state.dart';
import 'history.dart';
import 'reader.dart';
import 'screens/root_screen.dart';
import 'settings.dart';
import 'speech.dart';
import 'theme.dart';
import 'tts.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = AppSettings();
  final history = History();
  try {
    await settings.load();
    await history.load();
  } catch (_) {
    // Start with defaults rather than hang on the splash screen.
  }
  runApp(DictationApp(
    app: AppState(
      settings: settings,
      history: history,
      speaker: Speaker(settings),
      reader: MlKitReader(),
      speech: NativeSpeechInput(),
    ),
  ));
}

class DictationApp extends StatelessWidget {
  const DictationApp({super.key, required this.app});

  final AppState app;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app.settings,
      builder: (context, _) => MaterialApp(
        title: 'dictation-app',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: app.settings.themeMode,
        home: RootScreen(app: app),
      ),
    );
  }
}
