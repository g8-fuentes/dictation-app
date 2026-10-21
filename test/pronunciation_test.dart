import 'package:dictation_app/pronunciation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('flags words heard differently and words left out', () {
    final r = Pronunciation.compare(
      'The teacher is writing some words on the blackboard.',
      'the teacher is riding some word on blackboard',
    );
    expect([for (final w in r) w.status], [
      'ok', 'ok', 'ok', 'review', 'ok', 'review', 'ok', 'skipped', 'ok',
    ]);
    expect(r[3].heard, 'riding');
    // "words" heard as "word": the final s was not pronounced.
    expect(r[5].heard, 'word');
    expect(Pronunciation.score(r), 67);
  });

  test('digits count as the number word', () {
    final r = Pronunciation.compare('I have two cats.', 'I have 2 cats');
    expect(r.every((w) => w.status == 'ok'), isTrue);
  });
}
