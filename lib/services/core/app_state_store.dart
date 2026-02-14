import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:seawatch/models/avvistamento.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppStateStore {
  static const _tokenKey = 'jwt_token';
  static const _isAuthenticatedKey = 'is_authenticated'; // legacy key
  static const _userIdKey = 'user_id';
  static const _userEmailKey = 'user_email';
  static const _firstNameKey = 'first_name';
  static const _lastNameKey = 'last_name';
  static const _avatarKey = 'avatar_url';

  static const _offlineEmailKey = 'offline_email';
  static const _offlinePasswordSaltKey = 'offline_password_salt';
  static const _offlinePasswordHashKey = 'offline_password_hash';

  static const _cachedSightingsKey = 'cached_sightings_v2';
  static const _cachedAnimalsKey = 'cached_animals_v1';
  static const _cachedSpeciesKey = 'cached_species_v1';
  static const _cachedImagesBySightingKey = 'cached_images_by_sighting_v1';
  static const _pendingOpsKey = 'pending_ops_v1';
  static const _localIdMapKey = 'local_sighting_id_map_v1';

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  Future<SharedPreferences> get _prefs async {
    return SharedPreferences.getInstance();
  }

  Future<String?> _readSensitiveValue(String key) async {
    final secure = await _secureStorage.read(key: key);
    if (secure != null && secure.isNotEmpty) {
      return secure;
    }

    final prefs = await _prefs;
    final legacy = prefs.getString(key);
    if (legacy != null && legacy.isNotEmpty) {
      await _secureStorage.write(key: key, value: legacy);
      await prefs.remove(key);
      return legacy;
    }

    return null;
  }

  Future<void> _writeSensitiveValue(String key, String value) async {
    await _secureStorage.write(key: key, value: value);
    final prefs = await _prefs;
    if (prefs.containsKey(key)) {
      await prefs.remove(key);
    }
  }

  Future<void> _removeSensitiveValue(String key) async {
    await _secureStorage.delete(key: key);
    final prefs = await _prefs;
    if (prefs.containsKey(key)) {
      await prefs.remove(key);
    }
  }

  Future<bool> isAuthenticated() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  Future<String?> getToken() async {
    return _readSensitiveValue(_tokenKey);
  }

  Future<void> saveSession({
    required String token,
    required int userId,
    required String email,
    String? firstName,
    String? lastName,
    String? avatar,
  }) async {
    final prefs = await _prefs;
    await _writeSensitiveValue(_tokenKey, token);
    if (prefs.containsKey(_isAuthenticatedKey)) {
      await prefs.remove(_isAuthenticatedKey);
    }
    await prefs.setInt(_userIdKey, userId);
    await prefs.setString(_userEmailKey, email);
    if (firstName != null) {
      await prefs.setString(_firstNameKey, firstName);
    }
    if (lastName != null) {
      await prefs.setString(_lastNameKey, lastName);
    }
    if (avatar != null) {
      await prefs.setString(_avatarKey, avatar);
    }
  }

  Future<void> updateCachedProfile(UserLite user) async {
    final prefs = await _prefs;
    await prefs.setInt(_userIdKey, user.id);
    await prefs.setString(_userEmailKey, user.email);
    if (user.firstName != null) {
      await prefs.setString(_firstNameKey, user.firstName!);
    }
    if (user.lastName != null) {
      await prefs.setString(_lastNameKey, user.lastName!);
    }
    if (user.img != null) {
      await prefs.setString(_avatarKey, user.img!);
    }
  }

  Future<UserLite?> getCachedProfile() async {
    final prefs = await _prefs;
    final email = prefs.getString(_userEmailKey);
    final id = prefs.getInt(_userIdKey);
    if (email == null || id == null) {
      return null;
    }

    return UserLite(
      id: id,
      email: email,
      firstName: prefs.getString(_firstNameKey),
      lastName: prefs.getString(_lastNameKey),
      img: prefs.getString(_avatarKey),
    );
  }

  Future<int?> getCurrentUserId() async {
    final prefs = await _prefs;
    return prefs.getInt(_userIdKey);
  }

  Future<String?> getCurrentUserEmail() async {
    final prefs = await _prefs;
    return prefs.getString(_userEmailKey);
  }

  Future<void> saveOfflineCredentials({
    required String email,
    required String salt,
    required String hash,
  }) async {
    await _writeSensitiveValue(_offlineEmailKey, email);
    await _writeSensitiveValue(_offlinePasswordSaltKey, salt);
    await _writeSensitiveValue(_offlinePasswordHashKey, hash);
  }

  Future<Map<String, String>?> getOfflineCredentials() async {
    final email = await _readSensitiveValue(_offlineEmailKey);
    final salt = await _readSensitiveValue(_offlinePasswordSaltKey);
    final hash = await _readSensitiveValue(_offlinePasswordHashKey);
    if (email == null || salt == null || hash == null) {
      return null;
    }
    return {
      'email': email,
      'salt': salt,
      'hash': hash,
    };
  }

  Future<void> clearSession() async {
    final prefs = await _prefs;
    await _removeSensitiveValue(_tokenKey);
    await prefs.remove(_isAuthenticatedKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_userEmailKey);
    await prefs.remove(_firstNameKey);
    await prefs.remove(_lastNameKey);
    await prefs.remove(_avatarKey);

    await _removeSensitiveValue(_offlineEmailKey);
    await _removeSensitiveValue(_offlinePasswordSaltKey);
    await _removeSensitiveValue(_offlinePasswordHashKey);

    await prefs.remove(_cachedSightingsKey);
    await prefs.remove(_cachedAnimalsKey);
    await prefs.remove(_cachedSpeciesKey);
    await prefs.remove(_cachedImagesBySightingKey);
    await prefs.remove(_pendingOpsKey);
    await prefs.remove(_localIdMapKey);
  }

  Future<List<Avvistamento>> readCachedSightings() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_cachedSightingsKey);
    if (raw == null || raw.isEmpty) {
      return <Avvistamento>[];
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return <Avvistamento>[];
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(Avvistamento.fromLocalJson)
        .toList();
  }

  Future<void> saveCachedSightings(List<Avvistamento> sightings) async {
    final prefs = await _prefs;
    final raw = jsonEncode(sightings.map((s) => s.toLocalJson()).toList());
    await prefs.setString(_cachedSightingsKey, raw);
  }

  Future<List<AnimalOption>> readCachedAnimals() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_cachedAnimalsKey);
    if (raw == null || raw.isEmpty) {
      return <AnimalOption>[];
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return <AnimalOption>[];
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(AnimalOption.fromJson)
        .toList();
  }

  Future<void> saveCachedAnimals(List<AnimalOption> animals) async {
    final prefs = await _prefs;
    final raw = jsonEncode(animals.map((a) => a.toJson()).toList());
    await prefs.setString(_cachedAnimalsKey, raw);
  }

  Future<List<SpeciesOption>> readCachedSpecies() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_cachedSpeciesKey);
    if (raw == null || raw.isEmpty) {
      return <SpeciesOption>[];
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return <SpeciesOption>[];
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(SpeciesOption.fromJson)
        .toList();
  }

  Future<void> saveCachedSpecies(List<SpeciesOption> species) async {
    final prefs = await _prefs;
    final raw = jsonEncode(species.map((s) => s.toJson()).toList());
    await prefs.setString(_cachedSpeciesKey, raw);
  }

  Future<Map<int, List<SightingImageItem>>> readCachedImagesBySighting() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_cachedImagesBySightingKey);
    if (raw == null || raw.isEmpty) {
      return <int, List<SightingImageItem>>{};
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return <int, List<SightingImageItem>>{};
    }

    final result = <int, List<SightingImageItem>>{};
    for (final entry in decoded.entries) {
      final sightingId = int.tryParse(entry.key);
      if (sightingId == null) {
        continue;
      }

      final value = entry.value;
      if (value is! List) {
        continue;
      }

      result[sightingId] = value
          .whereType<Map<String, dynamic>>()
          .map(SightingImageItem.fromLocalJson)
          .toList();
    }

    return result;
  }

  Future<void> saveCachedImagesBySighting(
    Map<int, List<SightingImageItem>> map,
  ) async {
    final prefs = await _prefs;
    final serializable = <String, dynamic>{};
    for (final entry in map.entries) {
      serializable[entry.key.toString()] =
          entry.value.map((image) => image.toLocalJson()).toList();
    }

    await prefs.setString(_cachedImagesBySightingKey, jsonEncode(serializable));
  }

  Future<List<PendingOperation>> readPendingOps() async {
    final prefs = await _prefs;
    return PendingOperation.decodeList(prefs.getString(_pendingOpsKey));
  }

  Future<void> savePendingOps(List<PendingOperation> operations) async {
    final prefs = await _prefs;
    await prefs.setString(
        _pendingOpsKey, PendingOperation.encodeList(operations));
  }

  Future<Map<int, int>> readLocalIdMap() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_localIdMapKey);
    if (raw == null || raw.isEmpty) {
      return <int, int>{};
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return <int, int>{};
    }

    final out = <int, int>{};
    for (final entry in decoded.entries) {
      final local = int.tryParse(entry.key);
      final server = (entry.value as num?)?.toInt();
      if (local != null && server != null) {
        out[local] = server;
      }
    }
    return out;
  }

  Future<void> saveLocalIdMap(Map<int, int> map) async {
    final prefs = await _prefs;
    final serializable = <String, dynamic>{};
    for (final entry in map.entries) {
      serializable[entry.key.toString()] = entry.value;
    }
    await prefs.setString(_localIdMapKey, jsonEncode(serializable));
  }
}
