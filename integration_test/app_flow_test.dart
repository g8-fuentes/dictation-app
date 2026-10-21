import 'dart:convert';
import 'dart:typed_data';

import 'package:dictation_app/claude_api.dart';
import 'package:dictation_app/main.dart';
import 'package:dictation_app/screens/loading_screen.dart';
import 'package:dictation_app/settings.dart';
import 'package:dictation_app/theme.dart';
import 'package:dictation_app/tts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/app_test.dart' show sample;
import '../test/screens_test.dart' show reply;

/// Runs on a real Android device/emulator with the real plugins (voice,
/// storage); only the Claude API is faked.
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
    await t.pump();
    await binding.takeScreenshot(name);
  }

  Future<void> wait(WidgetTester t, int ms) async {
    final end = DateTime.now().add(Duration(milliseconds: ms));
    while (DateTime.now().isBefore(end)) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('home, theme, settings', (t) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    final s = AppSettings();
    await s.load();
    await t.pumpWidget(DictationApp(settings: s, speaker: Speaker(s)));
    await t.pumpAndSettle();
    expect(find.text('Texto original'), findsOneWidget);
    await shot(t, '01-home');

    await t.tap(find.byType(ThemeToggleButton));
    await t.pumpAndSettle();
    await shot(t, '02-home-theme');

    await t.tap(find.byTooltip('Configurações'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'sk-ant-test');
    await t.pumpAndSettle();
    await shot(t, '03-settings');
    await t.pageBack();
    await t.pumpAndSettle();
    expect(find.text('Falta a chave da API'), findsNothing);
    expect((await SharedPreferences.getInstance()).getString('apiKey'), 'sk-ant-test');
  });

  testWidgets('loading words speak, result narrates', (t) async {
    final s = AppSettings();
    await s.load();
    final speaker = Speaker(s);
    final client = MockClient((req) async {
      final body = jsonDecode(req.body) as Map;
      if (body['model'] == ClaudeApi.quickModel) {
        return reply('The teacher is standing in front of the class.');
      }
      await Future.delayed(const Duration(seconds: 6));
      return reply(jsonEncode(sample));
    });
    final img = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]);
    await t.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: LoadingScreen(
        settings: s,
        speaker: speaker,
        original: img,
        student: img,
        api: ClaudeApi('k', s.model, client: client),
      ),
    ));
    await wait(t, 1500);
    expect(find.text('front'), findsOneWidget);
    await t.tap(find.text('front'));
    await wait(t, 600);
    await shot(t, '04-loading');
    await t.tap(find.text('teacher'));
    await wait(t, 300);

    await wait(t, 6000);
    await t.pumpAndSettle();
    expect(find.text('Resultado'), findsOneWidget);
    await shot(t, '05-result');

    await t.tap(find.text('Tocar'));
    await wait(t, 1500);
    expect(find.byKey(const ValueKey('stop-fab')), findsOneWidget);
    await shot(t, '06-result-playing');
    await t.tap(find.byKey(const ValueKey('stop-fab')));
    await wait(t, 3000);
    expect(find.byKey(const ValueKey('stop-fab')), findsNothing);

    await t.tap(find.byTooltip('Ouvir este trecho').first);
    await wait(t, 2000);
    await t.scrollUntilVisible(find.text('Nova correção'), 300);
    await shot(t, '07-result-bottom');
  });
}
