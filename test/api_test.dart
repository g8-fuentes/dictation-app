import 'dart:convert';
import 'dart:typed_data';

import 'package:dictation_app/gemini_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'app_test.dart' show sample;
import 'screens_test.dart' show reply;

void main() {
  final img = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0, 0, 0, 0]);

  test('sends both images as a streaming JSON request with the key', () async {
    late http.Request sent;
    final api = GeminiApi('key', client: MockClient((req) async {
      sent = req;
      return reply(jsonEncode(sample));
    }));
    final c = await api.correct(img, img);
    expect(sent.url.path, endsWith('/models/${GeminiApi.models.first}:streamGenerateContent'));
    expect(sent.url.queryParameters['alt'], 'sse');
    expect(sent.headers['x-goog-api-key'], 'key');
    final body = jsonDecode(sent.body) as Map;
    final parts = (body['contents'] as List).first['parts'] as List;
    expect(parts.where((p) => p['inline_data'] != null), hasLength(2));
    expect(parts.first['inline_data']['mime_type'], 'image/png');
    expect(body['generationConfig']['responseMimeType'], 'application/json');
    expect(c.segments, hasLength(2));
    expect(c.mistakes, hasLength(2));
  });

  test('a busy model falls back to the next one', () async {
    final tried = <String>[];
    final api = GeminiApi('k', client: MockClient((req) async {
      tried.add(req.url.pathSegments.last.split(':').first);
      if (tried.length == 1) {
        return http.Response('{"error":{"code":503,"message":"high demand"}}', 503);
      }
      return reply(jsonEncode(sample));
    }));
    await api.correct(img, img);
    expect(tried, GeminiApi.models.take(2).toList());
  });

  test('when every model is busy the user is told so', () async {
    final api = GeminiApi('k',
        client: MockClient((_) async => http.Response('{"error":{"code":503}}', 503)));
    await expectLater(
      api.correct(img, img),
      throwsA(predicate((e) => e is ApiError && e.message.contains('sobrecarregado'))),
    );
  });

  test('an invalid key is reported, without trying other models', () async {
    var calls = 0;
    final api = GeminiApi('k', client: MockClient((_) async {
      calls++;
      return http.Response('{"error":{"code":400,"message":"API key not valid."}}', 400);
    }));
    await expectLater(
      api.correct(img, img),
      throwsA(predicate((e) => e is ApiError && e.message.contains('Chave'))),
    );
    expect(calls, 1);
  });

  test('a cut-off answer becomes a readable error', () async {
    final api = GeminiApi('k', client: MockClient((_) async => reply('{"segm', finish: 'MAX_TOKENS')));
    await expectLater(
      api.correct(img, img),
      throwsA(predicate((e) => e is ApiError && e.message.contains('longo'))),
    );
  });

  test('garbage text becomes a readable error', () async {
    final api = GeminiApi('k', client: MockClient((_) async => reply('não sei')));
    await expectLater(
      api.correct(img, img),
      throwsA(predicate((e) => e is ApiError && e.message.contains('organizar'))),
    );
  });

  test('a blocked request is reported', () async {
    final api = GeminiApi('k', client: MockClient((_) async => http.Response(
        'data: {"promptFeedback":{"blockReason":"SAFETY"}}\r\n\r\n', 200)));
    await expectLater(
      api.correct(img, img),
      throwsA(predicate((e) => e is ApiError && e.message.contains('processar'))),
    );
  });

  test('network failure is reported', () async {
    final api = GeminiApi('k', client: MockClient((_) async => throw Exception('offline')));
    await expectLater(
      api.correct(img, img),
      throwsA(predicate((e) => e is ApiError && e.message.contains('conexão'))),
    );
  });
}
