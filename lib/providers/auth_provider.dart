import 'package:nextone/models/auth_models.dart';
import 'package:nextone/services/auth_service.dart';

class AuthProvider {
  AuthProvider({AuthService? authService})
    : _authService = authService ?? AuthService();

  final AuthService _authService;

  Future<String?> login({
    required String email,
    required String phoneNumber,
    required String password,
  }) {
    return _authService.login(
      email: email,
      phoneNumber: phoneNumber,
      password: password,
    );
  }

  Future<String?> register({
    required String email,
    required String firstName,
    required String lastName,
    required String phoneNumber,
    required String password,
    required String role,
  }) {
    return _authService.register(
      email: email,
      firstName: firstName,
      lastName: lastName,
      phoneNumber: phoneNumber,
      password: password,
      role: role,
    );
  }

  Future<ForgotPasswordResult> forgotPassword({required String email}) {
    return _authService.forgotPassword(email: email);
  }

  Future<AuthProfileResult> profile({String? token}) {
    return _authService.profile(token: token);
  }

  Future<AuthTokenResult> refreshToken({String? refreshToken}) {
    return _authService.refreshToken(refreshToken: refreshToken);
  }

  Future<String?> logout({String? token, String? refreshToken}) {
    return _authService.logout(token: token, refreshToken: refreshToken);
  }
}
