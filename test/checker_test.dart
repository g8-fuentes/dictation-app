import 'package:dictation_app/checker.dart';
import 'package:flutter_test/flutter_test.dart';

const original =
    'The teacher is standing in front of the class. She is writing some words on the blackboard, and the students are copying them into their exercise books.';
const student =
    'The teacher is standing in front the class. She is writting some word on the blackbord, and the students are coping them into there exercise books';

void main() {
  test('finds the classic dictation mistakes', () {
    final c = Checker.check(original, student);
    final pairs = [for (final m in c.mistakes) '${m.type}|${m.written}|${m.correct}'];
    expect(pairs, [
      'palavra faltando||of',
      'ortografia|writting|writing',
      'gramática|word|words',
      'ortografia|blackbord,|blackboard,',
      'ortografia|coping|copying',
      'homófono|there|their',
      'pontuação|books|books.',
    ]);
    expect(c.mistakes[1].why, 'O "t" não é dobrado: "writing".');
    expect(c.mistakes[3].why, 'Faltou a letra "a": "blackboard".');
    expect(c.score, '7.6');
  });

  test('a perfect copy has no mistakes and scores 10', () {
    final c = Checker.check(original, original);
    expect(c.mistakes, isEmpty);
    expect(c.score, '10.0');
    expect(c.segments.every((s) => s.perfect), isTrue);
  });

  test('segments are short phrases covering the whole text in order', () {
    final c = Checker.check(original, student);
    expect(c.segments.length, greaterThan(2));
    for (final s in c.segments) {
      expect(Checker.words(s.original).length, lessThanOrEqualTo(8));
    }
    expect(c.segments.map((s) => s.original).join(' '), original);
    final wrong = c.mistakes.firstWhere((m) => m.correct == 'blackboard,');
    expect(c.segments[wrong.segment].original, contains('blackboard'));
  });

  test('capitals and extra words', () {
    final c = Checker.check('My name is Peter.', 'my name is is peter.');
    expect([for (final m in c.mistakes) m.type], ['maiúscula', 'palavra a mais', 'maiúscula']);
    expect(c.mistakes.first.why, '"My" começa com letra maiúscula.');
  });

  test('unrelated words count as an extra word, not a misspelling', () {
    final c = Checker.check('I like apples', 'I like dogs apples');
    expect([for (final m in c.mistakes) m.type], ['palavra a mais']);
  });

  test('marking a mistake as correct fixes the copy and the score', () {
    final c = Checker.check(original, student);
    final writting = c.mistakes.firstWhere((m) => m.written == 'writting');
    c.markCorrect(writting);
    expect(c.mistakes, hasLength(6));
    expect(c.segments[writting.segment].tokens.map((t) => t.text), contains('writing'));
    expect(c.score, '8.0');
    final missing = c.mistakes.firstWhere((m) => m.type == 'palavra faltando');
    c.markCorrect(missing);
    expect(c.segments[missing.segment].tokens.where((t) => t.status != 'ok'), isEmpty);
  });

  test('trims the book page to the dictation the student wrote', () {
    const page =
        'Lesson 12 Dictation 34 The teacher is standing in front of the class. Exercise 5 Answer the questions.';
    expect(Checker.trimToMatch(page, 'The teacher is standing in front the class.'),
        'The teacher is standing in front of the class.');
    expect(Checker.trimToMatch(page, student.substring(0, 40)), startsWith('The teacher is standing'));
    expect(Checker.dictationNumber(page), 34);
    expect(Checker.dictationNumber('DICTATION No. 7'), 7);
    expect(Checker.dictationNumber('no number here'), isNull);
  });
}
