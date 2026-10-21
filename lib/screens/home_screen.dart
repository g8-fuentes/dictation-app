import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../settings.dart';
import '../theme.dart';
import '../tts.dart';
import 'loading_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.settings, required this.speaker});

  final AppSettings settings;
  final Speaker speaker;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _picker = ImagePicker();
  Uint8List? _original;
  Uint8List? _student;

  Future<void> _pick(bool original, ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 85,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() => original ? _original = bytes : _student = bytes);
    } catch (_) {
      _snack('Não consegui abrir a foto. Tente de novo.');
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));

  void _openSettings() => Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SettingsScreen(settings: widget.settings)));

  Future<void> _analyse() async {
    if (!widget.settings.hasKey) {
      _snack('Coloque sua chave da API em Configurações.');
      _openSettings();
      return;
    }
    final error = await Navigator.of(context).push<String>(MaterialPageRoute(
      builder: (_) => LoadingScreen(
        settings: widget.settings,
        speaker: widget.speaker,
        original: _original!,
        student: _student!,
      ),
    ));
    if (error != null && mounted) _snack(error);
  }

  @override
  Widget build(BuildContext context) {
    final ready = _original != null && _student != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Corretor de Dictation'),
        actions: [
          ThemeToggleButton(onToggle: widget.settings.toggleTheme),
          IconButton(
            tooltip: 'Configurações',
            icon: const Icon(Icons.settings_outlined),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.settings,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              if (!widget.settings.hasKey) ...[
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.key_outlined),
                    title: const Text('Falta a chave da API'),
                    subtitle: const Text('Toque aqui para configurar antes de corrigir.'),
                    onTap: _openSettings,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              _PhotoSlot(
                step: '1',
                title: 'Texto original',
                hint: 'Foto da página do livro com a dictation',
                bytes: _original,
                onCamera: () => _pick(true, ImageSource.camera),
                onGallery: () => _pick(true, ImageSource.gallery),
                onClear: () => setState(() => _original = null),
              ),
              const SizedBox(height: 16),
              _PhotoSlot(
                step: '2',
                title: 'Texto do aluno',
                hint: 'Foto do caderno com a letra do aluno',
                bytes: _student,
                onCamera: () => _pick(false, ImageSource.camera),
                onGallery: () => _pick(false, ImageSource.gallery),
                onClear: () => setState(() => _student = null),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            onPressed: ready ? _analyse : null,
            icon: const Icon(Icons.fact_check_outlined),
            label: Text(ready ? 'Corrigir' : 'Adicione as duas fotos'),
          ),
        ),
      ),
    );
  }
}

class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({
    required this.step,
    required this.title,
    required this.hint,
    required this.bytes,
    required this.onCamera,
    required this.onGallery,
    required this.onClear,
  });

  final String step, title, hint;
  final Uint8List? bytes;
  final VoidCallback onCamera, onGallery, onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: bytes != null ? scheme.primary : scheme.secondaryContainer,
                foregroundColor: bytes != null ? scheme.onPrimary : scheme.onSecondaryContainer,
                child: bytes != null
                    ? const Icon(Icons.check, size: 16)
                    : Text(step, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: text.titleMedium)),
              if (bytes != null)
                IconButton(
                  tooltip: 'Remover foto',
                  icon: const Icon(Icons.close),
                  onPressed: onClear,
                ),
            ]),
            const SizedBox(height: 12),
            if (bytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: Image.memory(bytes!, fit: BoxFit.cover, width: double.infinity),
                ),
              )
            else
              Container(
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: scheme.outlineVariant, width: 1.5),
                  color: scheme.surfaceContainerHighest.withValues(alpha: .4),
                ),
                alignment: Alignment.center,
                padding: const EdgeInsets.all(12),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.image_outlined, color: scheme.onSurfaceVariant, size: 32),
                  const SizedBox(height: 6),
                  Text(hint,
                      textAlign: TextAlign.center,
                      style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                ]),
              ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: onCamera,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(bytes == null ? 'Tirar foto' : 'Tirar outra'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onGallery,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Galeria'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
