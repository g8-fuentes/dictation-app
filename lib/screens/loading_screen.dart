import 'dart:math';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../checker.dart';
import '../models.dart';
import 'photo_slot.dart';
import 'result_screen.dart';

/// Reads both photos on the device, corrects the copy, saves it to the
/// history and opens the result.
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key, required this.app, required this.original, required this.student});

  final AppState app;
  final Photo original;
  final Photo student;

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final reader = widget.app.reader;
    String page, copy;
    try {
      (page, copy) = await (
        reader.read(widget.original.path),
        reader.read(widget.student.path),
      ).wait;
    } catch (_) {
      _fail('Não consegui ler as fotos. Tente fotos mais nítidas e retas.');
      return;
    }
    if (Checker.words(page).isEmpty) {
      _fail('Não encontrei texto na foto do livro. Tente uma foto mais nítida.');
      return;
    }
    if (Checker.words(copy).isEmpty) {
      _fail('Não encontrei texto na foto do aluno. Tente uma foto mais nítida.');
      return;
    }
    final correction = Checker.check(Checker.trimToMatch(page, copy), copy);
    final record = DictationRecord(
      id: '${DateTime.now().microsecondsSinceEpoch}${Random().nextInt(999)}',
      date: DateTime.now(),
      number: Checker.dictationNumber(page),
      correction: correction,
    );
    await widget.app.history.add(record);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => ResultScreen(app: widget.app, record: record),
    ));
  }

  void _fail(String message) {
    if (mounted) Navigator.of(context).pop(message);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(width: 56, height: 56, child: CircularProgressIndicator(strokeWidth: 5)),
          const SizedBox(height: 24),
          Text('Analisando…', style: text.titleMedium),
        ]),
      ),
    );
  }
}
