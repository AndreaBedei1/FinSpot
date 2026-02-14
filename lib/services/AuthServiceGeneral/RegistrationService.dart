import 'package:seawatch/services/AuthServiceGeneral/AuthService.dart';
import 'package:seawatch/services/core/api_client.dart';

class RegistrationService {
  RegistrationService({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  Future<void> register(
    String nome,
    String cognome,
    String email,
    String password,
  ) async {
    final normalizedEmail = email.trim().toLowerCase();

    await _api.postJson(
      '/auth/register',
      body: {
        'email': normalizedEmail,
        'password': password,
        'firstName': nome.trim(),
        'lastName': cognome.trim(),
      },
      authRequired: false,
    );

    // Reuse login flow so local session, profile cache and offline hash are consistent.
    await AuthService().login(normalizedEmail, password);
  }
}
