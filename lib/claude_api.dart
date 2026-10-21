import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'models.dart';

class ClaudeError implements Exception {
  ClaudeError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Talks to the Anthropic Messages API directly with the user's own key.
class ClaudeApi {
  ClaudeApi(this.apiKey, this.model);

  final String apiKey;
  final String model;
  static const quickModel = 'claude-haiku-5-5';
  static final _url = Uri.parse('https://api.anthropic.com/v1/messages');

  /// Fast, plain transcription of the book page, used to fill the loading
  /// screen with the dictation's words while the full correction runs.
  Future<String> transcribeOriginal(Uint8List original) async {
    final text = await _send(
      quickModel,
      [original],
      'This photo shows a page from a Callan Method book with a dictation passage. '
          'Transcribe ONLY the dictation passage, exactly as printed. '
          'Reply with the text only, no comments.',
      maxTokens: 1500,
    );
    return text.trim();
  }

  Future<Correction> correct(Uint8List original, Uint8List student) async {
    final text = await _send(model, [original, student], _prompt, maxTokens: 12000);
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end <= start) {
      throw ClaudeError('Não consegui organizar a resposta. Tente de novo.');
    }
    try {
      final data = jsonDecode(text.substring(start, end + 1)) as Map<String, dynamic>;
      final c = Correction.fromJson(data);
      if (c.segments.isEmpty) throw const FormatException();
      return c;
    } catch (_) {
      throw ClaudeError('Não consegui organizar a resposta. Tente de novo.');
    }
  }

  Future<String> _send(String model, List<Uint8List> images, String prompt,
      {required int maxTokens}) async {
    final body = jsonEncode({
      'model': model,
      'max_tokens': maxTokens,
      'messages': [
        {
          'role': 'user',
          'content': [
            for (final img in images)
              {
                'type': 'image',
                'source': {
                  'type': 'base64',
                  'media_type': _mediaType(img),
                  'data': base64Encode(img),
                },
              },
            {'type': 'text', 'text': prompt},
          ],
        },
      ],
    });

    http.Response res;
    try {
      res = await http
          .post(_url,
              headers: {
                'x-api-key': apiKey,
                'anthropic-version': '2023-06-01',
                'content-type': 'application/json',
              },
              body: body)
          .timeout(const Duration(seconds: 180));
    } catch (_) {
      throw ClaudeError('Sem conexão com o Claude. Verifique a internet e tente de novo.');
    }

    if (res.statusCode != 200) {
      throw ClaudeError(switch (res.statusCode) {
        401 => 'Chave da API inválida. Confira em Configurações.',
        403 => 'Esta chave não tem permissão para usar o modelo escolhido.',
        413 => 'As fotos são grandes demais. Tente fotos menores.',
        429 => 'Muitas correções seguidas. Espere um pouco e tente de novo.',
        529 || 503 => 'O Claude está sobrecarregado agora. Tente de novo em instantes.',
        _ => 'Algo deu errado (${res.statusCode}). ${_apiMessage(res.body)}',
      });
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final parts = (data['content'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .where((b) => b['type'] == 'text')
        .map((b) => b['text'] as String);
    final text = parts.join();
    if (text.isEmpty) {
      throw ClaudeError('O Claude não conseguiu ler essas fotos. Tente fotos mais nítidas.');
    }
    return text;
  }

  static String _apiMessage(String body) {
    try {
      return '${(jsonDecode(body) as Map)['error']['message']}';
    } catch (_) {
      return '';
    }
  }

  static String _mediaType(Uint8List b) {
    if (b.length > 4 && b[0] == 0x89 && b[1] == 0x50) return 'image/png';
    if (b.length > 12 && b[8] == 0x57 && b[9] == 0x45 && b[10] == 0x42 && b[11] == 0x50) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }

  static const _prompt = '''You are helping an English teacher who uses the Callan Method correct a student's dictation.
Image 1 is the ORIGINAL dictation text (printed, from the Callan book; the page may show more than one dictation or other text — if so, use the dictation passage that best matches what the student wrote). Image 2 is the STUDENT's handwritten version.

Steps:
1. Transcribe the original exactly.
2. Transcribe the student's handwriting EXACTLY as written — keep every misspelling, missing word, wrong capital letter and wrong punctuation. Do not fix anything. If a word is truly illegible, write it as [?].
3. Split the ORIGINAL into short segments the way a teacher dictates it: natural phrases of about 3 to 10 words, breaking at punctuation and natural pauses. Every word of the original belongs to exactly one segment, in order.
4. Align the student's text to those segments and compare word by word.

Count as errors: spelling, wrong word (including homophones like there/their), missing words, extra words, wrong verb form or plural, and capital letters at the start of sentences or in proper nouns. Report punctuation mistakes too, with type "pontuação". Ignore line breaks and handwriting style.

Reply with ONLY one JSON object, no other text:
{
 "original_text": "...",
 "student_text": "...",
 "segments": [
   {"original": "the segment of the original text",
    "tokens": [ {"t": "word as the student wrote it (with attached punctuation)", "s": "ok"|"wrong"|"extra"|"missing", "c": "correct form (only for wrong)"} ]}
 ],
 "errors": [ {"segment": 0, "written": "what the student wrote, empty if missing", "correct": "correct form, empty if extra", "type": "ortografia"|"palavra faltando"|"palavra a mais"|"gramática"|"homófono"|"maiúscula"|"pontuação", "why": "short explanation in Brazilian Portuguese, max 20 words"} ],
 "score": 8.5,
 "notes": "optional short note in Brazilian Portuguese (e.g. illegible parts), or empty"
}
"segment" in each error is the 0-based index of the segment where it happens. In each segment, "tokens" follow the student's text in order; for a missing word insert a token with s="missing" and t = the missing word where it belongs. Every token that is not "ok" must have a matching entry in "errors", in the same order. "score" is a number out of 10 with one decimal, based on errors per word.''';
}
