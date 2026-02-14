import 'dart:io';

import 'package:seawatch/config/app_config.dart';
import 'package:seawatch/models/avvistamento.dart';
import 'package:seawatch/services/core/api_client.dart';
import 'package:seawatch/services/core/app_state_store.dart';

class SightingsRepository {
  SightingsRepository._();

  static final SightingsRepository instance = SightingsRepository._();

  static const String _opCreateSighting = 'create_sighting';
  static const String _opUpdateSighting = 'update_sighting';
  static const String _opDeleteSighting = 'delete_sighting';
  static const String _opUploadImage = 'upload_image';
  static const String _opCreateAnnotation = 'create_annotation';
  static const String _opUpdateAnnotation = 'update_annotation';
  static const String _opDeleteAnnotation = 'delete_annotation';

  final ApiClient _api = ApiClient();
  final AppStateStore _store = AppStateStore();

  bool _syncInProgress = false;

  String _opId() => DateTime.now().microsecondsSinceEpoch.toString();

  int _placeholderImageId(String operationId) {
    final parsed = int.tryParse(operationId);
    if (parsed != null) {
      return -parsed;
    }
    return -DateTime.now().millisecondsSinceEpoch;
  }

  List<Avvistamento> _sortSightings(List<Avvistamento> items) {
    final sorted = [...items];
    sorted.sort((a, b) => b.dataDateTime.compareTo(a.dataDateTime));
    return sorted;
  }

  Avvistamento? _findInCacheById(List<Avvistamento> cached, int id) {
    for (final item in cached) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  Future<List<Avvistamento>> _readCachedSightings() {
    return _store.readCachedSightings();
  }

  Future<void> _saveCachedSightings(List<Avvistamento> sightings) {
    return _store.saveCachedSightings(_sortSightings(sightings));
  }

  Future<List<PendingOperation>> _readPendingOpsSorted() async {
    final ops = await _store.readPendingOps();
    ops.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return ops;
  }

  Future<void> _savePendingOps(List<PendingOperation> ops) {
    return _store.savePendingOps(ops);
  }

  Future<void> _enqueue(PendingOperation operation) async {
    final ops = await _readPendingOpsSorted();
    ops.add(operation);
    await _savePendingOps(ops);
  }

  Future<void> _replaceSightingInCache(Avvistamento sighting) async {
    final current = await _readCachedSightings();
    final idx = current.indexWhere((s) => s.id == sighting.id);
    if (idx >= 0) {
      current[idx] = sighting;
    } else {
      current.add(sighting);
    }
    await _saveCachedSightings(current);
  }

  Future<void> _removeSightingFromCache(int sightingId) async {
    final current = await _readCachedSightings();
    current.removeWhere((s) => s.id == sightingId);
    await _saveCachedSightings(current);

    final images = await _store.readCachedImagesBySighting();
    images.remove(sightingId);
    await _store.saveCachedImagesBySighting(images);
  }

  Future<void> _replaceLocalSightingIdInCache({
    required int localId,
    required Avvistamento serverSighting,
  }) async {
    final current = await _readCachedSightings();
    final idx = current.indexWhere((s) => s.id == localId);
    if (idx >= 0) {
      current[idx] = serverSighting;
    } else {
      current.add(serverSighting);
    }

    await _saveCachedSightings(current);

    final images = await _store.readCachedImagesBySighting();
    if (images.containsKey(localId)) {
      images[serverSighting.id] = images[localId]!;
      images.remove(localId);
      await _store.saveCachedImagesBySighting(images);
    }
  }

  Future<UserLite> _currentUserOrFallback() async {
    final cached = await _store.getCachedProfile();
    if (cached != null) {
      return cached;
    }

    final userId = await _store.getCurrentUserId() ?? 0;
    final email = await _store.getCurrentUserEmail() ?? '';
    return UserLite(id: userId, email: email);
  }

  Future<void> _mergeCreatePayloadForLocalSighting(
    int localSightingId,
    Map<String, dynamic> partialUpdate,
  ) async {
    final ops = await _readPendingOpsSorted();
    final idx = ops.indexWhere(
      (op) =>
          op.type == _opCreateSighting &&
          op.payload['localId'] == localSightingId,
    );

    if (idx < 0) {
      return;
    }

    final payload = Map<String, dynamic>.from(ops[idx].payload);
    final dto = Map<String, dynamic>.from(payload['dto'] as Map? ?? const {});
    dto.addAll(partialUpdate);
    payload['dto'] = dto;

    ops[idx] = PendingOperation(
      id: ops[idx].id,
      type: ops[idx].type,
      payload: payload,
      createdAt: ops[idx].createdAt,
    );

    await _savePendingOps(ops);
  }

  Future<void> _upsertPendingUpdateOperation(
    int sightingId,
    Map<String, dynamic> updateDto,
  ) async {
    final ops = await _readPendingOpsSorted();
    final idx = ops.indexWhere(
      (op) =>
          op.type == _opUpdateSighting &&
          op.payload['sightingId'] == sightingId,
    );

    if (idx >= 0) {
      final payload = Map<String, dynamic>.from(ops[idx].payload);
      final existingDto =
          Map<String, dynamic>.from(payload['dto'] as Map? ?? const {});
      existingDto.addAll(updateDto);
      payload['dto'] = existingDto;

      ops[idx] = PendingOperation(
        id: ops[idx].id,
        type: ops[idx].type,
        payload: payload,
        createdAt: ops[idx].createdAt,
      );
    } else {
      ops.add(
        PendingOperation(
          id: _opId(),
          type: _opUpdateSighting,
          payload: {
            'sightingId': sightingId,
            'dto': updateDto,
          },
          createdAt: DateTime.now().toUtc(),
        ),
      );
    }

    await _savePendingOps(ops);
  }

  Future<void> _queueImageUpload(int sightingId, String filePath) async {
    await _enqueue(
      PendingOperation(
        id: _opId(),
        type: _opUploadImage,
        payload: {
          'sightingId': sightingId,
          'filePath': filePath,
        },
        createdAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> _upsertLocalImagePlaceholder(
      int sightingId, String filePath) async {
    final map = await _store.readCachedImagesBySighting();
    final list = [...(map[sightingId] ?? const <SightingImageItem>[])];

    final alreadyExists = list.any(
      (img) => img.pendingUpload && img.localPath == filePath,
    );

    if (!alreadyExists) {
      list.insert(
        0,
        SightingImageItem(
          id: _placeholderImageId(
              DateTime.now().microsecondsSinceEpoch.toString()),
          url: filePath,
          pendingUpload: true,
          localPath: filePath,
        ),
      );
    }

    map[sightingId] = list;
    await _store.saveCachedImagesBySighting(map);
  }

  Future<void> _removePendingImagePlaceholders(int sightingId) async {
    final map = await _store.readCachedImagesBySighting();
    final list = [...(map[sightingId] ?? const <SightingImageItem>[])];
    list.removeWhere((img) => img.pendingUpload);
    map[sightingId] = list;
    await _store.saveCachedImagesBySighting(map);
  }

  Future<int?> _resolveServerSightingId(
    int sightingId,
    Map<int, int> localToServer,
  ) async {
    if (sightingId > 0) {
      return sightingId;
    }
    return localToServer[sightingId];
  }

  Future<void> _refreshImagesCacheFromServer(int sightingId) async {
    final raw = await _api.getJsonList('/sighting-images/$sightingId/images');
    final images = raw.whereType<Map<String, dynamic>>().map((json) {
      final parsed = SightingImageItem.fromApiJson(json);
      return SightingImageItem(
        id: parsed.id,
        url: AppConfig.normalizeUrl(parsed.url),
        annotations: parsed.annotations,
      );
    }).toList();

    final cache = await _store.readCachedImagesBySighting();
    cache[sightingId] = images;
    await _store.saveCachedImagesBySighting(cache);
  }

  bool _isNetworkError(ApiException error) {
    final lower = error.message.toLowerCase();
    return lower.contains('timeout') ||
        lower.contains('connessione') ||
        lower.contains('connection') ||
        lower.contains('network');
  }

  Future<void> syncPending() async {
    if (_syncInProgress) {
      return;
    }

    final online = await _api.isBackendReachable();
    if (!online) {
      return;
    }

    _syncInProgress = true;
    try {
      final localToServer = await _store.readLocalIdMap();
      final operations = await _readPendingOpsSorted();
      if (operations.isEmpty) {
        return;
      }

      var index = 0;
      while (index < operations.length) {
        final op = operations[index];
        var keepCurrentAndStop = false;

        try {
          switch (op.type) {
            case _opCreateSighting:
              {
                final localId = (op.payload['localId'] as num).toInt();
                final dto = Map<String, dynamic>.from(
                    op.payload['dto'] as Map? ?? const {});

                final createdJson =
                    await _api.postJson('/sightings', body: dto);
                final created = Avvistamento.fromApiJson(createdJson);

                localToServer[localId] = created.id;
                await _store.saveLocalIdMap(localToServer);

                await _replaceLocalSightingIdInCache(
                  localId: localId,
                  serverSighting: created,
                );

                for (var i = index + 1; i < operations.length; i++) {
                  final payload =
                      Map<String, dynamic>.from(operations[i].payload);
                  final currentSightingId = payload['sightingId'];
                  if (currentSightingId == localId) {
                    payload['sightingId'] = created.id;
                    operations[i] = PendingOperation(
                      id: operations[i].id,
                      type: operations[i].type,
                      payload: payload,
                      createdAt: operations[i].createdAt,
                    );
                  }
                }
              }
              break;
            case _opUpdateSighting:
              {
                final payload = Map<String, dynamic>.from(op.payload);
                final dto = Map<String, dynamic>.from(
                    payload['dto'] as Map? ?? const {});
                final targetId = (payload['sightingId'] as num).toInt();
                final resolved =
                    await _resolveServerSightingId(targetId, localToServer);

                if (resolved == null) {
                  keepCurrentAndStop = true;
                  break;
                }

                final updatedJson =
                    await _api.putJson('/sightings/$resolved', body: dto);
                final updated = Avvistamento.fromApiJson(updatedJson);
                await _replaceSightingInCache(updated);
              }
              break;
            case _opDeleteSighting:
              {
                final targetId = (op.payload['sightingId'] as num).toInt();
                final resolved =
                    await _resolveServerSightingId(targetId, localToServer);
                if (resolved == null) {
                  await _removeSightingFromCache(targetId);
                  break;
                }

                await _api.delete('/sightings/$resolved');
                await _removeSightingFromCache(resolved);
              }
              break;
            case _opUploadImage:
              {
                final payload = Map<String, dynamic>.from(op.payload);
                final targetId = (payload['sightingId'] as num).toInt();
                final filePath = payload['filePath']?.toString() ?? '';
                final resolved =
                    await _resolveServerSightingId(targetId, localToServer);

                if (resolved == null) {
                  keepCurrentAndStop = true;
                  break;
                }

                if (filePath.isEmpty || !File(filePath).existsSync()) {
                  break;
                }

                await _api.uploadFile(
                  path: '/sighting-images/$resolved/upload',
                  fieldName: 'file',
                  filePath: filePath,
                );

                await _refreshImagesCacheFromServer(resolved);
                await _removePendingImagePlaceholders(targetId);
                if (targetId != resolved) {
                  await _removePendingImagePlaceholders(resolved);
                }
              }
              break;
            case _opCreateAnnotation:
              {
                final payload = Map<String, dynamic>.from(op.payload);
                final imageId = (payload['imageId'] as num).toInt();
                await _api
                    .postJson('/sighting-images/$imageId/annotations', body: {
                  'tl_x': payload['tl_x'],
                  'tl_y': payload['tl_y'],
                  'br_x': payload['br_x'],
                  'br_y': payload['br_y'],
                  'specimenName': payload['specimenName'],
                });

                final sightingId = (payload['sightingId'] as num?)?.toInt();
                if (sightingId != null && sightingId > 0) {
                  await _refreshImagesCacheFromServer(sightingId);
                }
              }
              break;
            case _opUpdateAnnotation:
              {
                final payload = Map<String, dynamic>.from(op.payload);
                final annotationId = (payload['annotationId'] as num).toInt();
                await _api.patchJson('/annotations/$annotationId', body: {
                  if (payload.containsKey('tl_x')) 'tl_x': payload['tl_x'],
                  if (payload.containsKey('tl_y')) 'tl_y': payload['tl_y'],
                  if (payload.containsKey('br_x')) 'br_x': payload['br_x'],
                  if (payload.containsKey('br_y')) 'br_y': payload['br_y'],
                  if (payload.containsKey('specimenName'))
                    'specimenName': payload['specimenName'],
                });

                final sightingId = (payload['sightingId'] as num?)?.toInt();
                if (sightingId != null && sightingId > 0) {
                  await _refreshImagesCacheFromServer(sightingId);
                }
              }
              break;
            case _opDeleteAnnotation:
              {
                final payload = Map<String, dynamic>.from(op.payload);
                final annotationId = (payload['annotationId'] as num).toInt();
                await _api.delete('/annotations/$annotationId');

                final sightingId = (payload['sightingId'] as num?)?.toInt();
                if (sightingId != null && sightingId > 0) {
                  await _refreshImagesCacheFromServer(sightingId);
                }
              }
              break;
            default:
              // Unknown op: drop it.
              break;
          }

          if (keepCurrentAndStop) {
            break;
          }

          operations.removeAt(index);
          await _savePendingOps(operations);
        } on ApiException catch (error) {
          if (error.isUnauthorized || _isNetworkError(error)) {
            break;
          }

          // Logical server error: drop only this op and continue.
          operations.removeAt(index);
          await _savePendingOps(operations);
        }
      }

      // Refresh sightings cache after successful partial/full sync.
      await getSightings(forceRefresh: true);
    } finally {
      _syncInProgress = false;
    }
  }

  Future<List<AnimalOption>> getAnimals({bool forceRefresh = false}) async {
    final online = await _api.isBackendReachable();

    if (online && forceRefresh) {
      try {
        final raw = await _api.getJsonList('/animals', authRequired: false);
        final animals = raw
            .whereType<Map<String, dynamic>>()
            .map(AnimalOption.fromJson)
            .toList();
        await _store.saveCachedAnimals(animals);
        return animals;
      } catch (_) {
        return _store.readCachedAnimals();
      }
    }

    final cached = await _store.readCachedAnimals();
    if (cached.isNotEmpty && !forceRefresh) {
      return cached;
    }

    if (!online) {
      return cached;
    }

    final raw = await _api.getJsonList('/animals', authRequired: false);
    final animals = raw
        .whereType<Map<String, dynamic>>()
        .map(AnimalOption.fromJson)
        .toList();
    await _store.saveCachedAnimals(animals);
    return animals;
  }

  Future<List<SpeciesOption>> getSpecies({
    int? animalId,
    bool forceRefresh = false,
  }) async {
    final online = await _api.isBackendReachable();

    if (online && (forceRefresh || animalId != null)) {
      try {
        final raw = await _api.getJsonList(
          '/species',
          query: animalId == null ? null : {'animalId': animalId.toString()},
          authRequired: false,
        );

        final species = raw
            .whereType<Map<String, dynamic>>()
            .map(SpeciesOption.fromJson)
            .toList();

        if (animalId == null) {
          await _store.saveCachedSpecies(species);
        } else {
          final cached = await _store.readCachedSpecies();
          final merged = <SpeciesOption>[
            ...cached.where((s) => s.animalId != animalId),
            ...species,
          ];
          await _store.saveCachedSpecies(merged);
        }

        return species;
      } catch (_) {
        // fallback below
      }
    }

    final cached = await _store.readCachedSpecies();
    if (animalId == null) {
      return cached;
    }

    return cached.where((s) => s.animalId == animalId).toList();
  }

  Future<List<Avvistamento>> getSightings({bool forceRefresh = false}) async {
    await syncPending();

    final online = await _api.isBackendReachable();
    if (!online) {
      return _sortSightings(await _readCachedSightings());
    }

    if (!forceRefresh) {
      final cached = await _readCachedSightings();
      if (cached.isNotEmpty) {
        return _sortSightings(cached);
      }
    }

    final response = await _api.getJsonMap('/sightings');
    final rawItems = response['items'];
    final serverSightings = rawItems is List
        ? rawItems
            .whereType<Map<String, dynamic>>()
            .map(Avvistamento.fromApiJson)
            .toList()
        : <Avvistamento>[];

    final local = await _readCachedSightings();
    final merged = <int, Avvistamento>{
      for (final s in serverSightings) s.id: s,
    };

    for (final localSighting in local) {
      if (localSighting.syncState == SyncState.pendingDelete) {
        merged.remove(localSighting.id);
        continue;
      }

      if (localSighting.id < 0 || localSighting.syncState != SyncState.synced) {
        merged[localSighting.id] = localSighting;
      }
    }

    final finalList = _sortSightings(merged.values.toList());
    await _saveCachedSightings(finalList);
    return finalList;
  }

  Future<Avvistamento?> getSightingById(int id,
      {bool forceRefresh = false}) async {
    if (id <= 0) {
      final localToServer = await _store.readLocalIdMap();
      final mappedId = localToServer[id];
      if (mappedId != null) {
        return getSightingById(mappedId, forceRefresh: forceRefresh);
      }

      final cached = await _readCachedSightings();
      return _findInCacheById(cached, id);
    }

    final online = await _api.isBackendReachable();
    if (!online && !forceRefresh) {
      final cached = await _readCachedSightings();
      return _findInCacheById(cached, id);
    }

    try {
      final raw = await _api.getJsonMap('/sightings/$id');
      final sighting = Avvistamento.fromApiJson(raw);
      await _replaceSightingInCache(sighting);
      return sighting;
    } catch (_) {
      final cached = await _readCachedSightings();
      return _findInCacheById(cached, id);
    }
  }

  Future<Avvistamento> createSighting(
    CreateSightingInput input, {
    List<String> imagePaths = const [],
  }) async {
    final online = await _api.isBackendReachable();

    if (online) {
      try {
        final createdRaw =
            await _api.postJson('/sightings', body: input.toApiJson());
        final created = Avvistamento.fromApiJson(createdRaw);
        await _replaceSightingInCache(created);

        for (final imagePath in imagePaths) {
          await uploadImage(created.id, imagePath);
        }

        return created;
      } on ApiException catch (error) {
        if (!error.isUnauthorized && !_isNetworkError(error)) {
          rethrow;
        }
      }
    }

    final user = await _currentUserOrFallback();
    final cachedAnimals = await _store.readCachedAnimals();
    final cachedSpecies = await _store.readCachedSpecies();
    String animalName = 'Animale';
    for (final animal in cachedAnimals) {
      if (animal.id == input.animalId) {
        animalName = animal.name;
        break;
      }
    }

    String? speciesName;
    if (input.speciesId != null) {
      for (final species in cachedSpecies) {
        if (species.id == input.speciesId) {
          speciesName = species.name;
          break;
        }
      }
    }
    final localId = -DateTime.now().millisecondsSinceEpoch;
    final localSighting = Avvistamento(
      id: localId,
      data: input.date.toUtc().toIso8601String(),
      latitudine: input.latitude,
      longitudine: input.longitude,
      animale: animalName,
      animalId: input.animalId,
      speciesId: input.speciesId,
      specie: speciesName,
      numeroEsemplari: input.specimens,
      vento: input.wind,
      mare: input.sea,
      note: input.notes,
      user: user,
      syncState: SyncState.pendingCreate,
    );

    await _replaceSightingInCache(localSighting);

    await _enqueue(
      PendingOperation(
        id: _opId(),
        type: _opCreateSighting,
        payload: {
          'localId': localId,
          'dto': input.toApiJson(),
        },
        createdAt: DateTime.now().toUtc(),
      ),
    );

    for (final imagePath in imagePaths) {
      await _queueImageUpload(localId, imagePath);
      await _upsertLocalImagePlaceholder(localId, imagePath);
    }

    return localSighting;
  }

  Future<Avvistamento> updateSighting(
    int sightingId,
    UpdateSightingInput input,
  ) async {
    if (sightingId <= 0) {
      final localToServer = await _store.readLocalIdMap();
      final mappedId = localToServer[sightingId];
      if (mappedId != null) {
        sightingId = mappedId;
      }
    }

    final updateDto = input.toApiJson();

    final current = await _readCachedSightings();
    final idx = current.indexWhere((s) => s.id == sightingId);
    if (idx >= 0) {
      final existing = current[idx];
      final updatedLocal = existing.copyWith(
        animalId: input.animalId ?? existing.animalId,
        speciesId: input.speciesId ?? existing.speciesId,
        vento: input.wind ?? existing.vento,
        mare: input.sea ?? existing.mare,
        note: input.notes ?? existing.note,
        syncState:
            sightingId > 0 ? SyncState.pendingUpdate : SyncState.pendingCreate,
      );
      current[idx] = updatedLocal;
      await _saveCachedSightings(current);
    }

    if (sightingId <= 0) {
      await _mergeCreatePayloadForLocalSighting(sightingId, updateDto);
      final refreshed = await _readCachedSightings();
      return refreshed.firstWhere((s) => s.id == sightingId);
    }

    final online = await _api.isBackendReachable();
    if (online) {
      try {
        final updatedRaw =
            await _api.putJson('/sightings/$sightingId', body: updateDto);
        final updated = Avvistamento.fromApiJson(updatedRaw);
        await _replaceSightingInCache(updated);
        return updated;
      } on ApiException catch (error) {
        if (error.isUnauthorized || !_isNetworkError(error)) {
          rethrow;
        }
      }
    }

    await _upsertPendingUpdateOperation(sightingId, updateDto);
    final refreshed = await _readCachedSightings();
    return refreshed.firstWhere((s) => s.id == sightingId);
  }

  Future<void> deleteSighting(int sightingId) async {
    if (sightingId <= 0) {
      final localToServer = await _store.readLocalIdMap();
      final mappedId = localToServer[sightingId];
      if (mappedId != null) {
        sightingId = mappedId;
      }
    }

    if (sightingId <= 0) {
      await _removeSightingFromCache(sightingId);

      final ops = await _readPendingOpsSorted();
      ops.removeWhere((op) {
        final target = (op.payload['sightingId'] as num?)?.toInt();
        final local = (op.payload['localId'] as num?)?.toInt();
        return target == sightingId || local == sightingId;
      });
      await _savePendingOps(ops);
      return;
    }

    await _removeSightingFromCache(sightingId);

    final online = await _api.isBackendReachable();
    if (online) {
      try {
        await _api.delete('/sightings/$sightingId');

        final ops = await _readPendingOpsSorted();
        ops.removeWhere((op) {
          final target = (op.payload['sightingId'] as num?)?.toInt();
          return target == sightingId && op.type != _opUploadImage;
        });
        await _savePendingOps(ops);
        return;
      } on ApiException catch (error) {
        if (error.isUnauthorized || !_isNetworkError(error)) {
          rethrow;
        }
      }
    }

    final ops = await _readPendingOpsSorted();
    ops.removeWhere((op) {
      final target = (op.payload['sightingId'] as num?)?.toInt();
      return target == sightingId &&
          (op.type == _opUpdateSighting || op.type == _opDeleteSighting);
    });
    ops.add(
      PendingOperation(
        id: _opId(),
        type: _opDeleteSighting,
        payload: {'sightingId': sightingId},
        createdAt: DateTime.now().toUtc(),
      ),
    );
    await _savePendingOps(ops);
  }

  Future<List<SightingImageItem>> getImagesForSighting(
    int sightingId, {
    bool forceRefresh = false,
  }) async {
    if (sightingId <= 0) {
      final localToServer = await _store.readLocalIdMap();
      final mappedId = localToServer[sightingId];
      if (mappedId != null) {
        return getImagesForSighting(mappedId, forceRefresh: forceRefresh);
      }
    }

    final cache = await _store.readCachedImagesBySighting();
    final cached = [...(cache[sightingId] ?? const <SightingImageItem>[])];

    final pendingOps = await _readPendingOpsSorted();
    final pendingUploads = pendingOps
        .where((op) => op.type == _opUploadImage)
        .where(
            (op) => (op.payload['sightingId'] as num?)?.toInt() == sightingId)
        .map((op) {
      final path = op.payload['filePath']?.toString() ?? '';
      return SightingImageItem(
        id: _placeholderImageId(op.id),
        url: path,
        pendingUpload: true,
        localPath: path,
      );
    }).toList();

    if (cached.isNotEmpty && !forceRefresh) {
      return [...pendingUploads, ...cached];
    }

    if (sightingId <= 0) {
      return [...pendingUploads, ...cached];
    }

    final online = await _api.isBackendReachable();
    if (!online) {
      return [...pendingUploads, ...cached];
    }

    await _refreshImagesCacheFromServer(sightingId);
    final updated = await _store.readCachedImagesBySighting();
    return [
      ...pendingUploads,
      ...(updated[sightingId] ?? const <SightingImageItem>[])
    ];
  }

  Future<void> uploadImage(int sightingId, String filePath) async {
    final online = await _api.isBackendReachable();
    final map = await _store.readLocalIdMap();
    final resolved = await _resolveServerSightingId(sightingId, map);

    if (online &&
        resolved != null &&
        resolved > 0 &&
        File(filePath).existsSync()) {
      try {
        await _api.uploadFile(
          path: '/sighting-images/$resolved/upload',
          fieldName: 'file',
          filePath: filePath,
        );

        await _refreshImagesCacheFromServer(resolved);
        if (sightingId != resolved) {
          await _removePendingImagePlaceholders(sightingId);
        }
        return;
      } on ApiException catch (error) {
        if (error.isUnauthorized || !_isNetworkError(error)) {
          rethrow;
        }
      }
    }

    await _queueImageUpload(sightingId, filePath);
    await _upsertLocalImagePlaceholder(sightingId, filePath);
  }

  Future<void> deleteImage({
    required int sightingId,
    required int imageId,
    String? localPath,
  }) async {
    if (imageId <= 0) {
      final imagesCache = await _store.readCachedImagesBySighting();
      final list = [
        ...(imagesCache[sightingId] ?? const <SightingImageItem>[])
      ];
      list.removeWhere((img) => img.id == imageId);
      imagesCache[sightingId] = list;
      await _store.saveCachedImagesBySighting(imagesCache);

      final ops = await _readPendingOpsSorted();
      var removed = false;
      ops.removeWhere((op) {
        if (op.type != _opUploadImage) {
          return false;
        }
        final opSightingId = (op.payload['sightingId'] as num?)?.toInt();
        if (opSightingId != sightingId) {
          return false;
        }
        if (localPath == null || localPath.isEmpty) {
          if (!removed) {
            removed = true;
            return true;
          }
          return false;
        }
        return op.payload['filePath'] == localPath;
      });
      await _savePendingOps(ops);
      return;
    }

    await _api.delete('/sighting-images/$imageId');
    await _refreshImagesCacheFromServer(sightingId);
  }

  Future<void> addAnnotation({
    required int sightingId,
    required int imageId,
    required double tlX,
    required double tlY,
    required double brX,
    required double brY,
    String? specimenName,
  }) async {
    final online = await _api.isBackendReachable();

    if (online) {
      try {
        await _api.postJson('/sighting-images/$imageId/annotations', body: {
          'tl_x': tlX,
          'tl_y': tlY,
          'br_x': brX,
          'br_y': brY,
          'specimenName': specimenName,
        });
        await _refreshImagesCacheFromServer(sightingId);
        return;
      } on ApiException catch (error) {
        if (error.isUnauthorized || !_isNetworkError(error)) {
          rethrow;
        }
      }
    }

    await _enqueue(
      PendingOperation(
        id: _opId(),
        type: _opCreateAnnotation,
        payload: {
          'sightingId': sightingId,
          'imageId': imageId,
          'tl_x': tlX,
          'tl_y': tlY,
          'br_x': brX,
          'br_y': brY,
          'specimenName': specimenName,
        },
        createdAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> updateAnnotation({
    required int sightingId,
    required int annotationId,
    double? tlX,
    double? tlY,
    double? brX,
    double? brY,
    String? specimenName,
  }) async {
    final body = <String, dynamic>{
      if (tlX != null) 'tl_x': tlX,
      if (tlY != null) 'tl_y': tlY,
      if (brX != null) 'br_x': brX,
      if (brY != null) 'br_y': brY,
      if (specimenName != null) 'specimenName': specimenName,
    };

    final online = await _api.isBackendReachable();
    if (online) {
      try {
        await _api.patchJson('/annotations/$annotationId', body: body);
        await _refreshImagesCacheFromServer(sightingId);
        return;
      } on ApiException catch (error) {
        if (error.isUnauthorized || !_isNetworkError(error)) {
          rethrow;
        }
      }
    }

    await _enqueue(
      PendingOperation(
        id: _opId(),
        type: _opUpdateAnnotation,
        payload: {
          'sightingId': sightingId,
          'annotationId': annotationId,
          ...body,
        },
        createdAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> deleteAnnotation({
    required int sightingId,
    required int annotationId,
  }) async {
    final online = await _api.isBackendReachable();
    if (online) {
      try {
        await _api.delete('/annotations/$annotationId');
        await _refreshImagesCacheFromServer(sightingId);
        return;
      } on ApiException catch (error) {
        if (error.isUnauthorized || !_isNetworkError(error)) {
          rethrow;
        }
      }
    }

    await _enqueue(
      PendingOperation(
        id: _opId(),
        type: _opDeleteAnnotation,
        payload: {
          'sightingId': sightingId,
          'annotationId': annotationId,
        },
        createdAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<List<String>> runRecognition(int sightingId) async {
    final result =
        await _api.postJson('/sightings/$sightingId/recognition', body: {});
    if (result['state'] == true && result['data'] is List) {
      return (result['data'] as List).map((e) => e.toString()).toList();
    }
    return const [];
  }

  Future<bool> hasPendingOperations() async {
    final ops = await _store.readPendingOps();
    return ops.isNotEmpty;
  }

  Future<String> pendingOperationsSummary() async {
    final ops = await _store.readPendingOps();
    if (ops.isEmpty) {
      return 'Nessuna modifica in coda';
    }

    final grouped = <String, int>{};
    for (final op in ops) {
      grouped[op.type] = (grouped[op.type] ?? 0) + 1;
    }

    final lines = grouped.entries
        .map((e) => '${e.key}: ${e.value}')
        .toList(growable: false);
    return 'Operazioni offline in coda (${ops.length}) - ${lines.join(', ')}';
  }
}
