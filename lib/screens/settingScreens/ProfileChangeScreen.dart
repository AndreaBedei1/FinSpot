import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:seawatch/config/app_config.dart';
import 'package:seawatch/services/AuthServiceGeneral/AuthService.dart';
import 'package:seawatch/services/core/api_client.dart';

class ProfileChangeScreen extends StatefulWidget {
  const ProfileChangeScreen({super.key});

  @override
  State<ProfileChangeScreen> createState() => _ProfileChangeScreenState();
}

class _ProfileChangeScreenState extends State<ProfileChangeScreen> {
  final _authService = AuthService();
  final _picker = ImagePicker();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _allowPop = false;

  String? _avatarUrl;
  File? _avatarFile;
  String _initialFirstName = '';
  String _initialLastName = '';

  bool get _hasUnsavedChanges {
    if (_loading || _saving) {
      return false;
    }

    return _firstNameController.text.trim() != _initialFirstName ||
        _lastNameController.text.trim() != _initialLastName ||
        _avatarFile != null;
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
    });

    final user = await _authService.getCurrentUser(refreshFromServer: true);

    if (!mounted) {
      return;
    }

    setState(() {
      _initialFirstName = user?.firstName?.trim() ?? '';
      _initialLastName = user?.lastName?.trim() ?? '';
      _firstNameController.text = _initialFirstName;
      _lastNameController.text = _initialLastName;
      _avatarUrl =
          user?.img == null ? null : AppConfig.normalizeUrl(user!.img!);
      _avatarFile = null;
      _loading = false;
    });
  }

  Future<void> _pickAvatar(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) {
      return;
    }

    setState(() {
      _avatarFile = File(picked.path);
    });
  }

  Future<void> _chooseAvatarSource() async {
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
      await _pickAvatar(source);
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
    });

    try {
      await _authService.updateProfile(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
      );

      if (_avatarFile != null) {
        await _authService.uploadAvatar(_avatarFile!.path);
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _initialFirstName = _firstNameController.text.trim();
        _initialLastName = _lastNameController.text.trim();
        _avatarFile = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profilo aggiornato.')),
      );

      Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Errore durante il salvataggio.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<bool> _confirmDiscardChanges() async {
    if (!_hasUnsavedChanges) {
      return true;
    }

    final discard = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Modifiche non salvate'),
          content: const Text('Vuoi uscire senza salvare le modifiche?'),
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return PopScope(
        canPop: _allowPop || !_saving,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) {
            return;
          }
          await _handlePopAttempt();
        },
        child: Scaffold(
          appBar: AppBar(title: const Text('Modifica profilo')),
          body: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    ImageProvider<Object>? avatarProvider;
    if (_avatarFile != null) {
      avatarProvider = FileImage(_avatarFile!);
    } else if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      avatarProvider = NetworkImage(_avatarUrl!);
    }

    return PopScope(
      canPop: _allowPop || (!_saving && !_hasUnsavedChanges),
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          return;
        }
        await _handlePopAttempt();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Modifica profilo')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: Semantics(
                button: true,
                label: 'Cambia immagine profilo',
                child: GestureDetector(
                  onTap: _saving ? null : _chooseAvatarSource,
                  child: CircleAvatar(
                    radius: 52,
                    backgroundImage: avatarProvider,
                    child: (_avatarFile == null &&
                            (_avatarUrl == null || _avatarUrl!.isEmpty))
                        ? const Icon(Icons.person, size: 52)
                        : null,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _firstNameController,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.givenName],
              decoration: const InputDecoration(
                labelText: 'Nome',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _lastNameController,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.familyName],
              decoration: const InputDecoration(
                labelText: 'Cognome',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Salvataggio...' : 'Salva modifiche'),
            ),
          ],
        ),
      ),
    );
  }
}
