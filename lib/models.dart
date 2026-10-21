/// One word of the student's copy, as compared with the original.
class Token {
  Token(this.text, this.status, this.correct);

  String text;
  String status; // ok | wrong | missing | extra
  String correct;

  factory Token.fromJson(Map<String, dynamic> j) => Token(
        '${j['t'] ?? ''}',
        '${j['s'] ?? 'ok'}',
        '${j['c'] ?? ''}',
      );

  Map<String, dynamic> toJson() => {
        't': text,
        's': status,
        if (correct.isNotEmpty) 'c': correct,
      };
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

  Map<String, dynamic> toJson() => {
        'segment': segment,
        'written': written,
        'correct': correct,
        'type': type,
        'why': why,
      };

  /// Punctuation and capitals weigh half a word in the score.
  double get weight => type == 'pontuação' || type == 'maiúscula' ? .5 : 1;
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
  String score;
  final String notes;

  int get originalWords =>
      segments.fold(0, (n, s) => n + s.original.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length);

  int get wordsWritten => segments
      .expand((s) => s.tokens)
      .where((t) => t.status != 'missing')
      .length;

  /// The teacher's call that a flagged word was right after all (usually a
  /// misread of the handwriting): the word turns correct and the score is
  /// recalculated.
  void markCorrect(Mistake m) {
    if (m.segment < 0 || m.segment >= segments.length) return;
    final seg = segments[m.segment];
    final index = seg.mistakes.indexOf(m);
    // The n-th flagged token of the segment belongs to its n-th mistake.
    final flagged = seg.tokens.where((t) => t.status != 'ok').toList();
    if (index >= 0 && index < flagged.length) {
      final t = flagged[index];
      switch (t.status) {
        case 'wrong':
          t.text = t.correct;
          t.status = 'ok';
          t.correct = '';
        case 'missing':
          t.status = 'ok';
        case 'extra':
          seg.tokens.remove(t);
      }
    }
    seg.mistakes.remove(m);
    mistakes.remove(m);
    score = scoreFor(mistakes, originalWords);
  }

  static String scoreFor(List<Mistake> mistakes, int words) {
    if (words == 0) return '';
    final weight = mistakes.fold<double>(0, (sum, e) => sum + e.weight);
    return (10 * (1 - weight / words)).clamp(0, 10).toStringAsFixed(1);
  }

  Map<String, dynamic> toJson() => {
        'original_text': originalText,
        'student_text': studentText,
        'segments': [
          for (final s in segments)
            {
              'original': s.original,
              'tokens': [for (final t in s.tokens) t.toJson()],
            },
        ],
        'errors': [for (final m in mistakes) m.toJson()],
        'score': score,
        'notes': notes,
      };

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

/// One corrected dictation in the student's history.
class DictationRecord {
  DictationRecord({required this.id, required this.date, this.number, required this.correction});

  final String id;
  final DateTime date;

  /// The dictation number printed in the book ("Dictation 59"), when found.
  final int? number;
  final Correction correction;

  String get title => number != null ? 'Dictation $number' : 'Dictation';

  double? get scoreValue => double.tryParse(correction.score);

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        if (number != null) 'number': number,
        'correction': correction.toJson(),
      };

  factory DictationRecord.fromJson(Map<String, dynamic> j) => DictationRecord(
        id: '${j['id']}',
        date: DateTime.tryParse('${j['date']}') ?? DateTime.now(),
        number: (j['number'] as num?)?.toInt(),
        correction: Correction.fromJson(j['correction'] as Map<String, dynamic>),
      );
}
