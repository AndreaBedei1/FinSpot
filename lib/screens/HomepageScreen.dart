import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:seawatch/models/avvistamento.dart';
import 'package:seawatch/screens/avvistamenti/AvvistamentoDetailsPage.dart';
import 'package:seawatch/services/sightings/sightings_repository.dart';

class HomepageScreen extends StatefulWidget {
  const HomepageScreen({super.key});

  @override
  State<HomepageScreen> createState() => _HomepageScreenState();
}

class _HomepageScreenState extends State<HomepageScreen> {
  final _repository = SightingsRepository.instance;

  bool _loading = true;
  String? _error;
  String _syncSummary = 'Caricamento...';
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
      final sightings =
          await _repository.getSightings(forceRefresh: forceRefresh);
      final syncSummary = await _repository.pendingOperationsSummary();

      if (!mounted) {
        return;
      }

      setState(() {
        _sightings = sightings;
        _syncSummary = syncSummary;
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

  String _formatDate(String iso) {
    final date = DateTime.tryParse(iso);
    if (date == null) {
      return '-';
    }
    return DateFormat('dd/MM/yyyy HH:mm').format(date.toLocal());
  }

  Color _markerColorForAnimal(String animal) {
    final normalized = animal.trim().toLowerCase();
    if (normalized.contains('balen')) {
      return const Color(0xFFA855F7); // violet
    }
    if (normalized.contains('delfin')) {
      return const Color(0xFF0EA5E9); // sky blue
    }
    if (normalized.contains('foca')) {
      return const Color(0xFF64748B); // slate gray
    }
    if (normalized.contains('razza')) {
      return const Color(0xFF14B8A6); // teal
    }
    if (normalized.contains('squal')) {
      return const Color(0xFFEF4444); // red
    }
    if (normalized.contains('tartarug')) {
      return const Color(0xFF10B981); // emerald green
    }
    if (normalized.contains('tonn')) {
      return const Color(0xFFF59E0B); // amber
    }
    return const Color(0xFF6B7280); // gray default
  }

  Future<void> _openSightingDetail(Avvistamento sighting) async {
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
  }

  Future<void> _showMarkerDetails(Avvistamento sighting) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sighting.specie ?? sighting.animale,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text('Animale: ${sighting.animale}'),
                Text('Data: ${_formatDate(sighting.data)}'),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _openSightingDetail(sighting);
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Apri dettaglio'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final background = Theme.of(context).scaffoldBackgroundColor;

    if (_loading) {
      return SafeArea(
        child: ColoredBox(
          color: background,
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_error != null) {
      return SafeArea(
        child: ColoredBox(
          color: background,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => _load(forceRefresh: true),
                    child: const Text('Riprova'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_sightings.isEmpty) {
      return SafeArea(
        child: ColoredBox(
          color: background,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Nessun avvistamento disponibile.'),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () => _load(forceRefresh: true),
                  child: const Text('Aggiorna'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final markers = _sightings.map((s) {
      final markerColor = _markerColorForAnimal(s.animale);
      return Marker(
        point: LatLng(s.latitudine, s.longitudine),
        width: 42,
        height: 42,
        child: Semantics(
          button: true,
          label: 'Marker ${s.animale}',
          child: GestureDetector(
            onTap: () => _showMarkerDetails(s),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.location_on, color: markerColor, size: 36),
                const Icon(Icons.circle, color: Colors.white, size: 11),
              ],
            ),
          ),
        ),
      );
    }).toList();

    final recent = _sightings.take(5).toList();

    return SafeArea(
      child: ColoredBox(
        color: background,
        child: RefreshIndicator(
          onRefresh: () => _load(forceRefresh: true),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.sync),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _syncSummary,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _load(forceRefresh: true),
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Aggiorna dati',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 280,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: LatLng(
                        _sightings.first.latitudine,
                        _sightings.first.longitudine,
                      ),
                      initialZoom: 9.5,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.seawatch',
                      ),
                      MarkerLayer(markers: markers),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Ultimi avvistamenti',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
              ...recent.map(
                (sighting) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.pets),
                    title: Text(sighting.specie ?? sighting.animale),
                    subtitle: Text(
                      '${_formatDate(sighting.data)}\n'
                      '${sighting.latitudine.toStringAsFixed(5)}, '
                      '${sighting.longitudine.toStringAsFixed(5)}',
                    ),
                    isThreeLine: true,
                    trailing: sighting.isPending
                        ? const Icon(Icons.cloud_upload, color: Colors.orange)
                        : const Icon(Icons.chevron_right),
                    onTap: () => _openSightingDetail(sighting),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
