import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;
import 'package:nextone/constants/api_constants.dart';
import 'package:nextone/models/auth_models.dart';

class AuthService {
  static String? _authToken;
  static String? _refreshToken;

  Future<String?> login({
    required String email,
    required String phoneNumber,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedPhone = phoneNumber.trim();
    final normalizedPassword = password.trim();

    if (normalizedEmail.isEmpty && normalizedPhone.isEmpty) {
      return 'Enter email or phone number to login.';
    }

    final payload = <String, String>{'password': normalizedPassword};
    if (normalizedEmail.isNotEmpty) {
      payload['email'] = normalizedEmail;
    }
    if (normalizedPhone.isNotEmpty) {
      payload['phone_number'] = normalizedPhone;
    }

    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.login}'),
      headers: _headers(accept: 'application/json'),
      body: jsonEncode(payload),
    );
    _logResponse('login', response);

    final error = _handleResponse(response, fallbackMessage: 'Login failed.');
    if (error == null) {
      _storeTokensFromResponse(response.body);
    }

    return error;
  }

  Future<String?> register({
    required String email,
    required String firstName,
    required String lastName,
    required String phoneNumber,
    required String password,
    required String role,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.register}'),
      headers: _headers(accept: 'application/json'),
      body: jsonEncode({
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'phone_number': phoneNumber,
        'password': password,
        'role': role,
      }),
    );
    _logResponse('register', response);

    return _handleResponse(response, fallbackMessage: 'Registration failed.');
  }

  Future<ForgotPasswordResult> forgotPassword({required String email}) async {
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.forgotPassword}'),
      headers: _headers(accept: '*/*'),
      body: jsonEncode({'email': email}),
    );
    _logResponse('forgotPassword', response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final dynamic body = jsonDecode(response.body);
        if (body is Map<String, dynamic>) {
          final dynamic message = body['message'];
          final dynamic data = body['data'];
          String? resetToken;

          if (data is Map<String, dynamic>) {
            final dynamic token = data['reset_token'];
            if (token is String && token.trim().isNotEmpty) {
              resetToken = token;
            }
          }

          if (message is String && message.trim().isNotEmpty) {
            return ForgotPasswordResult(
              message: message,
              resetToken: resetToken,
            );
          }
        }
      } catch (_) {
        // Fall back to a generic success message if the payload shape changes.
      }

      return const ForgotPasswordResult(
        message: 'Password reset token generated.',
      );
    }

    throw Exception(
      _handleResponse(
        response,
        fallbackMessage: 'Forgot password request failed.',
      ),
    );
  }

  Future<AuthProfileResult> profile({String? token}) async {
    final authToken = token ?? _authToken;
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.profile}'),
      headers: _headers(accept: 'application/json', token: authToken),
    );
    _logResponse('profile', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to fetch profile.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        final dynamic data = body['data'];
        return AuthProfileResult(
          data: data is Map<String, dynamic> ? data : body,
          message: _readMessage(body) ?? 'Profile loaded successfully.',
        );
      }
    } catch (_) {
      // Fall through to the generic parsing error below.
    }

    throw Exception('Profile response is not valid JSON.');
  }

  Future<AuthTokenResult> refreshToken({String? refreshToken}) async {
    final token = refreshToken ?? _refreshToken;
    if (token == null || token.trim().isEmpty) {
      throw Exception('Refresh token is required.');
    }

    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.refreshToken}'),
      headers: _headers(accept: 'application/json'),
      body: jsonEncode({'refresh_token': token.trim()}),
    );
    _logResponse('refreshToken', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to refresh token.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        final result = _tokenResultFromBody(body);
        _authToken = result.accessToken ?? _authToken;
        _refreshToken = result.refreshToken ?? _refreshToken;
        return result;
      }
    } catch (_) {
      // Fall through to the generic parsing error below.
    }

    throw Exception('Refresh token response is not valid JSON.');
  }

  Future<String?> logout({String? token, String? refreshToken}) async {
    final resolvedToken = token ?? _authToken;
    final resolvedRefreshToken = refreshToken ?? _refreshToken;
    final payload = <String, String>{};

    if (resolvedRefreshToken != null &&
        resolvedRefreshToken.trim().isNotEmpty) {
      payload['refresh_token'] = resolvedRefreshToken.trim();
    }

    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.logout}'),
      headers: _headers(accept: 'application/json', token: resolvedToken),
      body: jsonEncode(payload),
    );
    _logResponse('logout', response);

    if (response.statusCode == 401 || response.statusCode == 403) {
      _clearTokens();
      return null;
    }

    final error = _handleResponse(response, fallbackMessage: 'Logout failed.');
    if (error == null) {
      _clearTokens();
    }

    return error;
  }

  Map<String, String> _headers({required String accept, String? token}) {
    final headers = {'accept': accept, 'Content-Type': 'application/json'};

    if (token != null && token.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${token.trim()}';
    }

    return headers;
  }

  void _logResponse(String endpoint, http.Response response) {
    developer.log(
      '[$endpoint] ${response.statusCode} ${response.reasonPhrase ?? ''}\n${response.body}',
      name: 'AuthService',
    );
  }

  String? _handleResponse(
    http.Response response, {
    required String fallbackMessage,
  }) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return null;
    }

    try {
      final dynamic body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        final message = _readMessage(body);
        if (message != null && message.trim().isNotEmpty) {
          return message;
        }
      }
    } catch (_) {
      // Fall back to the default message when the error payload is not JSON.
    }

    return fallbackMessage;
  }

  void _storeTokensFromResponse(String responseBody) {
    try {
      final dynamic body = jsonDecode(responseBody);
      if (body is! Map<String, dynamic>) {
        return;
      }

      final result = _tokenResultFromBody(body);
      _authToken = result.accessToken ?? _authToken;
      _refreshToken = result.refreshToken ?? _refreshToken;
    } catch (_) {
      return;
    }
  }

  AuthTokenResult _tokenResultFromBody(Map<String, dynamic> body) {
    final dynamic data = body['data'];
    final tokenData = data is Map<String, dynamic> ? data : body;

    return AuthTokenResult(
      message: _readMessage(body) ?? 'Token refreshed successfully.',
      data: tokenData,
      accessToken: _readAccessToken(body) ?? _readAccessToken(data),
      refreshToken: _readRefreshToken(body) ?? _readRefreshToken(data),
    );
  }

  String? _readAccessToken(dynamic source) {
    if (source is! Map<String, dynamic>) {
      return null;
    }

    for (final key in ['token', 'access_token', 'accessToken', 'authToken']) {
      final dynamic value = source[key];
      if (value is String && value.trim().isNotEmpty) {
        return value;
      }
    }

    return null;
  }

  String? _readRefreshToken(dynamic source) {
    if (source is! Map<String, dynamic>) {
      return null;
    }

    for (final key in ['refresh_token', 'refreshToken']) {
      final dynamic value = source[key];
      if (value is String && value.trim().isNotEmpty) {
        return value;
      }
    }

    return null;
  }

  String? _readMessage(Map<String, dynamic> body) {
    final message = body['message'] ?? body['error'] ?? body['detail'];
    return message is String ? message : null;
  }

  void _clearTokens() {
    _authToken = null;
    _refreshToken = null;
  }
}
