import 'package:flutter_tts/flutter_tts.dart';

import 'settings.dart';

/// Thin wrapper over flutter_tts that speaks English with the chosen accent.
class Speaker {
  Speaker(this.settings);

  final AppSettings settings;
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;
  String? _lang;
  int _session = 0;

  Future<void> _setup() async {
    final wanted = settings.britishVoice ? 'en-GB' : 'en-US';
    if (_ready && _lang == wanted) return;
    await _tts.awaitSpeakCompletion(true);
    var lang = wanted;
    try {
      final ok = await _tts.isLanguageAvailable(lang);
      if (ok != true) lang = 'en-US';
    } catch (_) {}
    await _tts.setLanguage(lang);
    _lang = wanted;
    _ready = true;
  }

  /// Speaks one piece of text, interrupting anything already playing.
  Future<void> say(String text, {double? rate}) async {
    _session++;
    await _setup();
    await _tts.stop();
    await _tts.setSpeechRate(rate ?? settings.speechRate);
    await _tts.speak(text);
  }

  /// Speaks the parts one after another with a pause between them, like a
  /// teacher dictating. [onPart] reports the index being read, then -1 at the end.
  Future<void> dictate(
    List<String> parts, {
    required Duration pause,
    double? rate,
    void Function(int index)? onPart,
  }) async {
    final session = ++_session;
    await _setup();
    await _tts.stop();
    await _tts.setSpeechRate(rate ?? settings.speechRate);
    for (var i = 0; i < parts.length; i++) {
      if (session != _session) return;
      onPart?.call(i);
      await _tts.speak(parts[i]);
      if (session != _session) return;
      if (i < parts.length - 1) await Future.delayed(pause);
    }
    if (session == _session) onPart?.call(-1);
  }

  Future<void> stop() async {
    _session++;
    await _tts.stop();
  }
}
