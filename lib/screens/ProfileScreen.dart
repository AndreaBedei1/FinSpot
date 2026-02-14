import 'package:flutter/material.dart';
import 'package:seawatch/config/app_config.dart';
import 'package:seawatch/models/avvistamento.dart';
import 'package:seawatch/screens/settingScreens/ProfileChangeScreen.dart';
import 'package:seawatch/services/AuthServiceGeneral/AuthService.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.email});

  final String? email;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();

  bool _loading = true;
  UserLite? _user;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
    });

    try {
      final user = await _authService.getCurrentUser(refreshFromServer: true);
      if (!mounted) {
        return;
      }

      setState(() {
        _user = user;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (!mounted) {
      return;
    }

    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final user = _user;
    if (user == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Profilo non disponibile'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loadProfile,
              child: const Text('Riprova'),
            ),
          ],
        ),
      );
    }

    final displayName =
        '${user.firstName ?? ''} ${user.lastName ?? ''}'.trim().isEmpty
            ? 'Utente SeaWatch'
            : '${user.firstName ?? ''} ${user.lastName ?? ''}'.trim();
    final avatarUrl = user.img == null || user.img!.isEmpty
        ? null
        : AppConfig.normalizeUrl(user.img!);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profilo'),
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                      child: avatarUrl == null
                          ? const Icon(Icons.person, size: 44)
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(user.email),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () async {
                final updated = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileChangeScreen()),
                );

                if (updated == true) {
                  await _loadProfile();
                }
              },
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Modifica profilo'),
            ),
          ],
        ),
      ),
    );
  }
}
