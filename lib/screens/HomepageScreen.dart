import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_popup/flutter_map_marker_popup.dart';
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
  final PopupController _popupController = PopupController();

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

  DateTime _parseDateOrEpoch(String iso) {
    return DateTime.tryParse(iso)?.toLocal() ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  List<Avvistamento> _sortByDateDesc(List<Avvistamento> sightings) {
    final copy = [...sightings];
    copy.sort((a, b) =>
        _parseDateOrEpoch(b.data).compareTo(_parseDateOrEpoch(a.data)));
    return copy;
  }

  String _displayName(Avvistamento sighting) {
    return sighting.specie ?? sighting.animale;
  }

  Color _markerColorForAnimal(String animal) {
    final normalized = animal.trim().toLowerCase();
    if (normalized.contains('balen')) {
      return const Color(0xFFA855F7);
    }
    if (normalized.contains('delfin')) {
      return const Color(0xFF0EA5E9);
    }
    if (normalized.contains('foca')) {
      return const Color(0xFF64748B);
    }
    if (normalized.contains('razza')) {
      return const Color(0xFF14B8A6);
    }
    if (normalized.contains('squal')) {
      return const Color(0xFFEF4444);
    }
    if (normalized.contains('tartarug')) {
      return const Color(0xFF10B981);
    }
    if (normalized.contains('tonn')) {
      return const Color(0xFFF59E0B);
    }
    return const Color(0xFF6B7280);
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

  Widget _markerPin(Color color) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black26)],
          ),
        ),
        Icon(Icons.location_on, color: color, size: 40),
        const Positioned(
          top: 11,
          child: CircleAvatar(radius: 5, backgroundColor: Colors.white),
        ),
      ],
    );
  }

  List<Marker> _buildMarkers(List<Avvistamento> items) {
    return items.map((sighting) {
      final label = _displayName(sighting);
      return Marker(
        key: ValueKey<int>(sighting.id),
        point: LatLng(sighting.latitudine, sighting.longitudine),
        width: 44,
        height: 44,
        rotate: false,
        alignment: Alignment.topCenter,
        child: Semantics(
          button: true,
          label: 'Marker ${sighting.animale}',
          child: _markerPin(_markerColorForAnimal(label)),
        ),
      );
    }).toList();
  }

  Widget _popupInfoRow({
    required BuildContext context,
    required IconData icon,
    required String text,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.secondary),
        const SizedBox(width: 6),
              Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.75),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _compactPopup(BuildContext context, Avvistamento sighting) {
    final theme = Theme.of(context);
    final specie = _displayName(sighting);
    final color = _markerColorForAnimal(specie);
    final data = _formatDate(sighting.data);
    final esemplari = sighting.numeroEsemplari.toString();

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: DecoratedBox(
          decoration: BoxDecoration(
          color: theme.colorScheme.surface.withOpacity(0.95),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
          boxShadow: const [
            BoxShadow(
                blurRadius: 8, color: Colors.black26, offset: Offset(0, 2)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.location_on, color: color, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      specie,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: () => _popupController.hideAllPopups(),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close, size: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _popupInfoRow(
                context: context,
                icon: Icons.calendar_today,
                text: data,
              ),
              const SizedBox(height: 4),
              _popupInfoRow(
                context: context,
                icon: Icons.pets,
                text: 'Esemplari: $esemplari',
              ),
              const SizedBox(height: 4),
              _popupInfoRow(
                context: context,
                icon: Icons.gps_fixed,
                text:
                    '${sighting.latitudine.toStringAsFixed(4)}, ${sighting.longitudine.toStringAsFixed(4)}',
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Dettagli'),
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    _popupController.hideAllPopups();
                    _openSightingDetail(sighting);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
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

    final sortedSightings = _sortByDateDesc(_sightings);
    final recent = sortedSightings.take(5).toList();
    final markers = _buildMarkers(sortedSightings);

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
                height: 330,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    children: [
                      FlutterMap(
                        options: MapOptions(
                          initialCenter: LatLng(
                            sortedSightings.first.latitudine,
                            sortedSightings.first.longitudine,
                          ),
                          initialZoom: 9.5,
                          onTap: (_, __) => _popupController.hideAllPopups(),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.seawatch',
                          ),
                          PopupMarkerLayerWidget(
                            options: PopupMarkerLayerOptions(
                              popupController: _popupController,
                              markers: markers,
                              markerTapBehavior:
                                  MarkerTapBehavior.togglePopup(),
                              popupDisplayOptions: PopupDisplayOptions(
                                snap: PopupSnap.markerTop,
                                builder: (popupContext, marker) {
                                  final key = marker.key;
                                  if (key is ValueKey<int>) {
                                    final id = key.value;
                                    final sighting = sortedSightings.firstWhere(
                                      (item) => item.id == id,
                                      orElse: () => sortedSightings.first,
                                    );
                                    return _compactPopup(
                                        popupContext, sighting);
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
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
                    leading: Icon(
                      Icons.location_on,
                      color: _markerColorForAnimal(_displayName(sighting)),
                    ),
                    title: Text(_displayName(sighting)),
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
