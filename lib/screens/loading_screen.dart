import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../claude_api.dart';
import '../settings.dart';
import '../tts.dart';
import 'result_screen.dart';
import 'word_chip.dart';

/// Runs the correction. While it works, the dictation's own words appear as
/// buttons the student can tap to hear each one.
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({
    super.key,
    required this.settings,
    required this.speaker,
    required this.original,
    required this.student,
    this.api,
  });

  final AppSettings settings;
  final Speaker speaker;
  final Uint8List original;
  final Uint8List student;

  /// Lets tests swap in a fake; the real one is built from settings.
  final ClaudeApi? api;

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> with SingleTickerProviderStateMixin {
  static const _steps = [
    'Lendo a página do livro…',
    'Lendo a letra do aluno…',
    'Comparando palavra por palavra…',
    'Separando a dictation em trechos…',
    'Preparando as explicações…',
  ];

  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat(reverse: true);
  late final Timer _ticker;
  int _step = 0;
  List<String>? _words;
  bool _wordsFailed = false;
  int? _playing;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) setState(() => _step = (_step + 1) % _steps.length);
    });
    final api = widget.api ?? ClaudeApi(widget.settings.apiKey, widget.settings.model);

    api.transcribeOriginal(widget.original).then((text) {
      final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
      if (mounted) setState(() => words.isEmpty ? _wordsFailed = true : _words = words);
    }, onError: (_) {
      if (mounted) setState(() => _wordsFailed = true);
    });

    api.correct(widget.original, widget.student).then((result) {
      if (!mounted) return;
      widget.speaker.stop();
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => ResultScreen(
          settings: widget.settings,
          speaker: widget.speaker,
          result: result,
        ),
      ));
    }, onError: (Object e) {
      if (!mounted) return;
      widget.speaker.stop();
      Navigator.of(context).pop(e is ClaudeError ? e.message : 'Algo deu errado. Tente de novo.');
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _tap(int i) async {
    setState(() => _playing = i);
    await widget.speaker.say(cleanWord(_words![i]));
    if (mounted && _playing == i) setState(() => _playing = null);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) widget.speaker.stop();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Analisando')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Center(
                child: ScaleTransition(
                  scale: Tween(begin: .9, end: 1.08)
                      .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: scheme.primaryContainer,
                    child: Icon(Icons.auto_stories_outlined,
                        size: 40, color: scheme.onPrimaryContainer),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: Text(
                  _steps[_step],
                  key: ValueKey(_step),
                  textAlign: TextAlign.center,
                  style: text.titleMedium,
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: const LinearProgressIndicator(minHeight: 6),
              ),
              const SizedBox(height: 6),
              Text('Pode levar até 1 minuto.',
                  textAlign: TextAlign.center,
                  style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 28),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    alignment: Alignment.topCenter,
                    child: _wordsPanel(scheme, text),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _wordsPanel(ColorScheme scheme, TextTheme text) {
    if (_words == null) {
      return Row(children: [
        if (!_wordsFailed) ...[
          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Text(
            _wordsFailed
                ? 'As palavras da dictation vão aparecer no resultado.'
                : 'Buscando as palavras da dictation…',
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.touch_app_outlined, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text('Enquanto isso, pratique', style: text.titleMedium)),
        ]),
        const SizedBox(height: 4),
        Text('Toque numa palavra da dictation para ouvir a pronúncia.',
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 14),
        Wrap(
          spacing: 6,
          runSpacing: 8,
          children: [
            for (var i = 0; i < _words!.length; i++)
              WordChip(
                word: _words![i],
                active: _playing == i,
                delay: Duration(milliseconds: 25 * i),
                onTap: () => _tap(i),
              ),
          ],
        ),
      ],
    );
  }
}
