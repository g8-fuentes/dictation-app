import 'package:flutter/material.dart';

import '../app_state.dart';
import '../checker.dart';
import '../models.dart';
import '../pronunciation.dart';
import '../theme.dart';
import 'photo_slot.dart';
import 'progress_tab.dart' show formatDate;

/// The student reads a dictation aloud; words the phone heard differently
/// are flagged to practise.
class PronunciationTab extends StatefulWidget {
  const PronunciationTab({super.key, required this.app});

  final AppState app;

  @override
  State<PronunciationTab> createState() => _PronunciationTabState();
}

class _PronunciationTabState extends State<PronunciationTab> {
  /// Id of the dictation chosen from the history; null means the latest one,
  /// unless [_usePhoto].
  String? _sourceId;
  bool _usePhoto = false;
  Photo? _photo;
  String? _photoText;
  bool _readingPhoto = false;

  bool _recording = false;
  String _heard = '';
  List<SpokenWord>? _result;
  int? _playingWord;

  bool get _fromPhoto => _usePhoto || widget.app.history.records.isEmpty;

  DictationRecord? get _record {
    if (_fromPhoto) return null;
    final records = widget.app.history.records;
    return records.where((r) => r.id == _sourceId).firstOrNull ?? records.firstOrNull;
  }

  String? get _text => _fromPhoto ? _photoText : _record?.correction.originalText;

  Future<void> _setPhoto(Photo p) async {
    setState(() {
      _photo = p;
      _photoText = null;
      _readingPhoto = true;
      _result = null;
    });
    String text;
    try {
      text = await widget.app.reader.read(p.path);
    } catch (_) {
      text = '';
    }
    if (mounted) {
      setState(() {
        _readingPhoto = false;
        _photoText = text;
      });
    }
  }

  Future<void> _toggleRecord() async {
    final speech = widget.app.speech;
    if (_recording) {
      final heard = await speech.stop();
      if (!mounted) return;
      setState(() {
        _recording = false;
        _heard = heard;
        _result = Pronunciation.compare(_text!, heard);
      });
      return;
    }
    await widget.app.speaker.stop();
    if (!await speech.init()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Não consegui usar o microfone. Permita o acesso ao microfone e tente de novo.'),
      ));
      return;
    }
    setState(() {
      _recording = true;
      _heard = '';
      _result = null;
    });
    await speech.start((t) {
      if (mounted) setState(() => _heard = t);
    });
  }

  Future<void> _say(int i, String word) async {
    setState(() => _playingWord = i);
    await widget.app.speaker.say(Checker.bare(word));
    if (mounted && _playingWord == i) setState(() => _playingWord = null);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: widget.app.history, builder: (context, _) => _build(context));
  }

  Widget _build(BuildContext context) {
    final records = widget.app.history.records;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final source = _text;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text('O que você vai ler', style: text.titleMedium),
        const SizedBox(height: 8),
        DropdownButtonFormField<String?>(
          key: ValueKey('source-${_record?.id}-$_fromPhoto'),
          initialValue: _record?.id,
          isExpanded: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: [
            for (final r in records)
              DropdownMenuItem(value: r.id, child: Text('${r.title} · ${formatDate(r.date)}')),
            const DropdownMenuItem(value: null, child: Text('Foto de um texto')),
          ],
          onChanged: _recording
              ? null
              : (v) => setState(() {
                    _usePhoto = v == null;
                    _sourceId = v;
                    _result = null;
                    _heard = '';
                  }),
        ),
        const SizedBox(height: 12),
        if (_fromPhoto)
          PhotoSlot(
            step: null,
            title: 'Texto para ler',
            hint: 'Foto do texto em inglês',
            photo: _photo,
            onPicked: _setPhoto,
            onClear: () => setState(() {
              _photo = null;
              _photoText = null;
              _result = null;
            }),
          ),
        if (_readingPhoto)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (source != null && source.isNotEmpty && _result == null) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(source, style: text.titleMedium?.copyWith(height: 1.6)),
            ),
          ),
        ],
        if (source != null && source.isNotEmpty) ...[
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const ValueKey('record'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              backgroundColor: _recording ? scheme.error : null,
              foregroundColor: _recording ? scheme.onError : null,
            ),
            onPressed: _toggleRecord,
            icon: Icon(_recording ? Icons.stop : Icons.mic),
            label: Text(_recording ? 'Parar e avaliar' : (_result == null ? 'Gravar minha leitura' : 'Gravar de novo')),
          ),
          if (_recording) ...[
            const SizedBox(height: 12),
            Text(_heard.isEmpty ? 'Pode começar a ler em voz alta…' : _heard,
                style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant)),
          ],
        ],
        if (_fromPhoto && _photoText != null && _photoText!.isEmpty)
          Text('Não encontrei texto nessa foto.', style: TextStyle(color: scheme.error)),
        if (records.isEmpty && _photo == null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Depois que você corrigir dictations, elas aparecem na lista acima.',
                style: text.bodySmall),
          ),
        if (_result != null) ...[
          const SizedBox(height: 20),
          _ResultView(
            words: _result!,
            heardNothing: _heard.trim().isEmpty,
            playing: _playingWord,
            onWord: _say,
          ),
        ],
      ],
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.words,
    required this.heardNothing,
    required this.playing,
    required this.onWord,
  });

  final List<SpokenWord> words;
  final bool heardNothing;
  final int? playing;
  final void Function(int i, String word) onWord;

  @override
  Widget build(BuildContext context) {
    final m = Marks.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    if (heardNothing) {
      return Text('Não ouvi nada. Fale mais perto do celular e tente de novo.',
          style: TextStyle(color: scheme.error));
    }
    final review = words.where((w) => w.status == 'review').length;
    final skipped = words.where((w) => w.status == 'skipped').length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('${Pronunciation.score(words)}%',
                style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                review + skipped == 0
                    ? 'Todas as palavras foram entendidas.'
                    : '$review para revisar${skipped > 0 ? ', $skipped não ouvidas' : ''}',
                style: text.bodyMedium,
              ),
            ),
          ]),
          const SizedBox(height: 4),
          Text('Toque numa palavra para ouvir a pronúncia certa.',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          Wrap(spacing: 4, runSpacing: 6, children: [
            for (var i = 0; i < words.length; i++)
              _Word(
                word: words[i],
                active: playing == i,
                color: switch (words[i].status) {
                  'review' => (m.wrong, m.wrongBg),
                  'skipped' => (scheme.onSurfaceVariant, scheme.surfaceContainerHighest),
                  _ => (m.right, Colors.transparent),
                },
                onTap: () => onWord(i, words[i].word),
              ),
          ]),
          if (review > 0) ...[
            const SizedBox(height: 16),
            Text('O celular entendeu:', style: text.labelLarge),
            const SizedBox(height: 4),
            for (final w in words.where((w) => w.status == 'review'))
              Text('• ${Checker.bare(w.word)} → "${w.heard}"', style: text.bodyMedium),
          ],
        ]),
      ),
    );
  }
}

class _Word extends StatelessWidget {
  const _Word({required this.word, required this.active, required this.color, required this.onTap});

  final SpokenWord word;
  final bool active;
  final (Color, Color) color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: active ? scheme.primary : color.$2,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          word.word,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: active ? scheme.onPrimary : color.$1,
                fontWeight: word.status == 'ok' ? FontWeight.w500 : FontWeight.w800,
                decoration: word.status == 'skipped' ? TextDecoration.lineThrough : null,
              ),
        ),
      ),
    );
  }
}
