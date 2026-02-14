import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:seawatch/models/avvistamento.dart';
import 'package:seawatch/screens/avvistamenti/AvvistamentoDetailsPage.dart';
import 'package:seawatch/screens/avvistamenti/NuovoAvvistamentoScreen.dart';
import 'package:seawatch/services/sightings/sightings_repository.dart';

class AvvistamentiScreen extends StatefulWidget {
  const AvvistamentiScreen({super.key});

  @override
  State<AvvistamentiScreen> createState() => _AvvistamentiScreenState();
}

class _AvvistamentiScreenState extends State<AvvistamentiScreen> {
  final _repository = SightingsRepository.instance;

  bool _loading = true;
  String? _error;
  List<Avvistamento> _sightings = const [];

  @override
  void initState() {
    super.initState();
    _load(forceRefresh: true);
  }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final sightings = await _repository.getSightings(forceRefresh: forceRefresh);
      if (!mounted) {
        return;
      }
      setState(() {
        _sightings = sightings;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
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
        return '';
    }
  }

  String _formatDate(String iso) {
    final date = DateTime.tryParse(iso);
    if (date == null) {
      return '-';
    }
    return DateFormat('dd/MM/yyyy HH:mm').format(date.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Avvistamenti'),
        actions: [
          IconButton(
            onPressed: _loading ? null : () => _load(forceRefresh: true),
            icon: const Icon(Icons.refresh),
            tooltip: 'Aggiorna lista',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => NuovoAvvistamentoScreen()),
          );

          if (!mounted) {
            return;
          }

          await _load();
        },
        label: const Text('Nuovo'),
        icon: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () => _load(forceRefresh: true),
                child: const Text('Riprova'),
              ),
            ],
          ),
        ),
      );
    }

    if (_sightings.isEmpty) {
      return const Center(child: Text('Nessun avvistamento disponibile'));
    }

    return RefreshIndicator(
      onRefresh: () => _load(forceRefresh: true),
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: _sightings.length,
        separatorBuilder: (_, __) => const Divider(height: 0),
        itemBuilder: (context, index) {
          final sighting = _sightings[index];
          final syncLabel = _syncLabel(sighting.syncState);

          return ListTile(
            leading: CircleAvatar(
              child: Text(sighting.numeroEsemplari.toString()),
            ),
            title: Text(sighting.specie ?? sighting.animale),
            subtitle: Text(
              '${_formatDate(sighting.data)}\n'
              '${sighting.user.email}\n'
              '${sighting.latitudine.toStringAsFixed(5)}, '
              '${sighting.longitudine.toStringAsFixed(5)}'
              '${syncLabel.isEmpty ? '' : '\n$syncLabel'}',
            ),
            isThreeLine: true,
            trailing: sighting.isPending
                ? const Icon(Icons.cloud_upload, color: Colors.orange)
                : const Icon(Icons.chevron_right),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AvvistamentoDetailsPage(avvistamento: sighting),
                ),
              );

              if (!mounted) {
                return;
              }

              await _load();
            },
          );
        },
      ),
    );
  }
}
