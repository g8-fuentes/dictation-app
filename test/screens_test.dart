import 'dart:convert';

import 'package:dictation_app/gemini_api.dart';
import 'package:dictation_app/main.dart';
import 'package:dictation_app/screens/loading_screen.dart';
import 'package:dictation_app/settings.dart';
import 'package:dictation_app/theme.dart';
import 'package:dictation_app/tts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_test.dart' show sample;

final spoken = <String>[];

Future<AppSettings> setup(WidgetTester tester, [Map<String, Object> prefs = const {}]) async {
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
  final s = AppSettings();
  await s.load();
  return s;
}

/// A Gemini streaming reply (server-sent events) carrying [text].
http.Response reply(String text, {String finish = 'STOP'}) {
  final chunks = <Map<String, dynamic>>[
    // A thought part first: it must never reach the answer.
    {
      'candidates': [
        {
          'content': {
            'parts': [
              {'text': 'thinking...', 'thought': true}
            ]
          }
        }
      ]
    },
    // Split the text so the test covers stitching chunks back together.
    for (var i = 0; i < text.length; i += 7)
      {
        'candidates': [
          {
            'content': {
              'role': 'model',
              'parts': [
                {'text': text.substring(i, (i + 7).clamp(0, text.length))}
              ]
            },
            if (i + 7 >= text.length) 'finishReason': finish,
          }
        ]
      },
  ];
  final sse = chunks.map((e) => 'data: ${jsonEncode(e)}\r\n\r\n').join();
  return http.Response.bytes(utf8.encode(sse), 200, headers: {'content-type': 'text/event-stream'});
}

void main() {
  testWidgets('home shows both photo slots and asks for the key', (tester) async {
    final s = await setup(tester);
    await tester.pumpWidget(DictationApp(settings: s, speaker: Speaker(s)));
    await tester.pumpAndSettle();
    expect(find.text('Texto original'), findsOneWidget);
    expect(find.text('Texto do aluno'), findsOneWidget);
    expect(find.text('Falta a chave da API'), findsOneWidget);
    expect(find.text('Adicione as duas fotos'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed, isNull);
  });

  testWidgets('theme toggle flips light and dark and is saved', (tester) async {
    final s = await setup(tester);
    await tester.pumpWidget(DictationApp(settings: s, speaker: Speaker(s)));
    await tester.pumpAndSettle();
    final before = Theme.of(tester.element(find.text('Texto original'))).brightness;
    await tester.tap(find.byType(ThemeToggleButton));
    await tester.pumpAndSettle();
    final after = Theme.of(tester.element(find.text('Texto original'))).brightness;
    expect(after, isNot(before));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('themeMode'), isNotNull);
  });

  testWidgets('settings saves the API key', (tester) async {
    final s = await setup(tester);
    await tester.pumpWidget(DictationApp(settings: s, speaker: Speaker(s)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Configurações'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), ' AIza-test ');
    await tester.pumpAndSettle();
    expect(s.apiKey, 'AIza-test');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Falta a chave da API'), findsNothing);
  });

  testWidgets('loading shows tappable words, then the result', (tester) async {
    final s = await setup(tester, {'geminiKey': 'k'});
    var calls = 0;
    final client = MockClient((req) async {
      calls++;
      if (req.url.path.contains(GeminiApi.quickModels.first)) {
        return reply('The teacher is standing in front of the class.');
      }
      await Future.delayed(const Duration(seconds: 2));
      return reply('Aqui está:\n${jsonEncode(sample)}');
    });
    final img = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]);
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      home: LoadingScreen(
        settings: s,
        speaker: Speaker(s),
        original: img,
        student: img,
        api: GeminiApi('k', client: client),
      ),
    ));
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Toque numa palavra da dictation para ouvir a pronúncia.'), findsOneWidget);
    await tester.tap(find.text('front'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(spoken, contains('front'));
    await tester.tap(find.text('class.'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(spoken.last, 'class');

    await tester.pump(const Duration(seconds: 3));
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('Resultado'), findsOneWidget);
    expect(find.text('A dictation, trecho por trecho'), findsOneWidget);
    await tester.tap(find.byTooltip('Ouvir este trecho').first);
    await tester.pump(const Duration(milliseconds: 300));
    expect(spoken.last, 'The teacher is standing');
  });

  testWidgets('loading returns a readable error on a bad key', (tester) async {
    final s = await setup(tester, {'geminiKey': 'k'});
    final client = MockClient((req) async =>
        http.Response('{"error":{"code":400,"message":"API key not valid. Please pass a valid API key."}}', 400));
    String? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => TextButton(
          onPressed: () async {
            result = await Navigator.of(ctx).push<String>(MaterialPageRoute(
              builder: (_) => LoadingScreen(
                settings: s,
                speaker: Speaker(s),
                original: Uint8List(20),
                student: Uint8List(20),
                api: GeminiApi('k', client: client),
              ),
            ));
          },
          child: const Text('go'),
        ),
      ),
      theme: buildTheme(Brightness.light),
    ));
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(result, 'Chave da API inválida. Confira em Configurações.');
  });
}


