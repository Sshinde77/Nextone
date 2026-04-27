import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:nextone/constants/api_constants.dart';
import 'package:nextone/models/auth_models.dart';

class AuthService {
  static String? _authToken;
  static String? _refreshToken;
  static const Duration _requestTimeout = Duration(seconds: 45);
  static const int _maxRequestAttempts = 3;
  static const Duration _retryDelay = Duration(seconds: 2);
  static Future<void>? _warmupFuture;

  static Future<void> warmUpBackend() {
    return _warmupFuture ??= _pingBackend();
  }

  static String? get currentAuthToken => _authToken;

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

    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.login}');
    final headers = _headers(accept: 'application/json');
    final body = jsonEncode(payload);
    _logRequest(
      endpoint: 'login',
      method: 'POST',
      uri: uri,
      headers: headers,
      body: body,
    );

    http.Response response;
    try {
      response = await _sendWithRetry(
        () => http.post(
          uri,
          headers: headers,
          body: body,
        ),
      );
    } on TimeoutException {
      return 'Server is taking too long to respond. Please try again.';
    } on SocketException {
      return 'No internet connection or server is unreachable.';
    } on HandshakeException {
      return 'Secure connection failed. Check phone date/time and try again.';
    } on http.ClientException {
      return 'Network error while contacting server. Please try again.';
    } catch (_) {
      return 'Unable to connect to the server. Please try again.';
    }

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
    String? token,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.register}');
    final headers = _headers(
      accept: 'application/json',
      token: token ?? _authToken,
    );
    final body = jsonEncode({
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'phone_number': phoneNumber,
      'password': password,
      'role': role,
    });
    _logRequest(
      endpoint: 'register',
      method: 'POST',
      uri: uri,
      headers: headers,
      body: body,
    );

    http.Response response;
    try {
      response = await _sendWithRetry(
        () => http.post(
          uri,
          headers: headers,
          body: body,
        ),
      );
    } on TimeoutException {
      return 'Server is taking too long to respond. Please try again.';
    } on SocketException {
      return 'No internet connection or server is unreachable.';
    } on HandshakeException {
      return 'Secure connection failed. Check phone date/time and try again.';
    } on http.ClientException {
      return 'Network error while contacting server. Please try again.';
    } catch (_) {
      return 'Unable to connect to the server. Please try again.';
    }

    _logResponse('register', response);

    return _handleResponse(response, fallbackMessage: 'Registration failed.');
  }

  Future<ForgotPasswordResult> forgotPassword({required String email}) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.forgotPassword}');
    final headers = _headers(accept: '*/*');
    final body = jsonEncode({'email': email});
    _logRequest(
      endpoint: 'forgotPassword',
      method: 'POST',
      uri: uri,
      headers: headers,
      body: body,
    );
    final response = await http
        .post(
          uri,
          headers: headers,
          body: body,
        )
        .timeout(_requestTimeout);
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
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.profile}');
    final headers = _headers(accept: 'application/json', token: authToken);
    _logRequest(
      endpoint: 'profile',
      method: 'GET',
      uri: uri,
      headers: headers,
    );
    final response = await http
        .get(
          uri,
          headers: headers,
        )
        .timeout(_requestTimeout);
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

    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.refreshToken}');
    final headers = _headers(accept: 'application/json');
    final body = jsonEncode({'refresh_token': token.trim()});
    _logRequest(
      endpoint: 'refreshToken',
      method: 'POST',
      uri: uri,
      headers: headers,
      body: body,
    );
    final response = await http
        .post(
          uri,
          headers: headers,
          body: body,
        )
        .timeout(_requestTimeout);
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

    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.logout}');
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    final body = jsonEncode(payload);
    _logRequest(
      endpoint: 'logout',
      method: 'POST',
      uri: uri,
      headers: headers,
      body: body,
    );
    final response = await http
        .post(
          uri,
          headers: headers,
          body: body,
        )
        .timeout(_requestTimeout);
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

  Future<List<Map<String, dynamic>>> users({String? token}) async {
    final resolvedToken = token ?? _authToken;
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.users}');
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'users',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response = await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('users', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to fetch team members.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic body = jsonDecode(response.body);
      final userList = _extractUserList(body);
      if (userList != null) {
        return userList;
      }
    } catch (_) {
      // Fall through to generic error below.
    }

    throw Exception('Users response format is not valid.');
  }

  Map<String, String> _headers({required String accept, String? token}) {
    final headers = {'accept': accept, 'Content-Type': 'application/json'};

    if (token != null && token.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${token.trim()}';
    }

    return headers;
  }

  void _logRequest({
    required String endpoint,
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    String? body,
  }) {
    developer.log(
      '[$endpoint] REQUEST $method $uri\nHeaders: $headers${body == null ? '' : '\nBody: $body'}',
      name: 'AuthService',
    );
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

  List<Map<String, dynamic>>? _extractUserList(dynamic source) {
    if (source is List) {
      final users = source.whereType<Map>().map(_stringDynamicMap).toList();
      return users;
    }

    if (source is! Map<String, dynamic>) {
      return null;
    }

    final data = source['data'];
    if (data is List) {
      return data.whereType<Map>().map(_stringDynamicMap).toList();
    }

    if (data is Map<String, dynamic>) {
      final nestedUsers = data['users'];
      if (nestedUsers is List) {
        return nestedUsers.whereType<Map>().map(_stringDynamicMap).toList();
      }
    }

    final users = source['users'];
    if (users is List) {
      return users.whereType<Map>().map(_stringDynamicMap).toList();
    }

    return null;
  }

  Map<String, dynamic> _stringDynamicMap(Map source) {
    return source.map(
      (key, value) => MapEntry(key.toString(), value),
    );
  }

  void _clearTokens() {
    _authToken = null;
    _refreshToken = null;
  }

  static Future<void> _pingBackend() async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.profile}');
    developer.log(
      '[warmUpBackend] REQUEST GET $uri\nHeaders: {accept: application/json}',
      name: 'AuthService',
    );
    try {
      final response = await _sendWithRetry(
        () => http.get(
          uri,
          headers: {'accept': 'application/json'},
        ),
        timeout: const Duration(seconds: 20),
      );
      developer.log(
        '[warmUpBackend] ${response.statusCode} ${response.reasonPhrase ?? ''}\n${response.body}',
        name: 'AuthService',
      );
    } catch (_) {
      // This is a best-effort warm-up call.
    }
  }

  static Future<http.Response> _sendWithRetry(
    Future<http.Response> Function() request, {
    Duration? timeout,
  }) async {
    final resolvedTimeout = timeout ?? _requestTimeout;
    Object? lastError;

    for (var attempt = 1; attempt <= _maxRequestAttempts; attempt++) {
      try {
        return await request().timeout(resolvedTimeout);
      } on TimeoutException catch (error) {
        lastError = error;
        developer.log(
          'Request attempt $attempt failed with timeout: $error',
          name: 'AuthService',
        );
      } on SocketException catch (error) {
        lastError = error;
        developer.log(
          'Request attempt $attempt failed with socket error: $error',
          name: 'AuthService',
        );
      } on HandshakeException catch (error) {
        lastError = error;
        developer.log(
          'Request attempt $attempt failed with handshake error: $error',
          name: 'AuthService',
        );
      } on http.ClientException catch (error) {
        lastError = error;
        developer.log(
          'Request attempt $attempt failed with client error: $error',
          name: 'AuthService',
        );
      }

      if (attempt < _maxRequestAttempts) {
        await Future<void>.delayed(_retryDelay * attempt);
      }
    }

    if (lastError != null) {
      throw lastError;
    }

    throw Exception('Request failed without a specific error.');
  }
}
