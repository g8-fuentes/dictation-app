import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Reads the text in a photo. Kept behind an interface so tests can fake it.
abstract class TextReader {
  Future<String> read(String imagePath);
}

/// On-device text recognition with Google ML Kit: offline, no key.
class MlKitReader implements TextReader {
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  @override
  Future<String> read(String imagePath) async {
    final result = await _recognizer.processImage(InputImage.fromFilePath(imagePath));
    return tidy(result.text);
  }
}

/// Joins the lines of a photo into running text, undoing words split with a
/// hyphen at the end of a line.
String tidy(String raw) => raw
    .replaceAll(RegExp(r'(\w)-\s*\n\s*(\w)'), r'$1$2')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
