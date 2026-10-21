import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import 'result_screen.dart';

String formatDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// The course so far: every corrected dictation, with the score trend.
class ProgressTab extends StatelessWidget {
  const ProgressTab({super.key, required this.app});

  final AppState app;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app.history,
      builder: (context, _) {
        final records = app.history.records;
        if (records.isEmpty) return const _Empty();
        final scores = [for (final r in records.reversed) r.scoreValue].whereType<double>().toList();
        final avg = scores.isEmpty ? 0 : scores.reduce((a, b) => a + b) / scores.length;
        final best = scores.isEmpty ? 0 : scores.reduce((a, b) => a > b ? a : b);
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Row(children: [
              Expanded(child: _Stat(value: '${records.length}', label: 'dictations')),
              const SizedBox(width: 8),
              Expanded(child: _Stat(value: avg.toStringAsFixed(1), label: 'média')),
              const SizedBox(width: 8),
              Expanded(child: _Stat(value: best.toStringAsFixed(1), label: 'melhor')),
            ]),
            if (scores.length >= 2) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Notas ao longo do curso', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 140,
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: _ScoreChart(
                          scores.length > 20 ? scores.sublist(scores.length - 20) : scores,
                          Theme.of(context).colorScheme,
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text('Histórico', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final r in records) ...[
              _RecordTile(app: app, record: r),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.show_chart, size: 56, color: scheme.outline),
          const SizedBox(height: 12),
          Text('Nenhuma dictation corrigida ainda.',
              style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text('Cada correção fica salva aqui, com a nota.',
              style: TextStyle(color: scheme.onSurfaceVariant), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.app, required this.record});

  final AppState app;
  final DictationRecord record;

  Future<bool> _confirmDelete(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Apagar ${record.title}?'),
            content: const Text('A correção sai do histórico.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Apagar')),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final m = Marks.of(context);
    final n = record.correction.mistakes.length;
    return Dismissible(
      key: ValueKey(record.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) => app.history.remove(record),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: m.wrongBg, borderRadius: BorderRadius.circular(16)),
        child: Icon(Icons.delete_outline, color: m.wrong),
      ),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          title: Text(record.title),
          subtitle: Text('${formatDate(record.date)} · ${n == 0 ? 'sem erros' : n == 1 ? '1 erro' : '$n erros'}'),
          trailing: Text(
            record.correction.score,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: (record.scoreValue ?? 0) >= 7 ? m.right : m.wrong,
                ),
          ),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ResultScreen(app: app, record: record),
          )),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value, label;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(children: [
          Text(value, style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
          Text(label.toUpperCase(), style: text.labelSmall?.copyWith(letterSpacing: 1)),
        ]),
      ),
    );
  }
}

/// Scores (0–10) in course order as a line with dots.
class _ScoreChart extends CustomPainter {
  _ScoreChart(this.scores, this.scheme);

  final List<double> scores;
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 22.0;
    final w = size.width - left, h = size.height;
    final grid = Paint()
      ..color = scheme.outlineVariant
      ..strokeWidth = 1;
    final label = TextStyle(color: scheme.onSurfaceVariant, fontSize: 11);
    for (final v in [0, 5, 10]) {
      final y = h - h * v / 10;
      canvas.drawLine(Offset(left, y), Offset(size.width, y), grid);
      final tp = TextPainter(text: TextSpan(text: '$v', style: label), textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, Offset(0, y - tp.height / 2));
    }
    Offset at(int i) => Offset(
          left + (scores.length == 1 ? w / 2 : w * i / (scores.length - 1)),
          h - h * scores[i].clamp(0, 10) / 10,
        );
    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < scores.length; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = scheme.primary
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );
    final dot = Paint()..color = scheme.primary;
    final ring = Paint()..color = scheme.surface;
    for (var i = 0; i < scores.length; i++) {
      canvas.drawCircle(at(i), 5, ring);
      canvas.drawCircle(at(i), 3.5, dot);
    }
  }

  @override
  bool shouldRepaint(_ScoreChart old) => old.scores != scores || old.scheme != scheme;
}
