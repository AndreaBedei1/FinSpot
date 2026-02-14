import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:seawatch/models/avvistamento.dart';
import 'package:seawatch/services/sightings/sightings_repository.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final _repository = SightingsRepository.instance;

  bool _loading = true;
  String? _error;
  List<Avvistamento> _sightings = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final sightings = await _repository.getSightings();
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
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _load,
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
          child: const Center(child: Text('Nessun avvistamento disponibile.')),
        ),
      );
    }

    final totalSightings = _sightings.length;
    final totalSpecimens = _sightings.fold<int>(
      0,
      (acc, s) => acc + s.numeroEsemplari,
    );

    final bySpecies = <String, int>{};
    for (final s in _sightings) {
      final key = (s.specie ?? s.animale).trim();
      bySpecies[key] = (bySpecies[key] ?? 0) + 1;
    }

    final daily = <DateTime, int>{};
    final dayFmt = DateFormat('dd/MM');
    for (final s in _sightings) {
      final d = s.dataDateTime.toLocal();
      final day = DateTime(d.year, d.month, d.day);
      daily[day] = (daily[day] ?? 0) + s.numeroEsemplari;
    }

    final sortedDays = daily.keys.toList()..sort();

    final dayEntries = sortedDays
        .map((k) => MapEntry<String, int>(dayFmt.format(k), daily[k] ?? 0))
        .toList(growable: false);

    final speciesEntries = bySpecies.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final speciesSummary = speciesEntries
        .map((e) => '${e.key}: ${e.value}')
        .toList(growable: false)
        .join(', ');

    return SafeArea(
      child: ColoredBox(
        color: background,
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Avvistamenti totali: $totalSightings'),
                      const SizedBox(height: 6),
                      Text('Esemplari totali osservati: $totalSpecimens'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Esemplari per giorno',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 220,
                        child: Semantics(
                          label:
                              'Grafico a barre degli esemplari osservati per giorno.',
                          value: dayEntries
                              .map((e) => '${e.key}: ${e.value}')
                              .join(', '),
                          child: BarChart(
                            BarChartData(
                              borderData: FlBorderData(show: false),
                              gridData: const FlGridData(show: true),
                              titlesData: FlTitlesData(
                                topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                leftTitles: const AxisTitles(
                                  sideTitles: SideTitles(
                                      showTitles: true, reservedSize: 28),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      final idx = value.toInt();
                                      if (idx < 0 || idx >= dayEntries.length) {
                                        return const SizedBox.shrink();
                                      }
                                      return Text(dayEntries[idx].key,
                                          style: const TextStyle(fontSize: 10));
                                    },
                                  ),
                                ),
                              ),
                              barGroups:
                                  dayEntries.asMap().entries.map((entry) {
                                return BarChartGroupData(
                                  x: entry.key,
                                  barRods: [
                                    BarChartRodData(
                                      toY: entry.value.value.toDouble(),
                                      color: Colors.blue,
                                      width: 18,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Distribuzione specie',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 180,
                        child: Semantics(
                          label: 'Grafico a torta della distribuzione specie.',
                          value: speciesSummary,
                          child: PieChart(
                            PieChartData(
                              sections:
                                  speciesEntries.asMap().entries.map((entry) {
                                final idx = entry.key;
                                final species = entry.value;
                                return PieChartSectionData(
                                  value: species.value.toDouble(),
                                  title: '${species.value}',
                                  radius: 50,
                                  color: Colors
                                      .primaries[idx % Colors.primaries.length],
                                );
                              }).toList(),
                              sectionsSpace: 2,
                              centerSpaceRadius: 28,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...speciesEntries.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final species = entry.value;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                color: Colors
                                    .primaries[idx % Colors.primaries.length],
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text(species.key)),
                              Text(species.value.toString()),
                            ],
                          ),
                        );
                      }),
                    ],
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
