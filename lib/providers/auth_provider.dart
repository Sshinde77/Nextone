import 'package:nextone/models/auth_models.dart';
import 'package:nextone/services/auth_service.dart';

class AuthProvider {
  AuthProvider({AuthService? authService})
    : _authService = authService ?? AuthService();

  final AuthService _authService;

  String? get currentAuthToken => AuthService.currentAuthToken;

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
    String? token,
  }) {
    return _authService.register(
      email: email,
      firstName: firstName,
      lastName: lastName,
      phoneNumber: phoneNumber,
      password: password,
      role: role,
      token: token,
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

  Future<List<Map<String, dynamic>>> users({String? token}) {
    return _authService.users(token: token);
  }

  Future<Map<String, dynamic>> usersDetail({required String id, String? token}) {
    return _authService.usersDetail(id: id, token: token);
  }

  Future<void> deleteUser({required String id, String? token}) {
    return _authService.deleteUser(id: id, token: token);
  }

  Future<void> editUser({
    required String id,
    required String firstName,
    required String lastName,
    required String phoneNumber,
    String? token,
  }) {
    return _authService.editUser(
      id: id,
      firstName: firstName,
      lastName: lastName,
      phoneNumber: phoneNumber,
      token: token,
    );
  }

  Future<void> editUserRole({
    required String id,
    required String role,
    String? token,
  }) {
    return _authService.editUserRole(id: id, role: role, token: token);
  }
}
