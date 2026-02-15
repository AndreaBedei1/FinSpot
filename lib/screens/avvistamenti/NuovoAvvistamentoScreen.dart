import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:seawatch/models/avvistamento.dart';
import 'package:seawatch/services/sightings/sightings_repository.dart';

class NuovoAvvistamentoScreen extends StatefulWidget {
  const NuovoAvvistamentoScreen({super.key, this.userEmail});

  final String? userEmail;

  @override
  State<NuovoAvvistamentoScreen> createState() =>
      _NuovoAvvistamentoScreenState();
}

class _NuovoAvvistamentoScreenState extends State<NuovoAvvistamentoScreen> {
  static const _settingsChannel =
      MethodChannel('it.unibo.csr.seawatch/device_settings');

  final _formKey = GlobalKey<FormState>();
  final _repository = SightingsRepository.instance;
  final _picker = ImagePicker();

  final _specimensController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _notesController = TextEditingController();

  final List<File> _images = [];

  List<AnimalOption> _animals = const [];
  List<SpeciesOption> _species = const [];

  int? _selectedAnimalId;
  int? _selectedSpeciesId;
  String? _selectedSea;
  String? _selectedWind;

  bool _loadingAnimals = true;
  bool _saving = false;
  bool _loadingLocation = false;
  bool _dirty = false;
  bool _allowPop = false;

  static const _seaOptions = [
    'Calmo',
    'Poco mosso',
    'Mosso',
    'Molto mosso',
    'Agitato',
  ];

  static const _windOptions = [
    'Assente',
    'Debole',
    'Moderato',
    'Forte',
    'Tempesta',
  ];

  @override
  void initState() {
    super.initState();
    _loadAnimals();
  }

  @override
  void dispose() {
    _specimensController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadAnimals() async {
    setState(() {
      _loadingAnimals = true;
    });

    try {
      final animals = await _repository.getAnimals(forceRefresh: true);
      await _repository.getSpecies(forceRefresh: true);
      if (!mounted) {
        return;
      }

      setState(() {
        _animals = animals;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore caricando animali: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingAnimals = false;
        });
      }
    }
  }

  Future<void> _loadSpeciesForAnimal(int animalId) async {
    try {
      final species = await _repository.getSpecies(
        animalId: animalId,
        forceRefresh: true,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _species = species;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _species = const [];
      });
    }
  }

  void _markDirty() {
    if (_dirty) {
      return;
    }
    setState(() {
      _dirty = true;
    });
  }

  void _showInfo(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<bool> _confirmDiscardChanges() async {
    if (!_dirty || _saving) {
      return true;
    }

    final discard = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Modifiche non salvate'),
          content: const Text('Vuoi uscire senza salvare questo avvistamento?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Continua a modificare'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Esci senza salvare'),
            ),
          ],
        );
      },
    );

    return discard == true;
  }

  Future<void> _handlePopAttempt() async {
    if (_saving) {
      return;
    }

    final canLeave = await _confirmDiscardChanges();
    if (!canLeave || !mounted) {
      return;
    }

    setState(() {
      _allowPop = true;
    });
    Navigator.of(context).pop();
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_images.length >= 5) {
      _showInfo('Massimo 5 immagini per avvistamento.');
      return;
    }

    final picked = await _picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) {
      return;
    }

    setState(() {
      _images.add(File(picked.path));
    });
    _markDirty();
  }

  Future<void> _chooseImageSource() async {
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

    if (source != null) {
      await _pickImage(source);
    }
  }

  Future<bool> _openLocationActivation() async {
    if (!Platform.isAndroid) {
      return Geolocator.openLocationSettings();
    }

    try {
      final opened =
          await _settingsChannel.invokeMethod<bool>('openLocationActivation');
      if (opened == true) {
        return true;
      }
    } catch (_) {
      // fallback below
    }

    return Geolocator.openLocationSettings();
  }

  Future<void> _getCurrentLocation({bool markAsDirty = false}) async {
    setState(() {
      _loadingLocation = true;
    });

    try {
      var enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        final opened = await _openLocationActivation();
        if (!opened) {
          _showInfo('Attiva la posizione dalle impostazioni del dispositivo.');
          return;
        }

        enabled = await Geolocator.isLocationServiceEnabled();
        if (!enabled) {
          _showInfo('Posizione ancora disattivata. Attivala e riprova.');
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _showInfo(
            'Permesso posizione negato. Concedi il permesso per continuare.');
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        final opened = await Geolocator.openAppSettings();
        if (!opened) {
          _showInfo(
              'Attiva il permesso posizione nelle impostazioni dell\'app.');
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _latitudeController.text = position.latitude.toStringAsFixed(6);
        _longitudeController.text = position.longitude.toStringAsFixed(6);
      });
      if (markAsDirty) {
        _markDirty();
      }
    } catch (_) {
      _showInfo('Impossibile ottenere la posizione in questo momento.');
    } finally {
      if (mounted) {
        setState(() {
          _loadingLocation = false;
        });
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedAnimalId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona un animale.')),
      );
      return;
    }

    final specimens = int.tryParse(_specimensController.text.trim());
    final latitude = double.tryParse(_latitudeController.text.trim());
    final longitude = double.tryParse(_longitudeController.text.trim());

    if (specimens == null || specimens <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Numero esemplari non valido.')),
      );
      return;
    }

    if (latitude == null || longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Coordinate non valide.')),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final created = await _repository.createSighting(
        CreateSightingInput(
          date: DateTime.now(),
          specimens: specimens,
          latitude: latitude,
          longitude: longitude,
          animalId: _selectedAnimalId!,
          speciesId: _selectedSpeciesId,
          sea: _selectedSea,
          wind: _selectedWind,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        ),
        imagePaths: _images.map((e) => e.path).toList(),
      );

      if (!mounted) {
        return;
      }

      final offline = created.syncState == SyncState.pendingCreate;
      _showInfo(
        offline
            ? 'Salvato in locale. Sincronizzazione in coda quando torna la rete.'
            : 'Avvistamento salvato con successo.',
      );

      _dirty = false;

      Navigator.pop(context, created);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore salvataggio: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _allowPop || (!_saving && !_dirty),
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          return;
        }
        await _handlePopAttempt();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Nuovo avvistamento'),
          actions: [
            IconButton(
              onPressed: _loadingLocation
                  ? null
                  : () => _getCurrentLocation(markAsDirty: true),
              icon: _loadingLocation
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
              tooltip: 'Aggiorna posizione',
            ),
          ],
        ),
        body: _loadingAnimals
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      TextFormField(
                        controller: _specimensController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Numero esemplari *',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => _markDirty(),
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty) {
                            return 'Campo obbligatorio';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        value: _selectedAnimalId,
                        isExpanded: true,
                        menuMaxHeight: 280,
                        decoration: const InputDecoration(
                          labelText: 'Animale *',
                          border: OutlineInputBorder(),
                        ),
                        items: _animals
                            .map(
                              (animal) => DropdownMenuItem<int>(
                                value: animal.id,
                                child: Text(animal.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) async {
                          setState(() {
                            _selectedAnimalId = value;
                            _selectedSpeciesId = null;
                            _species = const [];
                          });
                          _markDirty();

                          if (value != null) {
                            await _loadSpeciesForAnimal(value);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        value: _selectedSpeciesId,
                        isExpanded: true,
                        menuMaxHeight: 280,
                        decoration: const InputDecoration(
                          labelText: 'Specie',
                          border: OutlineInputBorder(),
                        ),
                        items: _species
                            .map(
                              (specie) => DropdownMenuItem<int>(
                                value: specie.id,
                                child: Text(specie.name),
                              ),
                            )
                            .toList(),
                        onChanged: _species.isEmpty
                            ? null
                            : (value) {
                                setState(() {
                                  _selectedSpeciesId = value;
                                });
                                _markDirty();
                              },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _latitudeController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Latitudine *',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (_) => _markDirty(),
                              validator: (value) {
                                if ((value ?? '').trim().isEmpty) {
                                  return 'Obbligatoria';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _longitudeController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Longitudine *',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (_) => _markDirty(),
                              validator: (value) {
                                if ((value ?? '').trim().isEmpty) {
                                  return 'Obbligatoria';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedSea,
                        isExpanded: true,
                        menuMaxHeight: 280,
                        decoration: const InputDecoration(
                          labelText: 'Mare',
                          border: OutlineInputBorder(),
                        ),
                        items: _seaOptions
                            .map((s) =>
                                DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (value) {
                          setState(() => _selectedSea = value);
                          _markDirty();
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedWind,
                        isExpanded: true,
                        menuMaxHeight: 280,
                        decoration: const InputDecoration(
                          labelText: 'Vento',
                          border: OutlineInputBorder(),
                        ),
                        items: _windOptions
                            .map((w) =>
                                DropdownMenuItem(value: w, child: Text(w)))
                            .toList(),
                        onChanged: (value) {
                          setState(() => _selectedWind = value);
                          _markDirty();
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'Note',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => _markDirty(),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Immagini (${_images.length}/5)',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          TextButton.icon(
                            onPressed: _chooseImageSource,
                            icon: const Icon(Icons.add_a_photo_outlined),
                            label: const Text('Aggiungi'),
                          ),
                        ],
                      ),
                      if (_images.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _images
                              .asMap()
                              .entries
                              .map(
                                (entry) => Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(
                                        entry.value,
                                        width: 100,
                                        height: 100,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      top: 0,
                                      right: 0,
                                      child: InkWell(
                                        onTap: () {
                                          setState(() {
                                            _images.removeAt(entry.key);
                                          });
                                          _markDirty();
                                        },
                                        child: Container(
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.black54,
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            size: 18,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              .toList(),
                        ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(
                            _saving ? 'Salvataggio...' : 'Salva avvistamento'),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
