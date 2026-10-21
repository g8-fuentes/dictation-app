import 'package:dictation_app/checker.dart';
import 'package:dictation_app/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  test('a record survives saving and loading, marks included', () {
    final c = Checker.check(Checker.trimToMatch(bookPage, studentCopy), studentCopy);
    c.markCorrect(c.mistakes.first);
    final r = DictationRecord(id: '1', date: DateTime(2026, 10, 21), number: 59, correction: c);
    final back = DictationRecord.fromJson(r.toJson());
    expect(back.title, 'Dictation 59');
    expect(back.correction.score, c.score);
    expect(back.correction.mistakes.length, c.mistakes.length);
    expect(back.correction.segments.length, c.segments.length);
    expect(back.correction.segments.first.tokens.map((t) => t.status),
        c.segments.first.tokens.map((t) => t.status));
  });
}
