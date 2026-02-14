import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:seawatch/config/app_config.dart';
import 'package:seawatch/models/avvistamento.dart';
import 'package:seawatch/services/AuthServiceGeneral/AuthService.dart';
import 'package:seawatch/services/core/api_client.dart';
import 'package:seawatch/services/sightings/sightings_repository.dart';

class AvvistamentoDetailsPage extends StatefulWidget {
  const AvvistamentoDetailsPage({super.key, required this.avvistamento});

  final Avvistamento avvistamento;

  @override
  State<AvvistamentoDetailsPage> createState() =>
      _AvvistamentoDetailsPageState();
}

class _AvvistamentoDetailsPageState extends State<AvvistamentoDetailsPage> {
  final _repository = SightingsRepository.instance;
  final _authService = AuthService();
  final _api = ApiClient();
  final _imagePicker = ImagePicker();

  Avvistamento? _sighting;
  List<SightingImageItem> _images = const [];
  List<AnimalOption> _animals = const [];

  bool _loading = true;
  bool _working = false;
  bool _isOnline = false;
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _sighting = widget.avvistamento;
    _load();
  }

  bool get _isOwner {
    final sighting = _sighting;
    if (sighting == null || _currentUserId == null) {
      return false;
    }
    return sighting.user.id == _currentUserId;
  }

  String _formatDate(String iso) {
    final date = DateTime.tryParse(iso);
    if (date == null) {
      return '-';
    }
    return DateFormat('dd/MM/yyyy HH:mm').format(date.toLocal());
  }

  String _syncLabel(SyncState state) {
    switch (state) {
      case SyncState.pendingCreate:
        return 'Creazione in coda';
      case SyncState.pendingUpdate:
        return 'Modifica in coda';
      case SyncState.pendingDelete:
        return 'Eliminazione in coda';
      case SyncState.synced:
        return 'Sincronizzato';
    }
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: TextStyle(
                fontSize: 14.5,
                color: onSurface,
                decoration: TextDecoration.none,
              ),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: onSurface,
                    decoration: TextDecoration.none,
                  ),
                ),
                TextSpan(
                  text: value,
                  style: TextStyle(
                    color: onSurface,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });

    try {
      final online = await _api.isBackendReachable();
      final user = await _authService.getCurrentUser(refreshFromServer: true);
      final sightingId = _sighting?.id ?? widget.avvistamento.id;

      final freshSighting = await _repository.getSightingById(
        sightingId,
        forceRefresh: true,
      );
      final images = await _repository.getImagesForSighting(
        sightingId,
        forceRefresh: true,
      );
      final animals = await _repository.getAnimals();

      if (!mounted) {
        return;
      }

      setState(() {
        _currentUserId = user?.id;
        _sighting = freshSighting ?? _sighting;
        _images = images;
        _animals = animals;
        _isOnline = online;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore caricamento dettaglio: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _deleteSighting() async {
    final sighting = _sighting;
    if (sighting == null) {
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Conferma eliminazione'),
          content: const Text('Vuoi eliminare questo avvistamento?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Elimina'),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    setState(() {
      _working = true;
    });

    try {
      await _repository.deleteSighting(sighting.id);

      if (!mounted) {
        return;
      }

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore eliminazione: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
        });
      }
    }
  }

  Future<void> _editSighting() async {
    final sighting = _sighting;
    if (sighting == null) {
      return;
    }

    var selectedAnimalId = sighting.animalId;
    var selectedSpeciesId = sighting.speciesId;
    var selectedSea = sighting.mare;
    var selectedWind = sighting.vento;
    final notesController = TextEditingController(text: sighting.note ?? '');

    List<SpeciesOption> species = await _repository.getSpecies(
        animalId: selectedAnimalId, forceRefresh: true);
    if (!mounted) {
      return;
    }

    final updated = await showDialog<UpdateSightingInput>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Modifica avvistamento'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      enabled: false,
                      decoration: InputDecoration(
                        labelText: 'Data',
                        border: const OutlineInputBorder(),
                        hintText: _formatDate(sighting.data),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      enabled: false,
                      decoration: InputDecoration(
                        labelText: 'Utente',
                        border: const OutlineInputBorder(),
                        hintText: sighting.user.email,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      enabled: false,
                      decoration: InputDecoration(
                        labelText: 'Num. esemplari',
                        border: const OutlineInputBorder(),
                        hintText: sighting.numeroEsemplari.toString(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      enabled: false,
                      decoration: InputDecoration(
                        labelText: 'Latitudine',
                        border: const OutlineInputBorder(),
                        hintText: sighting.latitudine.toStringAsFixed(6),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      enabled: false,
                      decoration: InputDecoration(
                        labelText: 'Longitudine',
                        border: const OutlineInputBorder(),
                        hintText: sighting.longitudine.toStringAsFixed(6),
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      initialValue: selectedAnimalId,
                      isExpanded: true,
                      menuMaxHeight: 280,
                      decoration: const InputDecoration(
                        labelText: 'Animale',
                        border: OutlineInputBorder(),
                      ),
                      items: _animals
                          .map(
                            (a) => DropdownMenuItem<int>(
                              value: a.id,
                              child: Text(a.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) async {
                        if (value == null) {
                          return;
                        }
                        setDialogState(() {
                          selectedAnimalId = value;
                          selectedSpeciesId = null;
                          species = const [];
                        });

                        final loaded = await _repository.getSpecies(
                          animalId: value,
                          forceRefresh: true,
                        );
                        if (!mounted) {
                          return;
                        }
                        setDialogState(() {
                          species = loaded;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      initialValue: selectedSpeciesId,
                      isExpanded: true,
                      menuMaxHeight: 280,
                      decoration: const InputDecoration(
                        labelText: 'Specie',
                        border: OutlineInputBorder(),
                      ),
                      items: species
                          .map(
                            (s) => DropdownMenuItem<int>(
                              value: s.id,
                              child: Text(s.name),
                            ),
                          )
                          .toList(),
                      onChanged: species.isEmpty
                          ? null
                          : (value) {
                              setDialogState(() {
                                selectedSpeciesId = value;
                              });
                            },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: selectedSea,
                      isExpanded: true,
                      menuMaxHeight: 280,
                      decoration: const InputDecoration(
                        labelText: 'Mare',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Calmo', child: Text('Calmo')),
                        DropdownMenuItem(
                            value: 'Poco mosso', child: Text('Poco mosso')),
                        DropdownMenuItem(value: 'Mosso', child: Text('Mosso')),
                        DropdownMenuItem(
                            value: 'Molto mosso', child: Text('Molto mosso')),
                        DropdownMenuItem(
                            value: 'Agitato', child: Text('Agitato')),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          selectedSea = value;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: selectedWind,
                      isExpanded: true,
                      menuMaxHeight: 280,
                      decoration: const InputDecoration(
                        labelText: 'Vento',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'Assente', child: Text('Assente')),
                        DropdownMenuItem(
                            value: 'Debole', child: Text('Debole')),
                        DropdownMenuItem(
                            value: 'Moderato', child: Text('Moderato')),
                        DropdownMenuItem(value: 'Forte', child: Text('Forte')),
                        DropdownMenuItem(
                            value: 'Tempesta', child: Text('Tempesta')),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          selectedWind = value;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Note',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annulla'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                      UpdateSightingInput(
                        animalId: selectedAnimalId,
                        speciesId: selectedSpeciesId,
                        sea: selectedSea,
                        wind: selectedWind,
                        notes: notesController.text.trim().isEmpty
                            ? null
                            : notesController.text.trim(),
                      ),
                    );
                  },
                  child: const Text('Salva'),
                ),
              ],
            );
          },
        );
      },
    );

    if (updated == null) {
      return;
    }

    setState(() {
      _working = true;
    });

    try {
      final refreshed = await _repository.updateSighting(sighting.id, updated);
      if (!mounted) {
        return;
      }

      setState(() {
        _sighting = refreshed;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            refreshed.syncState == SyncState.pendingUpdate
                ? 'Modifica salvata in locale, in coda per sincronizzazione.'
                : 'Avvistamento aggiornato.',
          ),
        ),
      );

      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore aggiornamento: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
        });
      }
    }
  }

  Future<void> _uploadImage() async {
    final sighting = _sighting;
    if (sighting == null) {
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Scatta foto'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Scegli dalla galleria'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );

    if (source == null) {
      return;
    }

    final file = await _imagePicker.pickImage(source: source, imageQuality: 85);
    if (file == null) {
      return;
    }
    if (!mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _working = true;
    });
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          duration: Duration(minutes: 1),
          content: Text('Caricamento immagine in corso...'),
        ),
      );

    try {
      await _repository.uploadImage(sighting.id, file.path);
      await _load();

      if (!mounted) {
        return;
      }

      messenger.hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Immagine gestita correttamente.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      messenger.hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore caricamento immagine: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
        });
      }
    }
  }

  Future<void> _deleteImage(SightingImageItem image) async {
    final sighting = _sighting;
    if (sighting == null) {
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Elimina immagine'),
          content: const Text('Confermi eliminazione immagine?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Elimina'),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    setState(() {
      _working = true;
    });

    try {
      await _repository.deleteImage(
        sightingId: sighting.id,
        imageId: image.id,
        localPath: image.localPath,
      );
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore eliminazione immagine: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
        });
      }
    }
  }

  Future<void> _createOrEditAnnotation({
    required SightingImageItem image,
    AnnotationItem? existing,
  }) async {
    final sighting = _sighting;
    if (sighting == null) {
      return;
    }

    final tlX = TextEditingController(text: existing?.tlX.toString() ?? '');
    final tlY = TextEditingController(text: existing?.tlY.toString() ?? '');
    final brX = TextEditingController(text: existing?.brX.toString() ?? '');
    final brY = TextEditingController(text: existing?.brY.toString() ?? '');
    final specimenName =
        TextEditingController(text: existing?.specimenName ?? '');

    final submit = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
              existing == null ? 'Nuova annotazione' : 'Modifica annotazione'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: specimenName,
                  decoration: const InputDecoration(
                    labelText: 'Nome esemplare',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: tlX,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'tl_x',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: tlY,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'tl_y',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: brX,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'br_x',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: brY,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'br_y',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Salva'),
            ),
          ],
        );
      },
    );

    if (submit != true) {
      return;
    }

    final parsedTlX = double.tryParse(tlX.text.trim());
    final parsedTlY = double.tryParse(tlY.text.trim());
    final parsedBrX = double.tryParse(brX.text.trim());
    final parsedBrY = double.tryParse(brY.text.trim());

    if (parsedTlX == null ||
        parsedTlY == null ||
        parsedBrX == null ||
        parsedBrY == null) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Coordinate annotazione non valide.')),
      );
      return;
    }

    setState(() {
      _working = true;
    });

    try {
      if (existing == null) {
        await _repository.addAnnotation(
          sightingId: sighting.id,
          imageId: image.id,
          tlX: parsedTlX,
          tlY: parsedTlY,
          brX: parsedBrX,
          brY: parsedBrY,
          specimenName: specimenName.text.trim().isEmpty
              ? null
              : specimenName.text.trim(),
        );
      } else {
        await _repository.updateAnnotation(
          sightingId: sighting.id,
          annotationId: existing.id,
          tlX: parsedTlX,
          tlY: parsedTlY,
          brX: parsedBrX,
          brY: parsedBrY,
          specimenName: specimenName.text.trim().isEmpty
              ? null
              : specimenName.text.trim(),
        );
      }

      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore annotazione: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
        });
      }
    }
  }

  Future<void> _deleteAnnotation(int annotationId) async {
    final sighting = _sighting;
    if (sighting == null) {
      return;
    }

    setState(() {
      _working = true;
    });

    try {
      await _repository.deleteAnnotation(
        sightingId: sighting.id,
        annotationId: annotationId,
      );
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore eliminazione annotazione: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
        });
      }
    }
  }

  Future<void> _runRecognition() async {
    final sighting = _sighting;
    if (sighting == null || sighting.id <= 0) {
      return;
    }

    final online = await _api.isBackendReachable();
    if (!online) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isOnline = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Riconoscimento disponibile solo con connessione internet.'),
        ),
      );
      return;
    }

    setState(() {
      _working = true;
      _isOnline = true;
    });

    var loadingShown = false;
    try {
      if (mounted) {
        loadingShown = true;
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return const AlertDialog(
              content: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                      child: Text('Attendere, riconoscimento in corso...')),
                ],
              ),
            );
          },
        );
      }

      final results = await _repository.runRecognition(sighting.id);
      if (loadingShown && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        loadingShown = false;
      }

      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Riconoscimento esemplari'),
            content: results.isEmpty
                ? const Text('Nessun risultato disponibile.')
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: results.map((r) => Text('- $r')).toList(),
                  ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Chiudi'),
              ),
            ],
          );
        },
      );
    } catch (error) {
      if (loadingShown && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        loadingShown = false;
      }
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore riconoscimento: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
        });
      }
    }
  }

  Widget _buildImage(SightingImageItem image) {
    if (image.pendingUpload) {
      return Stack(
        fit: StackFit.expand,
        children: [
          if (image.localPath != null && File(image.localPath!).existsSync())
            Image.file(
              File(image.localPath!),
              fit: BoxFit.cover,
            )
          else
            const ColoredBox(color: Colors.black12),
          Container(
            color: Colors.black45,
            alignment: Alignment.center,
            child: const Text(
              'In coda',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      );
    }

    if (image.url.startsWith('http://') || image.url.startsWith('https://')) {
      return Image.network(
        image.url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const ColoredBox(
          color: Colors.black12,
          child: Icon(Icons.broken_image_outlined),
        ),
      );
    }

    if (image.url.startsWith('/')) {
      return Image.network(
        AppConfig.normalizeUrl(image.url),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const ColoredBox(
          color: Colors.black12,
          child: Icon(Icons.broken_image_outlined),
        ),
      );
    }

    final file = File(image.url);
    if (file.existsSync()) {
      return Image.file(file, fit: BoxFit.cover);
    }

    return const ColoredBox(
      color: Colors.black12,
      child: Icon(Icons.image_not_supported_outlined),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sighting = _sighting;

    if (_loading || sighting == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dettaglio avvistamento')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dettaglio avvistamento'),
        actions: [
          IconButton(
            onPressed: _working ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Aggiorna',
          ),
        ],
      ),
      body: IgnorePointer(
        ignoring: _working,
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info_outline),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Dati avvistamento',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Chip(
                            label: Text(_syncLabel(sighting.syncState)),
                            labelStyle: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              decoration: TextDecoration.none,
                              fontWeight: FontWeight.w600,
                            ),
                            backgroundColor:
                                Theme.of(context).colorScheme.surface,
                            side: BorderSide(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outline
                                  .withValues(alpha: 0.4),
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Divider(height: 1),
                      const SizedBox(height: 10),
                      _buildInfoRow(
                        icon: Icons.event_outlined,
                        label: 'Data',
                        value: _formatDate(sighting.data),
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        icon: Icons.person_outline,
                        label: 'Utente',
                        value: sighting.user.email,
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        icon: Icons.pets_outlined,
                        label: 'Animale',
                        value: sighting.animale,
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        icon: Icons.biotech_outlined,
                        label: 'Specie',
                        value: sighting.specie ?? '-',
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        icon: Icons.numbers_outlined,
                        label: 'Numero esemplari',
                        value: sighting.numeroEsemplari.toString(),
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        icon: Icons.place_outlined,
                        label: 'Coordinate',
                        value:
                            '${sighting.latitudine.toStringAsFixed(6)}, ${sighting.longitudine.toStringAsFixed(6)}',
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        icon: Icons.waves_outlined,
                        label: 'Mare',
                        value: sighting.mare ?? '-',
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        icon: Icons.air_outlined,
                        label: 'Vento',
                        value: sighting.vento ?? '-',
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        icon: Icons.notes_outlined,
                        label: 'Note',
                        value: sighting.note ?? '-',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (sighting.id > 0)
                    ElevatedButton.icon(
                      onPressed:
                          (_working || !_isOnline) ? null : _runRecognition,
                      icon: const Icon(Icons.search),
                      label: const Text('Riconoscimento'),
                    ),
                  if (_isOwner)
                    ElevatedButton.icon(
                      onPressed: _working ? null : _editSighting,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Modifica'),
                    ),
                  if (_isOwner)
                    ElevatedButton.icon(
                      style:
                          ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: _working ? null : _deleteSighting,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Elimina'),
                    ),
                ],
              ),
              if (sighting.id > 0 && !_isOnline)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Riconoscimento disponibile solo con connessione internet.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Immagini e annotazioni',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                  if (_isOwner)
                    TextButton.icon(
                      onPressed: _working ? null : _uploadImage,
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: const Text('Aggiungi foto'),
                    ),
                ],
              ),
              if (_images.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Nessuna immagine disponibile.'),
                ),
              ..._images.map(
                (image) => Card(
                  margin: const EdgeInsets.only(top: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 180,
                          width: double.infinity,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _buildImage(image),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text('Annotazioni: ${image.annotations.length}'),
                            const Spacer(),
                            if (_isOwner)
                              IconButton(
                                onPressed: image.pendingUpload
                                    ? null
                                    : () =>
                                        _createOrEditAnnotation(image: image),
                                icon: const Icon(Icons.add_comment_outlined),
                                tooltip: 'Aggiungi annotazione',
                              ),
                            if (_isOwner)
                              IconButton(
                                onPressed: () => _deleteImage(image),
                                icon: const Icon(Icons.delete_outline),
                                tooltip: 'Elimina immagine',
                              ),
                          ],
                        ),
                        if (image.annotations.isNotEmpty)
                          ...image.annotations.map(
                            (ann) => Container(
                              margin: const EdgeInsets.only(top: 6),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black12,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'ID ${ann.id} - ${ann.specimenName ?? 'Esemplare'} '
                                      '(${ann.tlX}, ${ann.tlY})-(${ann.brX}, ${ann.brY})',
                                    ),
                                  ),
                                  if (_isOwner)
                                    IconButton(
                                      onPressed: () => _createOrEditAnnotation(
                                        image: image,
                                        existing: ann,
                                      ),
                                      icon: const Icon(Icons.edit_outlined),
                                      tooltip: 'Modifica annotazione',
                                    ),
                                  if (_isOwner)
                                    IconButton(
                                      onPressed: () =>
                                          _deleteAnnotation(ann.id),
                                      icon: const Icon(Icons.delete_outline),
                                      tooltip: 'Elimina annotazione',
                                    ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              if (!_isOwner)
                const Text(
                  'Solo il proprietario puo modificare avvistamento, immagini e annotazioni.',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
