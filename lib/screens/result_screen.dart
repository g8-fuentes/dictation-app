import 'package:flutter/material.dart';

import '../app_state.dart';
import '../checker.dart';
import '../models.dart';
import '../theme.dart';
import '../tts.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key, required this.app, required this.record});

  final AppState app;
  final DictationRecord record;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  Correction get _result => widget.record.correction;
  Speaker get _speaker => widget.app.speaker;
  late final _keys = List.generate(_result.segments.length, (_) => GlobalKey());
  bool _playing = false;
  bool _withPauses = true;
  bool _slow = false;
  int _current = -1;
  String? _word; // "segment:index" of the word being spoken

  double get _rate =>
      _slow ? widget.app.settings.speechRate * .7 : widget.app.settings.speechRate;

  @override
  void dispose() {
    _speaker.stop();
    super.dispose();
  }

  Future<void> _markCorrect(Mistake m) async {
    setState(() => _result.markCorrect(m));
    await widget.app.history.save();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Marcado como certo. Nova nota: ${_result.score}')));
  }

  Future<void> _togglePlay() async {
    if (_playing) {
      await _speaker.stop();
      setState(() {
        _playing = false;
        _current = -1;
      });
      return;
    }
    setState(() {
      _playing = true;
      _word = null;
    });
    await _speaker.dictate(
      [for (final s in _result.segments) s.original],
      pause: _withPauses ? const Duration(milliseconds: 2500) : const Duration(milliseconds: 350),
      rate: _rate,
      onPart: (i) {
        if (!mounted) return;
        setState(() {
          _current = i;
          if (i < 0) _playing = false;
        });
        if (i >= 0) {
          final ctx = _keys[i].currentContext;
          if (ctx != null) {
            Scrollable.ensureVisible(ctx,
                alignment: .3, duration: const Duration(milliseconds: 350));
          }
        }
      },
    );
  }

  Future<void> _sayWord(int seg, int i, String word) async {
    setState(() {
      _playing = false;
      _current = -1;
      _word = '$seg:$i';
    });
    await _speaker.say(Checker.bare(word), rate: _rate);
    if (mounted && _word == '$seg:$i') setState(() => _word = null);
  }

  Future<void> _saySegment(int seg) async {
    setState(() {
      _playing = false;
      _word = null;
      _current = seg;
    });
    await _speaker.say(_result.segments[seg].original, rate: _rate);
    if (mounted && _current == seg && !_playing) setState(() => _current = -1);
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.record.title),
        actions: [ThemeToggleButton(onToggle: widget.app.settings.toggleTheme)],
      ),
      // The play button scrolls away while the reading follows the text, so
      // keep a stop button on screen.
      floatingActionButton: _playing
          ? FloatingActionButton.extended(
              key: const ValueKey('stop-fab'),
              onPressed: _togglePlay,
              icon: const Icon(Icons.stop),
              label: Text(_current >= 0 ? 'Parar · trecho ${_current + 1}' : 'Parar'),
            )
          : null,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            _Summary(result: r),
            const SizedBox(height: 16),
            _narrationCard(scheme, text),
            const SizedBox(height: 24),
            Text('A dictation, trecho por trecho', style: text.titleLarge),
            const SizedBox(height: 6),
            const _Legend(),
            const SizedBox(height: 12),
            for (var i = 0; i < r.segments.length; i++) ...[
              _SegmentCard(
                key: _keys[i],
                index: i,
                segment: r.segments[i],
                highlighted: _current == i,
                activeWord: _word,
                onPlay: () => _saySegment(i),
                onWord: (w, word) => _sayWord(i, w, word),
                onMarkCorrect: _markCorrect,
              ),
              const SizedBox(height: 12),
            ],
            if (r.notes.trim().isNotEmpty) ...[
              Text(r.notes, style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 12),
            ],
            Card(
              clipBehavior: Clip.antiAlias,
              child: ExpansionTile(
                title: const Text('Ver textos completos'),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                shape: const Border(),
                children: [
                  Text('Original', style: text.labelLarge),
                  const SizedBox(height: 4),
                  SelectableText(r.originalText),
                  const SizedBox(height: 12),
                  Text('Como o aluno escreveu', style: text.labelLarge),
                  const SizedBox(height: 4),
                  SelectableText(r.studentText),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.check),
              label: const Text('Concluir'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _narrationCard(ColorScheme scheme, TextTheme text) {
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Icon(Icons.record_voice_over_outlined, color: scheme.onPrimaryContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Ouvir a dictation',
                    style: text.titleMedium?.copyWith(color: scheme.onPrimaryContainer)),
              ),
            ]),
            const SizedBox(height: 4),
            Text(
              _withPauses
                  ? 'Lida trecho por trecho, com pausa para o aluno escrever.'
                  : 'Lida do começo ao fim, sem pausas.',
              style: text.bodyMedium?.copyWith(color: scheme.onPrimaryContainer),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilterChip(
                label: const Text('Com pausas'),
                selected: _withPauses,
                onSelected: _playing ? null : (v) => setState(() => _withPauses = v),
              ),
              FilterChip(
                label: const Text('Devagar'),
                selected: _slow,
                onSelected: _playing ? null : (v) => setState(() => _slow = v),
              ),
            ]),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: _togglePlay,
              icon: Icon(_playing ? Icons.stop : Icons.play_arrow),
              label: Text(_playing
                  ? (_current >= 0 ? 'Parar (trecho ${_current + 1})' : 'Parar')
                  : 'Tocar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.result});

  final Correction result;

  @override
  Widget build(BuildContext context) {
    final marks = Marks.of(context);
    final n = result.mistakes.length;
    return Row(children: [
      Expanded(child: _Stat(value: result.score.isEmpty ? '–' : result.score, label: 'nota')),
      const SizedBox(width: 8),
      Expanded(
        child: _Stat(
          value: '$n',
          label: n == 1 ? 'erro' : 'erros',
          color: n == 0 ? marks.right : marks.wrong,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(child: _Stat(value: '${result.wordsWritten}', label: 'palavras')),
    ]);
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.color});

  final String value, label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(children: [
          Text(value,
              style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800, color: color)),
          Text(label.toUpperCase(),
              style: text.labelSmall?.copyWith(letterSpacing: 1)),
        ]),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final m = Marks.of(context);
    final small = Theme.of(context).textTheme.bodySmall;
    return Wrap(spacing: 14, runSpacing: 4, children: [
      Text.rich(TextSpan(style: small, children: [
        TextSpan(
            text: 'riscado',
            style: TextStyle(color: m.wrong, decoration: TextDecoration.lineThrough)),
        const TextSpan(text: ' = errado'),
      ])),
      Text.rich(TextSpan(style: small, children: [
        TextSpan(text: 'verde', style: TextStyle(color: m.right, fontWeight: FontWeight.bold)),
        const TextSpan(text: ' = forma correta'),
      ])),
      Text.rich(TextSpan(style: small, children: [
        TextSpan(text: '^palavra', style: TextStyle(color: m.right, fontWeight: FontWeight.bold)),
        const TextSpan(text: ' = faltou'),
      ])),
    ]);
  }
}

class _SegmentCard extends StatelessWidget {
  const _SegmentCard({
    super.key,
    required this.index,
    required this.segment,
    required this.highlighted,
    required this.activeWord,
    required this.onPlay,
    required this.onWord,
    required this.onMarkCorrect,
  });

  final int index;
  final Segment segment;
  final bool highlighted;
  final String? activeWord;
  final VoidCallback onPlay;
  final void Function(int i, String word) onWord;
  final ValueChanged<Mistake> onMarkCorrect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final m = Marks.of(context);
    final words = segment.original.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final nErr = segment.tokens.where((t) => t.status != 'ok').length;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: highlighted ? scheme.secondaryContainer : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlighted ? scheme.primary : scheme.outlineVariant,
          width: highlighted ? 2 : 1,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            CircleAvatar(
              radius: 13,
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              child: Text('${index + 1}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 10),
            _Badge(
              text: nErr == 0 ? 'Correto' : (nErr == 1 ? '1 erro' : '$nErr erros'),
              fg: nErr == 0 ? m.right : m.wrong,
              bg: nErr == 0 ? m.rightBg : m.wrongBg,
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Ouvir este trecho',
              icon: const Icon(Icons.volume_up_outlined),
              onPressed: onPlay,
            ),
          ]),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ORIGINAL', style: text.labelSmall?.copyWith(letterSpacing: 1)),
                const SizedBox(height: 4),
                Wrap(children: [
                  for (var i = 0; i < words.length; i++)
                    _TapWord(
                      word: words[i],
                      active: activeWord == '$index:$i',
                      onTap: () => onWord(i, words[i]),
                    ),
                ]),
                const SizedBox(height: 12),
                Text('ALUNO ESCREVEU', style: text.labelSmall?.copyWith(letterSpacing: 1)),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(children: _studentSpans(m, text)),
                  style: text.titleMedium?.copyWith(height: 1.6),
                ),
                for (final e in segment.mistakes) ...[
                  const SizedBox(height: 10),
                  _MistakeRow(mistake: e, onMarkCorrect: () => onMarkCorrect(e)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<InlineSpan> _studentSpans(Marks m, TextTheme text) {
    final spans = <InlineSpan>[];
    for (final t in segment.tokens) {
      if (spans.isNotEmpty) spans.add(const TextSpan(text: ' '));
      switch (t.status) {
        case 'wrong':
          spans.add(TextSpan(
            text: t.text,
            style: TextStyle(
              color: m.wrong,
              decoration: TextDecoration.lineThrough,
              decorationColor: m.wrong,
              decorationThickness: 2,
            ),
          ));
          spans.add(TextSpan(
            text: ' ${t.correct}',
            style: TextStyle(color: m.right, fontWeight: FontWeight.w800),
          ));
        case 'missing':
          spans.add(TextSpan(
            text: '^${t.text}',
            style: TextStyle(
              color: m.right,
              backgroundColor: m.rightBg,
              fontWeight: FontWeight.w800,
            ),
          ));
        case 'extra':
          spans.add(TextSpan(
            text: t.text,
            style: TextStyle(
              color: m.wrong,
              decoration: TextDecoration.lineThrough,
              decorationStyle: TextDecorationStyle.wavy,
              decorationColor: m.wrong,
            ),
          ));
        default:
          spans.add(TextSpan(text: t.text));
      }
    }
    return spans;
  }
}

class _TapWord extends StatelessWidget {
  const _TapWord({required this.word, required this.active, required this.onTap});

  final String word;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 2, bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
        decoration: BoxDecoration(
          color: active ? scheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          word,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: active ? scheme.onPrimary : null,
                decoration: TextDecoration.underline,
                decorationStyle: TextDecorationStyle.dotted,
                decorationColor: scheme.outline,
              ),
        ),
      ),
    );
  }
}

class _MistakeRow extends StatelessWidget {
  const _MistakeRow({required this.mistake, required this.onMarkCorrect});

  final Mistake mistake;
  final VoidCallback onMarkCorrect;

  @override
  Widget build(BuildContext context) {
    final m = Marks.of(context);
    final text = Theme.of(context).textTheme;
    final e = mistake;
    final punct = e.type.toLowerCase().contains('pontu');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Text.rich(TextSpan(style: text.bodyLarge, children: [
              if (e.written.isNotEmpty)
                TextSpan(
                  text: e.written,
                  style: TextStyle(
                      color: m.wrong,
                      decoration: TextDecoration.lineThrough,
                      decorationColor: m.wrong),
                ),
              if (e.written.isNotEmpty && e.correct.isNotEmpty) const TextSpan(text: '  →  '),
              if (e.correct.isNotEmpty)
                TextSpan(
                  text: e.written.isEmpty ? '+ ${e.correct}' : e.correct,
                  style: TextStyle(color: m.right, fontWeight: FontWeight.w800),
                ),
            ])),
            _Badge(
              text: e.type,
              fg: punct ? m.warn : m.wrong,
              bg: punct ? m.warnBg : m.wrongBg,
            ),
          ],
        ),
        if (e.why.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(e.why, style: text.bodyMedium),
        ],
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onMarkCorrect,
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: const Text('Marcar como certo'),
          ),
        ),
      ]),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.fg, required this.bg});

  final String text;
  final Color fg, bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: .6),
      ),
    );
  }
}
