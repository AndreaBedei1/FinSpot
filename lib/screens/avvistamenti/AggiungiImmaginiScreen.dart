import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:seawatch/services/sightings/sightings_repository.dart';

class AggiungiImmaginiScreen extends StatefulWidget {
  const AggiungiImmaginiScreen({super.key, required this.avvistamentoId});

  final String avvistamentoId;

  @override
  State<AggiungiImmaginiScreen> createState() => _AggiungiImmaginiScreenState();
}

class _AggiungiImmaginiScreenState extends State<AggiungiImmaginiScreen> {
  final _repository = SightingsRepository.instance;
  final _picker = ImagePicker();
  final List<File> _images = [];

  bool _loading = false;

  int get _sightingId => int.tryParse(widget.avvistamentoId) ?? -1;

  Future<void> _pick(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) {
      return;
    }

    setState(() {
      _images.add(File(picked.path));
    });
  }

  Future<void> _uploadAll() async {
    if (_images.isEmpty) {
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      for (final image in _images) {
        await _repository.uploadImage(_sightingId, image.path);
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Immagini gestite correttamente.')),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore upload immagini: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aggiungi immagini')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _images
                .map(
                  (file) => Image.file(
                    file,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: _loading ? null : () => _pick(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Camera'),
              ),
              OutlinedButton.icon(
                onPressed: _loading ? null : () => _pick(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Galleria'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: _loading ? null : _uploadAll,
            child: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Carica immagini'),
          ),
        ],
      ),
    );
  }
}
