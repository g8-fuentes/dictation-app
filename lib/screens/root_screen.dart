import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';
import 'correct_tab.dart';
import 'listen_tab.dart';
import 'progress_tab.dart';
import 'pronunciation_tab.dart';
import 'settings_screen.dart';

class RootScreen extends StatefulWidget {
  const RootScreen({super.key, required this.app});

  final AppState app;

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _tab = 0;
  static const _titles = ['Corrigir', 'Progresso', 'Ouvir', 'Pronúncia'];

  void _go(int i) {
    widget.app.speaker.stop();
    setState(() => _tab = i);
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_tab]),
        actions: [
          ThemeToggleButton(onToggle: app.settings.toggleTheme),
          IconButton(
            tooltip: 'Configurações',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => SettingsScreen(settings: app.settings))),
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          CorrectTab(app: app, onOpenProgress: () => _go(1)),
          ProgressTab(app: app),
          ListenTab(app: app),
          PronunciationTab(app: app),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _go,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.fact_check_outlined), label: 'Corrigir'),
          NavigationDestination(icon: Icon(Icons.show_chart), label: 'Progresso'),
          NavigationDestination(icon: Icon(Icons.headphones_outlined), label: 'Ouvir'),
          NavigationDestination(icon: Icon(Icons.mic_none), label: 'Pronúncia'),
        ],
      ),
    );
  }
}
