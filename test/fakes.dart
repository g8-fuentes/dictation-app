import 'package:dictation_app/app_state.dart';
import 'package:dictation_app/history.dart';
import 'package:dictation_app/reader.dart';
import 'package:dictation_app/settings.dart';
import 'package:dictation_app/speech.dart';
import 'package:dictation_app/tts.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

const bookPage =
    'Lesson 41 Dictation 59 The teacher is standing in front of the class. She is writing some words on the blackboard, and the students are copying them into their exercise books. Exercise 5 Answer the questions.';
const studentCopy =
    'The teacher is standing in front the class. She is writting some word on the blackbord, and the students are coping them into there exercise books';

/// A valid 1x1 PNG, so photo previews can render.
final pngBytes = Uint8List.fromList([
  137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0, 0, 0, 1, 8, 2, 0,
  0, 0, 144, 119, 83, 222, 0, 0, 0, 12, 73, 68, 65, 84, 120, 156, 99, 248, 255, 255, 63, 0, 5,
  254, 2, 254, 13, 239, 70, 184, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130,
]);

/// Returns the text registered for each photo path.
class FakeReader implements TextReader {
  FakeReader(this.texts);
  final Map<String, String> texts;
  final reads = <String>[];

  @override
  Future<String> read(String imagePath) async {
    reads.add(imagePath);
    return texts[imagePath] ?? '';
  }
}

class FakeSpeech implements SpeechInput {
  FakeSpeech(this.heard, {this.available = true});
  String heard;
  bool available;

  @override
  Future<bool> init() async => available;

  @override
  Future<void> start(void Function(String text) onText) async => onText(heard);

  @override
  Future<String> stop() async => heard;
}

/// Hands out photos named in [queue], one per pick.
class FakeImagePicker extends ImagePickerPlatform with MockPlatformInterfaceMixin {
  final queue = <String>[];

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async =>
      queue.isEmpty ? null : XFile.fromData(pngBytes, path: queue.removeAt(0));

  @override
  Future<LostDataResponse> getLostData() async => LostDataResponse.empty();
}

final spoken = <String>[];

/// Fresh app state with fakes for the camera, OCR, voice and microphone.
Future<AppState> makeApp(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
  Map<String, String> photos = const {'book.jpg': bookPage, 'copy.jpg': studentCopy},
  String heard = '',
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);
  spoken.clear();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(const MethodChannel('flutter_tts'), (call) async {
    if (call.method == 'speak') spoken.add(call.arguments as String);
    return 1;
  });
  SharedPreferences.setMockInitialValues(prefs);
  final settings = AppSettings();
  await settings.load();
  final history = History();
  await history.load();
  return AppState(
    settings: settings,
    history: history,
    speaker: Speaker(settings),
    reader: FakeReader(photos),
    speech: FakeSpeech(heard),
  );
}
