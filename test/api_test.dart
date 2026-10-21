import 'dart:convert';
import 'dart:typed_data';

import 'package:dictation_app/claude_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'app_test.dart' show sample;
import 'screens_test.dart' show reply;

void main() {
  final img = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0, 0, 0, 0]);

  test('sends both images, streaming, with the chosen model', () async {
    late Map body;
    final api = ClaudeApi('key', 'claude-sonnet-5-5', client: MockClient((req) async {
      body = jsonDecode(req.body) as Map;
      expect(req.headers['x-api-key'], 'key');
      return reply(jsonEncode(sample));
    }));
    final c = await api.correct(img, img);
    expect(body['model'], 'claude-sonnet-5-5');
    expect(body['stream'], true);
    final content = (body['messages'] as List).first['content'] as List;
    expect(content.where((b) => b['type'] == 'image'), hasLength(2));
    expect(content.first['source']['media_type'], 'image/png');
    expect(c.segments, hasLength(2));
  });

  test('a cut-off answer becomes a readable error', () async {
    final api = ClaudeApi('k', 'm', client: MockClient((_) async => reply('{"segm', stop: 'max_tokens')));
    expect(() => api.correct(img, img), throwsA(isA<ClaudeError>()));
  });

  test('garbage text becomes a readable error', () async {
    final api = ClaudeApi('k', 'm', client: MockClient((_) async => reply('não sei')));
    await expectLater(
      api.correct(img, img),
      throwsA(predicate((e) => e is ClaudeError && e.message.contains('organizar'))),
    );
  });

  test('stream error event is reported', () async {
    final api = ClaudeApi('k', 'm', client: MockClient((_) async => http.Response(
        'event: error\ndata: {"type":"error","error":{"type":"overloaded_error"}}\n\n', 200)));
    await expectLater(
      api.correct(img, img),
      throwsA(predicate((e) => e is ClaudeError && e.message.contains('sobrecarregado'))),
    );
  });

  test('network failure is reported', () async {
    final api = ClaudeApi('k', 'm', client: MockClient((_) async => throw Exception('offline')));
    await expectLater(
      api.correct(img, img),
      throwsA(predicate((e) => e is ClaudeError && e.message.contains('conexão'))),
    );
  });
}
