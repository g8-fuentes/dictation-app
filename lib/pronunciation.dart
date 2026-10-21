import 'checker.dart';

class SpokenWord {
  SpokenWord(this.word, this.status, [this.heard = '']);

  final String word; // as printed in the text
  final String status; // ok | review | skipped
  final String heard; // what the recogniser understood, for review
}

/// Compares the text with what the speech recogniser heard. A word heard as
/// something else is flagged for review; it is an approximation of
/// pronunciation, not a phonetic analysis.
class Pronunciation {
  static const _numbers = {
    '0': 'zero', '1': 'one', '2': 'two', '3': 'three', '4': 'four', '5': 'five',
    '6': 'six', '7': 'seven', '8': 'eight', '9': 'nine', '10': 'ten', '11': 'eleven',
    '12': 'twelve', '20': 'twenty', '100': 'hundred',
  };

  static String _norm(String w) {
    final b = Checker.bare(w);
    return _numbers[b] ?? b;
  }

  static List<SpokenWord> compare(String text, String heard) {
    final orig = Checker.words(text);
    final said = Checker.words(heard);
    final o = [for (final w in orig) _norm(w)];
    final s = [for (final w in said) _norm(w)];
    final ops = Checker.align(o, s);
    final out = <SpokenWord>[];
    for (final op in ops) {
      if (op.o == null) continue; // extra words the recogniser heard
      final word = orig[op.o!];
      if (op.s == null) {
        out.add(SpokenWord(word, 'skipped'));
      } else if (o[op.o!] == s[op.s!] || Checker.similarity(o[op.o!], s[op.s!]) >= .85) {
        out.add(SpokenWord(word, 'ok'));
      } else {
        out.add(SpokenWord(word, 'review', said[op.s!]));
      }
    }
    return out;
  }

  /// Share of words heard as written, 0–100.
  static int score(List<SpokenWord> words) {
    if (words.isEmpty) return 0;
    return (100 * words.where((w) => w.status == 'ok').length / words.length).round();
  }
}
