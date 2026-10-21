import 'package:dictation_app/main.dart';
import 'package:dictation_app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

void main() {
  late FakeImagePicker picker;
  setUp(() {
    picker = FakeImagePicker();
    ImagePickerPlatform.instance = picker;
  });

  Future<void> correctOnce(WidgetTester tester) async {
    picker.queue.addAll(['book.jpg', 'copy.jpg']);
    await tester.tap(find.text('Câmera').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Câmera').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('correct')));
    await tester.pumpAndSettle();
  }

  testWidgets('two photos give a saved correction with no key or extra step', (tester) async {
    final app = await makeApp(tester);
    await tester.pumpWidget(DictationApp(app: app));
    await tester.pumpAndSettle();
    expect(find.text('Adicione as duas fotos'), findsOneWidget);

    await correctOnce(tester);
    expect(find.text('Dictation 59'), findsOneWidget);
    expect(find.text('A dictation, trecho por trecho'), findsOneWidget);
    expect(find.text('7.6'), findsOneWidget);
    expect(app.history.records, hasLength(1));
    // Headings and the exercise on the page were left out.
    expect(app.history.records.first.correction.originalText, startsWith('The teacher'));
    expect(app.history.records.first.correction.originalText, endsWith('exercise books.'));
  });

  testWidgets('marking a mistake as correct updates the score and the history', (tester) async {
    final app = await makeApp(tester);
    await tester.pumpWidget(DictationApp(app: app));
    await tester.pumpAndSettle();
    await correctOnce(tester);

    final button = find.text('Marcar como certo').first;
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(app.history.records.first.correction.mistakes, hasLength(6));
    expect(app.history.records.first.correction.score, '8.0');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('history'), contains('"score":"8.0"'));
  });

  testWidgets('progress lists every dictation with its score', (tester) async {
    final app = await makeApp(tester);
    await tester.pumpWidget(DictationApp(app: app));
    await tester.pumpAndSettle();
    await correctOnce(tester);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await correctOnce(tester);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Progresso').last);
    await tester.pumpAndSettle();
    expect(find.text('Notas ao longo do curso'), findsOneWidget);
    expect(find.text('Dictation 59'), findsNWidgets(2));
    await tester.tap(find.text('Dictation 59').first);
    await tester.pumpAndSettle();
    expect(find.text('A dictation, trecho por trecho'), findsOneWidget);
  });

  testWidgets('a photo that has no text gives a clear message', (tester) async {
    final app = await makeApp(tester, photos: {'book.jpg': bookPage});
    await tester.pumpWidget(DictationApp(app: app));
    await tester.pumpAndSettle();
    await correctOnce(tester);
    expect(find.text('Não encontrei texto na foto do aluno. Tente uma foto mais nítida.'), findsOneWidget);
    expect(app.history.records, isEmpty);
  });

  testWidgets('listen reads the whole photo text at once', (tester) async {
    final app = await makeApp(tester, photos: {'text.jpg': 'Hello there. How are you today?'});
    await tester.pumpWidget(DictationApp(app: app));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ouvir').last);
    await tester.pumpAndSettle();
    picker.queue.add('text.jpg');
    await tester.tap(find.text('Câmera'));
    await tester.pumpAndSettle();
    expect(find.text('Hello there. How are you today?'), findsOneWidget);
    expect(spoken, ['Hello there. How are you today?']);
  });

  testWidgets('pronunciation flags the words heard differently', (tester) async {
    final app = await makeApp(tester,
        heard: 'the teacher is standing in front of the class she is riding some words on the blackboard and the students are copying them into their exercise books');
    await tester.pumpWidget(DictationApp(app: app));
    await tester.pumpAndSettle();
    await correctOnce(tester);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pronúncia').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Dictation 59'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('record')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('record')));
    await tester.pumpAndSettle();
    expect(find.text('1 para revisar'), findsOneWidget);
    expect(find.text('• writing → "riding"'), findsOneWidget);
    await tester.tap(find.text('writing'));
    await tester.pump();
    expect(spoken.last, 'writing');
  });

  testWidgets('theme toggle flips light and dark and is saved', (tester) async {
    final app = await makeApp(tester);
    await tester.pumpWidget(DictationApp(app: app));
    await tester.pumpAndSettle();
    final before = Theme.of(tester.element(find.text('Texto original'))).brightness;
    await tester.tap(find.byType(ThemeToggleButton));
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.text('Texto original'))).brightness, isNot(before));
    expect((await SharedPreferences.getInstance()).getInt('themeMode'), isNotNull);
  });
}
