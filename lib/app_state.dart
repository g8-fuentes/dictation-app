import 'history.dart';
import 'reader.dart';
import 'settings.dart';
import 'speech.dart';
import 'tts.dart';

/// What every screen needs, handed down from main().
class AppState {
  AppState({
    required this.settings,
    required this.history,
    required this.speaker,
    required this.reader,
    required this.speech,
  });

  final AppSettings settings;
  final History history;
  final Speaker speaker;
  final TextReader reader;
  final SpeechInput speech;
}
