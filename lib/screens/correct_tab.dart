import 'package:flutter/material.dart';

import '../app_state.dart';
import 'loading_screen.dart';
import 'photo_slot.dart';

class CorrectTab extends StatefulWidget {
  const CorrectTab({super.key, required this.app, required this.onOpenProgress});

  final AppState app;
  final VoidCallback onOpenProgress;

  @override
  State<CorrectTab> createState() => _CorrectTabState();
}

class _CorrectTabState extends State<CorrectTab> {
  Photo? _original;
  Photo? _student;

  @override
  void initState() {
    super.initState();
    recoverLostPhoto().then((p) {
      if (p != null && mounted) setState(() => _original == null ? _original = p : _student = p);
    });
  }

  Future<void> _analyse() async {
    final error = await Navigator.of(context).push<String>(MaterialPageRoute(
      builder: (_) => LoadingScreen(app: widget.app, original: _original!, student: _student!),
    ));
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error)));
    } else {
      // Done: start fresh for the next dictation.
      setState(() {
        _original = null;
        _student = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = _original != null && _student != null;
    return Column(children: [
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          children: [
            PhotoSlot(
              step: '1',
              title: 'Texto original',
              hint: 'Foto da página do livro com a dictation',
              photo: _original,
              onPicked: (p) => setState(() => _original = p),
              onClear: () => setState(() => _original = null),
            ),
            const SizedBox(height: 16),
            PhotoSlot(
              step: '2',
              title: 'Texto do aluno',
              hint: 'Foto do caderno com a letra do aluno',
              photo: _student,
              onPicked: (p) => setState(() => _student = p),
              onClear: () => setState(() => _student = null),
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: FilledButton.icon(
          key: const ValueKey('correct'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          onPressed: ready ? _analyse : null,
          icon: const Icon(Icons.fact_check_outlined),
          label: Text(ready ? 'Corrigir' : 'Adicione as duas fotos'),
        ),
      ),
    ]);
  }
}
