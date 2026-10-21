import 'package:flutter/material.dart';

/// Colours for marking the student's copy, tuned for each brightness.
class Marks extends ThemeExtension<Marks> {
  const Marks({required this.wrong, required this.wrongBg, required this.right,
      required this.rightBg, required this.warn, required this.warnBg});

  final Color wrong, wrongBg, right, rightBg, warn, warnBg;

  static Marks of(BuildContext context) => Theme.of(context).extension<Marks>()!;

  @override
  Marks copyWith() => this;

  @override
  Marks lerp(Marks? other, double t) => other ?? this;
}

const _light = Marks(
  wrong: Color(0xFFD2283C), wrongBg: Color(0xFFFDE7EA),
  right: Color(0xFF1D7A4A), rightBg: Color(0xFFE2F5EA),
  warn: Color(0xFFA15C00), warnBg: Color(0xFFFFF1D6),
);
const _dark = Marks(
  wrong: Color(0xFFFF7085), wrongBg: Color(0xFF3A1A24),
  right: Color(0xFF6FD69B), rightBg: Color(0xFF163325),
  warn: Color(0xFFFFC065), warnBg: Color(0xFF3A2A12),
);

ThemeData buildTheme(Brightness b) {
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF2952C8), brightness: b);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    extensions: [b == Brightness.dark ? _dark : _light],
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      margin: EdgeInsets.zero,
    ),
  );
}

/// AppBar action that flips light/dark.
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key, required this.onToggle});

  final void Function(Brightness current) onToggle;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      tooltip: dark ? 'Tema claro' : 'Tema escuro',
      icon: Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
      onPressed: () => onToggle(Theme.of(context).brightness),
    );
  }
}
