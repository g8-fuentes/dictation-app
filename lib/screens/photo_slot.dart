import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class Photo {
  Photo(this.path, this.bytes);
  final String path;
  final Uint8List bytes;
}

final _picker = ImagePicker();
bool _picking = false;

/// Opens the camera or the gallery; null when cancelled or on failure.
Future<Photo?> pickPhoto(BuildContext context, ImageSource source) async {
  if (_picking) return null;
  _picking = true;
  try {
    final file = await _picker.pickImage(
      source: source,
      maxWidth: 2400,
      maxHeight: 2400,
      imageQuality: 90,
    );
    if (file == null) return null;
    return Photo(file.path, await file.readAsBytes());
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Não consegui abrir a foto. Tente de novo.')));
    }
    return null;
  } finally {
    _picking = false;
  }
}

/// Android may close the app while the camera is open; the photo is then
/// handed back on the next start.
Future<Photo?> recoverLostPhoto() async {
  try {
    final lost = await _picker.retrieveLostData();
    final file = lost.file;
    if (lost.isEmpty || file == null) return null;
    return Photo(file.path, await file.readAsBytes());
  } catch (_) {
    return null;
  }
}

class PhotoSlot extends StatelessWidget {
  const PhotoSlot({
    super.key,
    required this.step,
    required this.title,
    required this.hint,
    required this.photo,
    required this.onPicked,
    required this.onClear,
  });

  final String? step;
  final String title, hint;
  final Photo? photo;
  final ValueChanged<Photo> onPicked;
  final VoidCallback onClear;

  Future<void> _pick(BuildContext context, ImageSource source) async {
    final p = await pickPhoto(context, source);
    if (p != null) onPicked(p);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final bytes = photo?.bytes;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              if (step != null) ...[
                CircleAvatar(
                  radius: 14,
                  backgroundColor: bytes != null ? scheme.primary : scheme.secondaryContainer,
                  foregroundColor: bytes != null ? scheme.onPrimary : scheme.onSecondaryContainer,
                  child: bytes != null
                      ? const Icon(Icons.check, size: 16)
                      : Text(step!, style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
              ],
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
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: Image.memory(bytes, fit: BoxFit.cover, width: double.infinity),
                ),
              )
            else
              Container(
                height: 110,
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
                  onPressed: () => _pick(context, ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Câmera'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pick(context, ImageSource.gallery),
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
