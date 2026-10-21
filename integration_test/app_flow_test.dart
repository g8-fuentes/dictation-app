import 'dart:convert';
import 'dart:io';

import 'package:dictation_app/app_state.dart';
import 'package:dictation_app/history.dart';
import 'package:dictation_app/main.dart';
import 'package:dictation_app/reader.dart';
import 'package:dictation_app/settings.dart';
import 'package:dictation_app/theme.dart';
import 'package:dictation_app/tts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:integration_test/integration_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/fakes.dart' show FakeSpeech;
import 'images.dart';

/// Hands out real image files, one per pick.
class FilePicker extends ImagePickerPlatform with MockPlatformInterfaceMixin {
  final queue = <String>[];

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async =>
      queue.isEmpty ? null : XFile(queue.removeAt(0));

  @override
  Future<LostDataResponse> getLostData() async => LostDataResponse.empty();
}

/// Runs on a real Android device/emulator with the real plugins: ML Kit text
/// recognition, voice and storage. Only the camera and microphone are faked.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // The surface switch has to be redone in every test.
  var surfaceReady = false;
  setUp(() => surfaceReady = false);
  Future<void> shot(WidgetTester t, String name) async {
    if (!surfaceReady) {
      await binding.convertFlutterSurfaceToImage();
      surfaceReady = true;
    }
    await t.pumpAndSettle();
    await binding.takeScreenshot(name);
  }

  Future<String> file(String name, String b64) async {
    final f = File('${Directory.systemTemp.path}/$name');
    await f.writeAsBytes(base64Decode(b64));
    return f.path;
  }

  Future<void> settle(WidgetTester t, [int ms = 3000]) async {
    final end = DateTime.now().add(Duration(milliseconds: ms));
    while (DateTime.now().isBefore(end)) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('ML Kit reads the book page and the handwriting', (t) async {
    final reader = MlKitReader();
    final sw = Stopwatch()..start();
    final book = await reader.read(await file('book.jpg', bookJpg));
    final hand = await reader.read(await file('hand.jpg', handJpg));
    debugPrint('OCR_BOOK (${sw.elapsedMilliseconds} ms): $book');
    debugPrint('OCR_HAND: $hand');
    expect(book, contains('The teacher is standing in front of the class.'));
    expect(hand.toLowerCase(), contains('teacher'));
  });

  testWidgets('correct, mark as correct, progress, listen, pronunciation', (t) async {
    await (await SharedPreferences.getInstance()).clear();
    final settings = AppSettings();
    await settings.load();
    final history = History();
    await history.load();
    final picker = FilePicker();
    ImagePickerPlatform.instance = picker;
    final app = AppState(
      settings: settings,
      history: history,
      speaker: Speaker(settings),
      reader: MlKitReader(),
      speech: FakeSpeech('the teacher is standing in front of the class she is riding some words'),
    );
    final book = await file('book.jpg', bookJpg);
    final hand = await file('hand.jpg', handJpg);

    await t.pumpWidget(DictationApp(app: app));
    await t.pumpAndSettle();
    await shot(t, '01-correct');

    picker.queue.addAll([book, hand]);
    await t.tap(find.text('Câmera').first);
    await settle(t, 1000);
    await t.tap(find.text('Câmera').last);
    await settle(t, 1000);
    await t.tap(find.byKey(const ValueKey('correct')));
    await settle(t, 6000);
    expect(find.text('A dictation, trecho por trecho'), findsOneWidget);
    expect(history.records, hasLength(1));
    final c = history.records.first.correction;
    debugPrint('RESULT ${history.records.first.title}: score ${c.score}, '
        '${[for (final m in c.mistakes) '${m.type}:${m.written}>${m.correct}'].join(' | ')}');
    await shot(t, '02-result');

    final before = c.mistakes.length;
    final mark = find.text('Marcar como certo').first;
    await t.ensureVisible(mark);
    await t.pumpAndSettle();
    await shot(t, '03-result-mistake');
    await t.tap(mark);
    await settle(t, 1000);
    expect(history.records.first.correction.mistakes.length, before - 1);

    await t.pageBack();
    await t.pumpAndSettle();
    await t.tap(find.text('Progresso').last);
    await t.pumpAndSettle();
    await shot(t, '04-progress');

    await t.tap(find.text('Ouvir').last);
    await t.pumpAndSettle();
    picker.queue.add(book);
    await t.tap(find.text('Câmera'));
    await settle(t, 3000);
    expect(find.byKey(const ValueKey('listen-play')), findsOneWidget);
    await shot(t, '05-listen');
    await t.tap(find.byKey(const ValueKey('listen-play')));
    await settle(t, 500);

    await t.tap(find.text('Pronúncia').last);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('record')));
    await settle(t, 500);
    await t.tap(find.byKey(const ValueKey('record')));
    await settle(t, 1000);
    expect(find.textContaining('para revisar'), findsOneWidget);
    await shot(t, '06-pronunciation');

    await t.tap(find.byType(ThemeToggleButton));
    await t.pumpAndSettle();
    await shot(t, '07-pronunciation-dark');
  });
}
