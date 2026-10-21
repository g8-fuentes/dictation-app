import 'package:flutter/material.dart';

import '../settings.dart';
import '../theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.settings});

  final AppSettings settings;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final _key = TextEditingController(text: widget.settings.apiKey);
  bool _show = false;

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
        actions: [ThemeToggleButton(onToggle: s.toggleTheme)],
      ),
      body: ListenableBuilder(
        listenable: s,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Chave da API do Gemini', style: text.titleMedium),
            const SizedBox(height: 4),
            Text('Grátis em aistudio.google.com/apikey. Ela fica salva só neste celular.',
                style: text.bodySmall),
            const SizedBox(height: 12),
            TextField(
              controller: _key,
              obscureText: !_show,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: 'Cole a chave aqui',
                suffixIcon: IconButton(
                  icon: Icon(_show ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _show = !_show),
                ),
              ),
              onChanged: s.setApiKey,
            ),
            const SizedBox(height: 8),
            const SizedBox(height: 20),
            Text('Voz da narração', style: text.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Britânica')),
                ButtonSegment(value: false, label: Text('Americana')),
              ],
              selected: {s.britishVoice},
              onSelectionChanged: (v) => s.setBritishVoice(v.first),
            ),
            const SizedBox(height: 20),
            Text('Velocidade da voz', style: text.titleMedium),
            Slider(
              value: s.speechRate,
              min: 0.2,
              max: 0.7,
              divisions: 10,
              label: s.speechRate < 0.35
                  ? 'Lenta'
                  : s.speechRate > 0.5
                      ? 'Rápida'
                      : 'Normal',
              onChanged: s.setSpeechRate,
            ),
          ],
        ),
      ),
    );
  }
}
