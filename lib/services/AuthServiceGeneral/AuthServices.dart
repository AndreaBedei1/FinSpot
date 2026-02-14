import 'package:seawatch/services/AuthServiceGeneral/AuthService.dart';
import 'package:seawatch/services/core/api_client.dart';

class AuthServices {
  final AuthService _authService;

  AuthServices({AuthService? authService})
      : _authService = authService ?? AuthService();

  Future<Map<String, dynamic>> changePassword(
    String user,
    String oldPassword,
    String newPassword,
  ) async {
    try {
      await _authService.changePasswordDirect(
        oldPassword: oldPassword,
        newPassword: newPassword,
      );
      return {
        'success': true,
        'message': 'Password cambiata con successo.',
      };
    } on ApiException catch (error) {
      return {
        'success': false,
        'message': error.message,
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Errore durante il cambio password.',
      };
    }
  }
}
