import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'models.dart';

class ApiError implements Exception {
  ApiError(this.message, {this.tryOtherModel = false});
  final String message;

  /// The model is busy, over its free quota or gone; another one may work.
  final bool tryOtherModel;
  @override
  String toString() => message;
}

/// Talks to the Gemini API directly with the user's own (free) key from
/// Google AI Studio.
class GeminiApi {
  GeminiApi(this.apiKey, {http.Client? client}) : _client = client ?? http.Client();

  /// Tried in order: the free Flash models often answer "high demand" (503),
  /// and each has its own free quota.
  static const models = ['gemini-flash-latest', 'gemini-3.6-flash', 'gemini-3.5-flash-lite'];
  static const quickModels = ['gemini-flash-lite-latest', 'gemini-3.5-flash-lite'];

  final String apiKey;
  final http.Client _client;

  /// Fast, plain transcription of the book page, used to fill the loading
  /// screen with the dictation's words while the full correction runs.
  Future<String> transcribeOriginal(Uint8List original) async {
    final text = await _sendAny(
      quickModels,
      [original],
      'This photo shows a page from a Callan Method book with a dictation passage. '
          'Transcribe ONLY the dictation passage, exactly as printed. '
          'Reply with the text only, no comments.',
      json: false,
      maxTokens: 4000,
    );
    return text.trim();
  }

  Future<Correction> correct(Uint8List original, Uint8List student) async {
    final text = await _sendAny(models, [original, student], _prompt, json: true, maxTokens: 32000);
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end <= start) {
      throw ApiError('Não consegui organizar a resposta. Tente de novo.');
    }
    try {
      final data = jsonDecode(text.substring(start, end + 1)) as Map<String, dynamic>;
      final c = Correction.fromJson(data);
      if (c.segments.isEmpty) throw const FormatException();
      return c;
    } catch (_) {
      throw ApiError('Não consegui organizar a resposta. Tente de novo.');
    }
  }

  Future<String> _sendAny(List<String> models, List<Uint8List> images, String prompt,
      {required bool json, required int maxTokens}) async {
    for (var i = 0;; i++) {
      try {
        return await _send(models[i], images, prompt, json: json, maxTokens: maxTokens);
      } on ApiError catch (e) {
        if (!e.tryOtherModel || i == models.length - 1) rethrow;
      }
    }
  }

  /// Streams the reply so the connection never sits idle for minutes (mobile
  /// networks drop silent connections), and returns the full text.
  Future<String> _send(String model, List<Uint8List> images, String prompt,
      {required bool json, required int maxTokens}) async {
    final body = jsonEncode({
      'contents': [
        {
          'role': 'user',
          'parts': [
            for (final img in images)
              {
                'inline_data': {'mime_type': _mediaType(img), 'data': base64Encode(img)},
              },
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': {
        'maxOutputTokens': maxTokens,
        if (json) 'responseMimeType': 'application/json',
      },
    });

    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:streamGenerateContent?alt=sse');
    final req = http.Request('POST', url)
      ..headers.addAll({'x-goog-api-key': apiKey, 'content-type': 'application/json'})
      ..body = body;

    http.StreamedResponse res;
    try {
      res = await _client.send(req).timeout(const Duration(seconds: 60));
    } catch (_) {
      throw ApiError('Sem conexão com o Gemini. Verifique a internet e tente de novo.');
    }

    if (res.statusCode != 200) {
      final errBody = await res.stream.bytesToString().catchError((_) => '');
      final msg = _apiMessage(errBody);
      if (const {404, 429, 500, 503, 504}.contains(res.statusCode)) {
        throw ApiError(
          res.statusCode == 429
              ? 'Limite gratuito do Gemini atingido. Espere um minuto e tente de novo.'
              : 'O Gemini está sobrecarregado agora. Tente de novo em instantes.',
          tryOtherModel: true,
        );
      }
      throw ApiError(switch (res.statusCode) {
        400 when msg.toLowerCase().contains('api key') =>
          'Chave da API inválida. Confira em Configurações.',
        401 || 403 => 'Chave da API inválida ou sem permissão. Confira em Configurações.',
        413 => 'As fotos são grandes demais. Tente fotos menores.',
        _ => 'Algo deu errado (${res.statusCode}). $msg',
      });
    }

    final text = StringBuffer();
    String? finish;
    try {
      // Chunks arrive every few seconds while the model works; a long
      // silence means the connection is dead.
      final lines = res.stream
          .timeout(const Duration(seconds: 90))
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      await for (final line in lines) {
        if (!line.startsWith('data:')) continue;
        final Map<String, dynamic> ev;
        try {
          ev = jsonDecode(line.substring(5).trim()) as Map<String, dynamic>;
        } catch (_) {
          continue;
        }
        if (ev['error'] != null) {
          throw ApiError('O Gemini teve um erro. Tente de novo.');
        }
        final blocked = (ev['promptFeedback'] as Map?)?['blockReason'];
        if (blocked != null) finish = 'BLOCKED';
        for (final c in (ev['candidates'] as List? ?? const [])) {
          if (c is! Map) continue;
          for (final p in ((c['content'] as Map?)?['parts'] as List? ?? const [])) {
            if (p is Map && p['thought'] != true && p['text'] is String) text.write(p['text']);
          }
          if (c['finishReason'] != null) finish = '${c['finishReason']}';
        }
      }
    } on ApiError {
      rethrow;
    } catch (_) {
      throw ApiError('A conexão caiu durante a análise. Tente de novo.');
    }

    if (finish == 'MAX_TOKENS') {
      throw ApiError('O texto é longo demais para uma correção só. Tente uma foto com menos texto.');
    }
    if (text.isEmpty) {
      throw ApiError(finish != null && finish != 'STOP'
          ? 'O Gemini não conseguiu processar essas fotos. Tente outras fotos.'
          : 'O Gemini não conseguiu ler essas fotos. Tente fotos mais nítidas.');
    }
    return text.toString();
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
