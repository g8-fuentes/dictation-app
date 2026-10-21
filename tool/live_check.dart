// ignore_for_file: avoid_print
// Runs one real correction against the Gemini API, for checking the prompt
// and the response handling by hand:
//   GEMINI_API_KEY=... dart run tool/live_check.dart book.jpg student.jpg
import 'dart:io';

import 'package:dictation_app/gemini_api.dart';

Future<void> main(List<String> args) async {
  final key = Platform.environment['GEMINI_API_KEY'] ?? '';
  final api = GeminiApi(key);
  final original = await File(args[0]).readAsBytes();
  final student = await File(args[1]).readAsBytes();

  var sw = Stopwatch()..start();
  final words = await api.transcribeOriginal(original);
  print('quick transcription (${sw.elapsedMilliseconds} ms): $words\n');

  sw = Stopwatch()..start();
  final c = await api.correct(original, student);
  print('correction (${sw.elapsedMilliseconds} ms): score ${c.score}, '
      '${c.mistakes.length} mistakes, ${c.segments.length} segments');
  for (final s in c.segments) {
    print('  [${s.original}]  ${s.tokens.map((t) => t.status == 'ok' ? t.text : '<${t.status}:${t.text}${t.correct.isEmpty ? '' : '>${t.correct}'}>').join(' ')}');
  }
  for (final m in c.mistakes) {
    print('  - ${m.type}: "${m.written}" -> "${m.correct}" (${m.why})');
  }
  if (c.notes.isNotEmpty) print('notes: ${c.notes}');
}
