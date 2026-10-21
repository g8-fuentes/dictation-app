/// One word of the student's copy, as compared with the original.
class Token {
  Token(this.text, this.status, this.correct);

  final String text;
  final String status; // ok | wrong | missing | extra
  final String correct;

  factory Token.fromJson(Map<String, dynamic> j) => Token(
        '${j['t'] ?? ''}',
        '${j['s'] ?? 'ok'}',
        '${j['c'] ?? ''}',
      );
}

class Mistake {
  Mistake(this.segment, this.written, this.correct, this.type, this.why);

  final int segment;
  final String written;
  final String correct;
  final String type;
  final String why;

  factory Mistake.fromJson(Map<String, dynamic> j) => Mistake(
        (j['segment'] is num) ? (j['segment'] as num).toInt() : -1,
        '${j['written'] ?? ''}',
        '${j['correct'] ?? ''}',
        '${j['type'] ?? 'erro'}',
        '${j['why'] ?? ''}',
      );
}

/// A short chunk of the dictation, the way the teacher reads it aloud.
class Segment {
  Segment(this.original, this.tokens);

  final String original;
  final List<Token> tokens;
  final List<Mistake> mistakes = [];

  bool get perfect => tokens.every((t) => t.status == 'ok');
}

class Correction {
  Correction({
    required this.originalText,
    required this.studentText,
    required this.segments,
    required this.mistakes,
    required this.score,
    required this.notes,
  });

  final String originalText;
  final String studentText;
  final List<Segment> segments;
  final List<Mistake> mistakes;
  final String score;
  final String notes;

  int get wordsWritten => segments
      .expand((s) => s.tokens)
      .where((t) => t.status != 'missing')
      .length;

  factory Correction.fromJson(Map<String, dynamic> j) {
    final segs = <Segment>[
      for (final s in (j['segments'] as List? ?? const []))
        if (s is Map<String, dynamic>)
          Segment(
            '${s['original'] ?? ''}',
            [
              for (final t in (s['tokens'] as List? ?? const []))
                if (t is Map<String, dynamic>) Token.fromJson(t)
            ],
          ),
    ];
    final mistakes = <Mistake>[
      for (final e in (j['errors'] as List? ?? const []))
        if (e is Map<String, dynamic>) Mistake.fromJson(e)
    ];
    for (final m in mistakes) {
      if (m.segment >= 0 && m.segment < segs.length) {
        segs[m.segment].mistakes.add(m);
      }
    }
    final score = j['score'];
    return Correction(
      originalText: '${j['original_text'] ?? ''}',
      studentText: '${j['student_text'] ?? ''}',
      segments: segs,
      mistakes: mistakes,
      score: score is num ? score.toStringAsFixed(1) : '${score ?? ''}',
      notes: '${j['notes'] ?? ''}',
    );
  }
}
