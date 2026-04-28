class ApiConstants {
  static const String baseUrl = 'https://nextoneapi.onrender.com/api/v1';

  // Auth Endpoints
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String forgotPassword = '/auth/forgot-password';
  static const String profile = '/auth/profile';
  static const String refreshToken = '/auth/refresh-token';
  static const String logout = '/auth/logout';

  // User Endpoints
  static const String users = '/users';
  static const String usersdetail = '/users/{id}';
  static const String deleteuser = '/users/{id}';
  static const String edituser = '/users/{id}';
  static const String edituserrole = '/users/{id}/role';

  // Leads Endpoints
  static const String leads = '/leads';
  static const String createsleads = '/leads';
  static const String editleads = '/leads/{id}';
}
