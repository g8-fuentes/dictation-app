import 'package:flutter/material.dart';

import '../app_state.dart';
import 'photo_slot.dart';

/// Photo of any text, read aloud at once in a native English voice.
class ListenTab extends StatefulWidget {
  const ListenTab({super.key, required this.app});

  final AppState app;

  @override
  State<ListenTab> createState() => _ListenTabState();
}

class _ListenTabState extends State<ListenTab> {
  Photo? _photo;
  String? _text;
  bool _reading = false;
  bool _playing = false;
  bool _slow = false;

  Future<void> _set(Photo p) async {
    await widget.app.speaker.stop();
    setState(() {
      _photo = p;
      _text = null;
      _reading = true;
      _playing = false;
    });
    String text;
    try {
      text = await widget.app.reader.read(p.path);
    } catch (_) {
      text = '';
    }
    if (!mounted) return;
    setState(() {
      _reading = false;
      _text = text;
    });
    if (text.isNotEmpty) _play();
  }

  Future<void> _play() async {
    if (_playing) {
      await widget.app.speaker.stop();
      setState(() => _playing = false);
      return;
    }
    setState(() => _playing = true);
    final rate = widget.app.settings.speechRate * (_slow ? .7 : 1);
    await widget.app.speaker.say(_text!, rate: rate);
    if (mounted) setState(() => _playing = false);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        PhotoSlot(
          step: null,
          title: 'Texto para ouvir',
          hint: 'Foto de qualquer texto em inglês',
          photo: _photo,
          onPicked: _set,
          onClear: () {
            widget.app.speaker.stop();
            setState(() {
              _photo = null;
              _text = null;
              _playing = false;
            });
          },
        ),
        const SizedBox(height: 16),
        if (_reading)
          const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
        else if (_text != null && _text!.isEmpty)
          Text('Não encontrei texto nessa foto. Tente uma foto mais nítida.',
              style: TextStyle(color: scheme.error))
        else if (_text != null) ...[
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                key: const ValueKey('listen-play'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                onPressed: _play,
                icon: Icon(_playing ? Icons.stop : Icons.play_arrow),
                label: Text(_playing ? 'Parar' : 'Ouvir o texto'),
              ),
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: const Text('Devagar'),
              selected: _slow,
              onSelected: _playing ? null : (v) => setState(() => _slow = v),
            ),
          ]),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SelectableText(_text!, style: text.titleMedium?.copyWith(height: 1.6)),
            ),
          ),
        ],
      ],
    );
  }
}
