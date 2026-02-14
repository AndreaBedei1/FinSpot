import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:seawatch/config/app_config.dart';
import 'package:seawatch/models/avvistamento.dart';
import 'package:seawatch/services/core/api_client.dart';
import 'package:seawatch/services/core/app_state_store.dart';
import 'package:seawatch/services/sightings/sightings_repository.dart';

class AuthService {
  AuthService({
    ApiClient? api,
    AppStateStore? store,
  })  : _api = api ?? ApiClient(),
        _store = store ?? AppStateStore();

  final ApiClient _api;
  final AppStateStore _store;

  String _normalizeEmail(String email) => email.trim().toLowerCase();

  String? _normalizeOptionalUrl(dynamic value) {
    final raw = value?.toString();
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    return AppConfig.normalizeUrl(raw.trim());
  }

  UserLite _normalizeUserImage(UserLite user) {
    final normalized = _normalizeOptionalUrl(user.img);
    if (normalized == user.img) {
      return user;
    }
    return UserLite(
      id: user.id,
      email: user.email,
      firstName: user.firstName,
      lastName: user.lastName,
      img: normalized,
    );
  }

  String _randomSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  String _hashOfflinePassword({
    required String email,
    required String password,
    required String salt,
  }) {
    final payload = '$email|$salt|$password';
    return sha256.convert(utf8.encode(payload)).toString();
  }

  Future<void> _cacheOfflinePassword(String email, String password) async {
    final salt = _randomSalt();
    final hash = _hashOfflinePassword(
      email: email,
      password: password,
      salt: salt,
    );

    await _store.saveOfflineCredentials(
      email: email,
      salt: salt,
      hash: hash,
    );
  }

  Future<void> login(String email, String password) async {
    final normalizedEmail = _normalizeEmail(email);

    final loginResponse = await _api.postJson(
      '/auth/login',
      body: {
        'email': normalizedEmail,
        'password': password,
      },
      authRequired: false,
    );

    final token = loginResponse['access_token']?.toString();
    if (token == null || token.isEmpty) {
      throw const ApiException('Login non riuscito: token non ricevuto');
    }

    // Save token immediately so authenticated calls can proceed.
    await _store.saveSession(
      token: token,
      userId: 0,
      email: normalizedEmail,
    );

    final me = await _api.getJsonMap('/auth/me');
    final userId =
        (me['userId'] as num?)?.toInt() ?? (me['id'] as num?)?.toInt() ?? 0;
    final emailFromToken = (me['email'] ?? normalizedEmail).toString();

    String? firstName;
    String? lastName;
    String? avatar;
    try {
      final userRaw = await _api.getJsonMap('/users/me');
      firstName = userRaw['firstName']?.toString();
      lastName = userRaw['lastName']?.toString();
      avatar = _normalizeOptionalUrl(userRaw['img']);
    } catch (_) {
      // Keep minimal profile if /users/me is temporarily unavailable.
    }

    await _store.saveSession(
      token: token,
      userId: userId,
      email: emailFromToken,
      firstName: firstName,
      lastName: lastName,
      avatar: avatar,
    );

    await _cacheOfflinePassword(emailFromToken, password);

    // Trigger an early sync of offline changes from previous sessions.
    await SightingsRepository.instance.syncPending();
  }

  Future<bool> loginOffline(String email, String password) async {
    final normalizedEmail = _normalizeEmail(email);

    final isAuthenticated = await _store.isAuthenticated();
    final token = await _store.getToken();
    if (!isAuthenticated || token == null || token.isEmpty) {
      return false;
    }

    final credentials = await _store.getOfflineCredentials();
    if (credentials == null) {
      return false;
    }

    final savedEmail = credentials['email']!;
    final salt = credentials['salt']!;
    final savedHash = credentials['hash']!;

    if (savedEmail != normalizedEmail) {
      return false;
    }

    final providedHash = _hashOfflinePassword(
      email: normalizedEmail,
      password: password,
      salt: salt,
    );

    return providedHash == savedHash;
  }

  Future<void> attemptLogin(String email, String password) async {
    try {
      await login(email, password);
    } on ApiException catch (error) {
      final offlineOk = await loginOffline(email, password);
      if (!offlineOk) {
        throw ApiException(
          'Login fallito. ${error.message}',
          statusCode: error.statusCode,
        );
      }
    } catch (_) {
      final offlineOk = await loginOffline(email, password);
      if (!offlineOk) {
        rethrow;
      }
    }
  }

  Future<bool> checkSession() async {
    final isAuthenticated = await _store.isAuthenticated();
    final token = await _store.getToken();

    if (!isAuthenticated || token == null || token.isEmpty) {
      return false;
    }

    final online = await _api.isBackendReachable();
    if (!online) {
      return true;
    }

    try {
      await _api.getJsonMap('/auth/me');
      return true;
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await _store.clearSession();
        return false;
      }
      return true;
    }
  }

  Future<void> logout() async {
    await _store.clearSession();
  }

  Future<UserLite?> getCurrentUser({bool refreshFromServer = true}) async {
    if (refreshFromServer && await _api.isBackendReachable()) {
      try {
        final raw = await _api.getJsonMap('/users/me');
        final user = UserLite(
          id: (raw['id'] as num?)?.toInt() ?? 0,
          email: (raw['email'] ?? '').toString(),
          firstName: raw['firstName']?.toString(),
          lastName: raw['lastName']?.toString(),
          img: _normalizeOptionalUrl(raw['img']),
        );
        await _store.updateCachedProfile(user);
        return user;
      } catch (_) {
        // fall back below
      }
    }

    final cached = await _store.getCachedProfile();
    if (cached == null) {
      return null;
    }

    final normalized = _normalizeUserImage(cached);
    if (normalized.img != cached.img) {
      await _store.updateCachedProfile(normalized);
    }
    return normalized;
  }

  Future<UserLite> updateProfile({
    required String firstName,
    required String lastName,
  }) async {
    final online = await _api.isBackendReachable();

    if (!online) {
      final cached = await _store.getCachedProfile();
      if (cached == null) {
        throw const ApiException('Nessun profilo locale disponibile.');
      }

      final updated = UserLite(
        id: cached.id,
        email: cached.email,
        firstName: firstName,
        lastName: lastName,
        img: cached.img,
      );

      await _store.updateCachedProfile(updated);
      return updated;
    }

    await _api.putJson(
      '/users/me',
      body: {
        'firstName': firstName,
        'lastName': lastName,
      },
    );

    final refreshed = await getCurrentUser(refreshFromServer: true);
    if (refreshed == null) {
      throw const ApiException('Errore aggiornando il profilo utente.');
    }

    return refreshed;
  }

  Future<String> uploadAvatar(String filePath) async {
    final online = await _api.isBackendReachable();
    if (!online) {
      throw const ApiException('Upload avatar disponibile solo online.');
    }

    const fieldNames = ['file', 'avatar', 'image'];
    Map<String, dynamic>? raw;
    ApiException? lastError;

    for (final fieldName in fieldNames) {
      try {
        raw = await _api.uploadFile(
          path: '/users/upload-avatar',
          fieldName: fieldName,
          filePath: filePath,
        );
        break;
      } on ApiException catch (error) {
        lastError = error;
      }
    }

    if (raw == null) {
      throw lastError ?? const ApiException('Upload avatar fallito.');
    }

    final imgUrl = _normalizeOptionalUrl(raw['imgUrl'] ?? raw['img']);
    if (imgUrl == null || imgUrl.isEmpty) {
      throw const ApiException('Upload avatar fallito.');
    }

    final current = await _store.getCachedProfile();
    if (current != null) {
      await _store.updateCachedProfile(
        UserLite(
          id: current.id,
          email: current.email,
          firstName: current.firstName,
          lastName: current.lastName,
          img: imgUrl,
        ),
      );
    }

    return imgUrl;
  }

  Future<void> changePasswordDirect({
    required String oldPassword,
    required String newPassword,
  }) async {
    final online = await _api.isBackendReachable();
    if (!online) {
      throw const ApiException('Cambio password disponibile solo online.');
    }

    await _api.putJson(
      '/users/change-password',
      body: {
        'oldPassword': oldPassword,
        'newPassword': newPassword,
      },
    );
  }

  Future<void> changePassword(
    BuildContext context,
    String email,
    String oldPassword,
    String newPassword,
  ) async {
    try {
      await changePasswordDirect(
        oldPassword: oldPassword,
        newPassword: newPassword,
      );
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password aggiornata con successo.')),
      );
    } on ApiException catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }
}
