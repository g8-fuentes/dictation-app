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
