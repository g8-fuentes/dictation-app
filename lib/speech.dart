import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Hears the student reading aloud. Kept behind an interface so tests can
/// fake it.
abstract class SpeechInput {
  /// False when the phone has no speech recognition or the microphone was
  /// refused.
  Future<bool> init();

  /// Starts listening; [onText] gets everything heard so far.
  Future<void> start(void Function(String text) onText);

  /// Stops and returns everything heard.
  Future<String> stop();
}

/// Android's own speech recognition: no key needed. It stops by itself after
/// a pause, so it is restarted until the student taps stop, keeping what was
/// already heard.
class NativeSpeechInput implements SpeechInput {
  final _stt = SpeechToText();
  bool _ready = false;
  bool _wanted = false;
  String _done = '';
  String _current = '';
  String? _locale;
  void Function(String)? _onText;

  String get _all => [_done, _current].where((s) => s.isNotEmpty).join(' ');

  @override
  Future<bool> init() async {
    if (_ready) return true;
    try {
      _ready = await _stt.initialize(onStatus: _onStatus, onError: (_) => _restartSoon());
      if (_ready) {
        final locales = await _stt.locales();
        String? pick(String id) =>
            locales.map((l) => l.localeId).where((l) => l.replaceAll('-', '_') == id).firstOrNull;
        _locale = pick('en_GB') ?? pick('en_US') ??
            locales.map((l) => l.localeId).where((l) => l.startsWith('en')).firstOrNull ?? 'en_US';
      }
    } catch (_) {
      _ready = false;
    }
    return _ready;
  }

  @override
  Future<void> start(void Function(String text) onText) async {
    _onText = onText;
    _done = '';
    _current = '';
    _wanted = true;
    await _listen();
  }

  Future<void> _listen() async {
    if (!_wanted) return;
    await _stt.listen(
      onResult: _onResult,
      listenOptions: SpeechListenOptions(
        localeId: _locale,
        partialResults: true,
        listenMode: ListenMode.dictation,
        cancelOnError: false,
        listenFor: const Duration(minutes: 5),
        pauseFor: const Duration(seconds: 8),
      ),
    );
  }

  void _onResult(SpeechRecognitionResult r) {
    _current = r.recognizedWords;
    if (r.finalResult) {
      _done = _all;
      _current = '';
    }
    _onText?.call(_all);
  }

  void _onStatus(String status) {
    if (status == SpeechToText.doneStatus || status == SpeechToText.notListeningStatus) {
      _restartSoon();
    }
  }

  void _restartSoon() {
    if (!_wanted) return;
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_wanted && !_stt.isListening) _listen();
    });
  }

  @override
  Future<String> stop() async {
    _wanted = false;
    await _stt.stop();
    // The last words arrive just after stopping.
    await Future.delayed(const Duration(milliseconds: 600));
    if (_current.isNotEmpty) {
      _done = _all;
      _current = '';
    }
    return _done;
  }
}
