import 'models.dart';

/// Compares the student's copy with the original entirely on the device:
/// aligns the words, labels each mistake and explains it in Portuguese.
class Checker {
  static final _space = RegExp(r'\s+');
  static final _edgePunct = RegExp(r"^[^\w']+|[^\w']+$");

  static List<String> words(String text) =>
      text.trim().split(_space).where((w) => w.isNotEmpty).toList();

  /// The bare word: no punctuation around it, lower case.
  static String bare(String w) => w.replaceAll(_edgePunct, '').toLowerCase();

  static String _noPunct(String w) => w.replaceAll(_edgePunct, '');

  static Correction check(String original, String student) {
    final orig = words(original);
    final stud = words(student);
    final ops = align(orig, stud);
    final segOf = _segmentIndex(orig);
    final segCount = orig.isEmpty ? 0 : segOf.last + 1;

    final segTokens = List.generate(segCount, (_) => <Token>[]);
    final mistakes = <Mistake>[];
    var lastSeg = 0;
    for (final op in ops) {
      if (segCount == 0) break;
      final seg = op.o != null ? segOf[op.o!] : lastSeg;
      lastSeg = seg;
      if (op.o != null && op.s != null) {
        final o = orig[op.o!], s = stud[op.s!];
        if (o == s) {
          segTokens[seg].add(Token(s, 'ok', ''));
        } else {
          segTokens[seg].add(Token(s, 'wrong', o));
          final (type, why) = explain(s, o);
          mistakes.add(Mistake(seg, s, o, type, why));
        }
      } else if (op.o != null) {
        final o = orig[op.o!];
        segTokens[seg].add(Token(o, 'missing', ''));
        mistakes.add(Mistake(seg, '', o, 'palavra faltando', 'Faltou escrever "${bare(o)}".'));
      } else {
        final s = stud[op.s!];
        segTokens[seg].add(Token(s, 'extra', ''));
        mistakes.add(Mistake(seg, s, '', 'palavra a mais', '"${bare(s)}" não está no texto original.'));
      }
    }

    final segments = [
      for (var i = 0; i < segCount; i++)
        Segment([for (var j = 0; j < orig.length; j++) if (segOf[j] == i) orig[j]].join(' '),
            segTokens[i]),
    ];
    for (final m in mistakes) {
      segments[m.segment].mistakes.add(m);
    }
    return Correction(
      originalText: orig.join(' '),
      studentText: stud.join(' '),
      segments: segments,
      mistakes: mistakes,
      score: Correction.scoreFor(mistakes, orig.length),
      notes: '',
    );
  }

  /// Splits the original into short phrases, the way a teacher dictates:
  /// at punctuation, and never more than 8 words.
  static List<int> _segmentIndex(List<String> orig) {
    final seg = <int>[];
    var current = 0, len = 0;
    for (var i = 0; i < orig.length; i++) {
      seg.add(current);
      len++;
      final endsPhrase = RegExp(r'[.,;:!?)"]$').hasMatch(orig[i]);
      final remaining = orig.length - i - 1;
      if (remaining > 0 && ((endsPhrase && len >= 2 && remaining >= 2) || len >= 8)) {
        current++;
        len = 0;
      }
    }
    return seg;
  }

  /// Picks the stretch of the book page that best matches the student's copy,
  /// so headings or other exercises on the photo are left out.
  static String trimToMatch(String original, String student) {
    final orig = words(original);
    final stud = words(student);
    if (orig.isEmpty || stud.isEmpty) return original.trim();
    final ops = align(orig, stud, freeEnds: true);
    final matched = [
      for (final op in ops)
        if (op.o != null && op.s != null && _subCost(orig[op.o!], stud[op.s!]) < 1) op.o!
    ];
    if (matched.isEmpty) return orig.join(' ');
    return orig.sublist(matched.first, matched.last + 1).join(' ');
  }

  static double _subCost(String o, String s) {
    if (o == s) return 0;
    final bo = bare(o), bs = bare(s);
    if (bo == bs) return .3; // only capitals or punctuation differ
    final sim = similarity(bo, bs);
    if (sim >= .5 || _homophone(bo, bs)) return 1 - sim * .4;
    return 2.5; // unrelated words: better to call it missing + extra
  }

  /// Word-level alignment with costs: equal 0, small differences < 1,
  /// missing/extra 1. With [freeEnds], skipping the start or end of the
  /// original costs nothing.
  static List<AlignOp> align(List<String> orig, List<String> stud, {bool freeEnds = false}) {
    final n = orig.length, m = stud.length;
    final d = List.generate(n + 1, (_) => List<double>.filled(m + 1, 0));
    for (var i = 1; i <= n; i++) {
      d[i][0] = freeEnds ? 0 : i.toDouble();
    }
    for (var j = 1; j <= m; j++) {
      d[0][j] = j.toDouble();
    }
    for (var i = 1; i <= n; i++) {
      for (var j = 1; j <= m; j++) {
        final sub = d[i - 1][j - 1] + _subCost(orig[i - 1], stud[j - 1]);
        final del = d[i - 1][j] + 1;
        final ins = d[i][j - 1] + 1;
        d[i][j] = sub < del ? (sub < ins ? sub : ins) : (del < ins ? del : ins);
      }
    }
    var i = n, j = m;
    final ops = <AlignOp>[];
    if (freeEnds) {
      var best = n;
      for (var k = 0; k <= n; k++) {
        if (d[k][m] < d[best][m]) best = k;
      }
      for (var k = n; k > best; k--) {
        ops.add(AlignOp(k - 1, null));
      }
      i = best;
    }
    while (i > 0 || j > 0) {
      if (i > 0 && j > 0 &&
          (d[i][j] - (d[i - 1][j - 1] + _subCost(orig[i - 1], stud[j - 1]))).abs() < 1e-9) {
        ops.add(AlignOp(i - 1, j - 1));
        i--;
        j--;
      } else if (i > 0 && (d[i][j] - (d[i - 1][j] + (freeEnds && j == 0 ? 0 : 1))).abs() < 1e-9) {
        ops.add(AlignOp(i - 1, null));
        i--;
      } else {
        ops.add(AlignOp(null, j - 1));
        j--;
      }
    }
    return ops.reversed.toList();
  }

  static int _lev(String a, String b) {
    final prev = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      var diag = prev[0];
      prev[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final tmp = prev[j];
        final best = prev[j] + 1 < prev[j - 1] + 1 ? prev[j] + 1 : prev[j - 1] + 1;
        final sub = diag + (a[i - 1] == b[j - 1] ? 0 : 1);
        prev[j] = best < sub ? best : sub;
        diag = tmp;
      }
    }
    return prev[b.length];
  }

  static double similarity(String a, String b) {
    if (a.isEmpty && b.isEmpty) return 1;
    final longest = a.length > b.length ? a.length : b.length;
    return 1 - _lev(a, b) / longest;
  }

  static const _homophoneGroups = [
    ['there', 'their', "they're"], ['your', "you're"], ['its', "it's"],
    ['to', 'too', 'two'], ['where', 'wear', 'were'], ['here', 'hear'],
    ['know', 'no'], ['knew', 'new'], ['write', 'right'], ['whose', "who's"],
    ['then', 'than'], ['buy', 'by', 'bye'], ['see', 'sea'], ['for', 'four'],
    ['which', 'witch'], ['weather', 'whether'], ['piece', 'peace'],
    ['hole', 'whole'], ['our', 'hour'], ['son', 'sun'], ['one', 'won'],
    ['eight', 'ate'], ['meet', 'meat'], ['week', 'weak'], ['road', 'rode'],
    ['made', 'maid'], ['wait', 'weight'], ['would', 'wood'], ['flower', 'flour'],
    ['allowed', 'aloud'], ['brake', 'break'], ['mail', 'male'], ['pair', 'pear'],
    ['sale', 'sail'], ['tail', 'tale'], ['through', 'threw'], ['an', 'and'],
    ['of', 'off'],
  ];

  static bool _homophone(String a, String b) =>
      _homophoneGroups.any((g) => g.contains(a) && g.contains(b));

  /// Names the kind of mistake and explains it in a short sentence.
  static (String, String) explain(String written, String correct) {
    final w = _noPunct(written), c = _noPunct(correct);
    if (w == c) {
      return ('pontuação', 'A pontuação certa é "$correct".');
    }
    if (w.toLowerCase() == c.toLowerCase()) {
      final upper = c.isNotEmpty && c[0] == c[0].toUpperCase();
      return (
        'maiúscula',
        upper ? '"$c" começa com letra maiúscula.' : '"$c" se escreve com letra minúscula.',
      );
    }
    final bw = w.toLowerCase(), bc = c.toLowerCase();
    if (_homophone(bw, bc)) {
      return ('homófono', '"$bc" e "$bw" soam parecido, mas aqui o certo é "$bc".');
    }
    if ('${bw}s' == bc || '${bw}es' == bc) {
      return ('gramática', 'É plural: "$bc".');
    }
    if ('${bc}s' == bw || '${bc}es' == bw) {
      return ('gramática', 'É singular: "$bc", sem o "s".');
    }
    return ('ortografia', _spellingHint(bw, bc));
  }

  static String _spellingHint(String w, String c) {
    if (w.length == c.length) {
      final diffs = [for (var i = 0; i < c.length; i++) if (w[i] != c[i]) i];
      if (diffs.length == 2 && diffs[1] == diffs[0] + 1 &&
          w[diffs[0]] == c[diffs[1]] && w[diffs[1]] == c[diffs[0]]) {
        return 'Letras trocadas de lugar: o certo é "$c".';
      }
      if (diffs.length == 1) {
        return 'Trocou "${w[diffs[0]]}" por "${c[diffs[0]]}": o certo é "$c".';
      }
    }
    if (w.length + 1 == c.length) {
      for (var i = 0; i < c.length; i++) {
        if (c.substring(0, i) + c.substring(i + 1) == w) {
          final l = c[i];
          final doubled = (i > 0 && c[i - 1] == l) || (i + 1 < c.length && c[i + 1] == l);
          return doubled ? 'O "$l" é dobrado: "$c".' : 'Faltou a letra "$l": "$c".';
        }
      }
    }
    if (w.length == c.length + 1) {
      for (var i = 0; i < w.length; i++) {
        if (w.substring(0, i) + w.substring(i + 1) == c) {
          final l = w[i];
          final doubled = (i > 0 && w[i - 1] == l) || (i + 1 < w.length && w[i + 1] == l);
          return doubled ? 'O "$l" não é dobrado: "$c".' : 'Sobrou a letra "$l": "$c".';
        }
      }
    }
    return 'A grafia certa é "$c".';
  }

  /// "Dictation 59" (or "Dictation No. 59") printed on the book page.
  static int? dictationNumber(String pageText) {
    final m = RegExp(r'dictation\s*(?:n[oº°]\.?\s*)?(\d{1,3})', caseSensitive: false)
        .firstMatch(pageText);
    return m == null ? null : int.tryParse(m.group(1)!);
  }
}

class AlignOp {
  AlignOp(this.o, this.s);
  final int? o; // index in the original, null for an extra word
  final int? s; // index in the student's copy, null for a missing word
}
