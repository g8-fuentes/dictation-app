import 'package:dictation_app/models.dart';
import 'package:dictation_app/screens/result_screen.dart';
import 'package:dictation_app/settings.dart';
import 'package:dictation_app/theme.dart';
import 'package:dictation_app/tts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sample = {
  'original_text': 'The teacher is standing in front of the class.',
  'student_text': 'The teacher is standing in front the clas.',
  'segments': [
    {
      'original': 'The teacher is standing',
      'tokens': [
        {'t': 'The', 's': 'ok'},
        {'t': 'teacher', 's': 'ok'},
        {'t': 'is', 's': 'ok'},
        {'t': 'standing', 's': 'ok'},
      ],
    },
    {
      'original': 'in front of the class.',
      'tokens': [
        {'t': 'in', 's': 'ok'},
        {'t': 'front', 's': 'ok'},
        {'t': 'of', 's': 'missing'},
        {'t': 'the', 's': 'ok'},
        {'t': 'clas.', 's': 'wrong', 'c': 'class.'},
      ],
    },
  ],
  'errors': [
    {'segment': 1, 'written': '', 'correct': 'of', 'type': 'palavra faltando', 'why': '"in front of" sempre leva "of".'},
    {'segment': 1, 'written': 'clas', 'correct': 'class', 'type': 'ortografia', 'why': 'Class tem dois "s".'},
  ],
  'score': 8.5,
  'notes': '',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('parses a correction and groups errors by segment', () {
    final c = Correction.fromJson(sample);
    expect(c.segments, hasLength(2));
    expect(c.segments[0].perfect, isTrue);
    expect(c.segments[1].mistakes, hasLength(2));
    expect(c.wordsWritten, 8);
    expect(c.score, '8.5');
  });

  testWidgets('result screen shows segments and errors', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'), (_) async => 1);
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings();
    await settings.load();
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.dark),
      home: ResultScreen(
        settings: settings,
        speaker: Speaker(settings),
        result: Correction.fromJson(sample),
      ),
    ));
    expect(find.text('8.5'), findsOneWidget);
    expect(find.text('CORRETO'), findsOneWidget);
    expect(find.text('2 ERROS'), findsOneWidget);
    expect(find.text('Class tem dois "s".'), findsOneWidget);
    await tester.tap(find.text('Tocar'));
    await tester.pump();
    expect(find.byKey(const ValueKey('stop-fab')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('stop-fab')));
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Tocar'), findsOneWidget);
  });
}
