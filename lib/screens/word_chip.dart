import 'package:flutter/material.dart';

/// Strips surrounding punctuation so the voice says only the word.
String cleanWord(String w) => w.replaceAll(RegExp(r"^[^\w']+|[^\w']+$"), '');

/// A tappable word that pops in, and lights up while it is spoken.
class WordChip extends StatefulWidget {
  const WordChip({
    super.key,
    required this.word,
    required this.onTap,
    this.active = false,
    this.delay = Duration.zero,
  });

  final String word;
  final VoidCallback onTap;
  final bool active;
  final Duration delay;

  @override
  State<WordChip> createState() => _WordChipState();
}

class _WordChipState extends State<WordChip> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = widget.active;
    return AnimatedOpacity(
      opacity: _shown ? 1 : 0,
      duration: const Duration(milliseconds: 250),
      child: AnimatedScale(
        scale: !_shown ? .6 : (active ? 1.12 : 1),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutBack,
        child: Material(
          color: active ? scheme.primary : scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (active) ...[
                  Icon(Icons.volume_up, size: 16, color: scheme.onPrimary),
                  const SizedBox(width: 4),
                ],
                Text(
                  widget.word,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: active ? scheme.onPrimary : scheme.onSecondaryContainer,
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
