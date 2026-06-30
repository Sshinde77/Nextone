import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:nextone/constants/api_constants.dart';
import 'package:nextone/models/auth_models.dart';
import 'package:nextone/models/salary_models.dart';
import 'package:nextone/utils/app_error_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static String? _authToken;
  static String? _refreshToken;
  static EffectivePermissionsResult _currentPermissions =
      const EffectivePermissionsResult.empty();
  static const String _authTokenStorageKey = 'auth_token';
  static const String _refreshTokenStorageKey = 'refresh_token';
  static const Duration _requestTimeout = Duration(seconds: 45);
  static const int _maxRequestAttempts = 3;
  static const Duration _retryDelay = Duration(seconds: 2);
  static Future<void>? _warmupFuture;

  static Future<void> warmUpBackend() {
    return _warmupFuture ??= _pingBackend();
  }

  static String? get currentAuthToken => _authToken;
  static EffectivePermissionsResult get currentPermissions =>
      _currentPermissions;

  static Future<bool> hasPersistedSession() async {
    if (_authToken != null && _authToken!.trim().isNotEmpty) {
      return true;
    }

    await _restoreTokensFromStorage();
    return _authToken != null && _authToken!.trim().isNotEmpty;
  }

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
      return AppErrorHandler.timeoutMessage;
    } on SocketException {
      return AppErrorHandler.noInternetMessage;
    } on HandshakeException {
      return AppErrorHandler.unknownMessage;
    } on http.ClientException {
      return AppErrorHandler.unknownMessage;
    } catch (_) {
      return AppErrorHandler.unknownMessage;
    }

    _logResponse('login', response);

    if (response.statusCode == 401) {
      final loginErrorBody = _decodeJsonMap(response.body);
      final message =
          loginErrorBody != null ? _readMessage(loginErrorBody) : null;
      return message ?? 'Invalid credentials';
    }

    final error = _handleResponse(response, fallbackMessage: 'Login failed.');
    if (error == null) {
      await _storeTokensFromResponse(response.body);
      try {
        await myPermissions(forceRefresh: true);
      } catch (_) {
        // Keep login successful even if permission prefetch fails.
      }
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
      return AppErrorHandler.timeoutMessage;
    } on SocketException {
      return AppErrorHandler.noInternetMessage;
    } on HandshakeException {
      return AppErrorHandler.unknownMessage;
    } on http.ClientException {
      return AppErrorHandler.unknownMessage;
    } catch (_) {
      return AppErrorHandler.unknownMessage;
    }

    _logResponse('register', response);

    return _handleResponse(response, fallbackMessage: 'Registration failed.');
  }

  Future<ForgotPasswordResult> forgotPassword({required String email}) async {
    final uri =
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.forgotPassword}');
    final headers = _headers(accept: 'application/json');
    final normalizedEmail = email.trim().toLowerCase();
    final body = jsonEncode({'email': normalizedEmail});
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
          final payload = data is Map<String, dynamic> ? data : body;
          final token = _readForgotPasswordToken(payload);
          final emailValue = _readStringValue(
            payload,
            const <String>['email'],
          );
          final expiresIn = _readStringValue(
            payload,
            const <String>['expires_in', 'expiresIn', 'expires'],
          );

          if (message is String && message.trim().isNotEmpty && token != null) {
            return ForgotPasswordResult(
              message: message,
              token: token,
              email: emailValue,
              expiresIn: expiresIn,
            );
          }
        }
      } catch (_) {
        // Fall back to a generic success message if the payload shape changes.
      }

      return const ForgotPasswordResult(
        message: 'Email verified. Use the token to reset your password.',
      );
    }

    if (response.statusCode == 404) {
      final exactMessage = _readForgotPasswordErrorMessage(response.body) ??
          'No account found with this email address';
      throw Exception(exactMessage);
    }

    throw Exception(
      _handleResponse(
        response,
        fallbackMessage: 'Forgot password request failed.',
      ),
    );
  }

  Future<String?> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    final normalizedToken = token.trim();
    final normalizedPassword = newPassword.trim();
    if (normalizedToken.isEmpty) {
      throw Exception('Reset token is required.');
    }
    if (normalizedPassword.isEmpty) {
      throw Exception('New password is required.');
    }

    final uri =
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.resetPassword}');
    final headers = _headers(accept: 'application/json');
    final body = jsonEncode(<String, String>{
      'token': normalizedToken,
      'new_password': normalizedPassword,
    });
    _logRequest(
      endpoint: 'resetPassword',
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
      return AppErrorHandler.timeoutMessage;
    } on SocketException {
      return AppErrorHandler.noInternetMessage;
    } on HandshakeException {
      return AppErrorHandler.unknownMessage;
    } on http.ClientException {
      return AppErrorHandler.unknownMessage;
    } catch (_) {
      return AppErrorHandler.unknownMessage;
    }

    _logResponse('resetPassword', response);
    return _handleResponse(
      response,
      fallbackMessage: 'Password reset failed.',
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

  Future<EffectivePermissionsResult> myPermissions({
    String? token,
    bool forceRefresh = false,
  }) async {
    final resolvedToken = token ?? _authToken;
    if (!forceRefresh &&
        resolvedToken == _authToken &&
        (_currentPermissions.role.isNotEmpty ||
            _currentPermissions.permissions.isNotEmpty)) {
      return _currentPermissions;
    }

    final uri =
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.myPermissions}');
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'myPermissions',
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
    _logResponse('myPermissions', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to fetch permissions.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) {
        throw Exception('Permissions response is not valid JSON.');
      }
      final result = _effectivePermissionsResultFromBody(body);
      if (resolvedToken == _authToken) {
        _currentPermissions = result;
      }
      return result;
    } catch (_) {
      throw Exception('Permissions response is not valid JSON.');
    }
  }

  Future<AuthTokenResult> refreshToken({String? refreshToken}) async {
    final token = refreshToken ?? _refreshToken;
    if (token == null || token.trim().isEmpty) {
      throw Exception('Refresh token is required.');
    }

    final uri =
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.refreshToken}');
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
        await _persistTokens();
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
    final headers = _headers(accept: '*/*', token: resolvedToken);
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
      await _clearTokens();
      return null;
    }

    final error = _handleResponse(response, fallbackMessage: 'Logout failed.');
    if (error == null) {
      await _clearTokens();
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

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
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

  Future<LeadsListResult> usersPaged({
    String? token,
    int page = 1,
    int perPage = 10,
  }) async {
    final resolvedToken = token ?? _authToken;
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.users}')
        .replace(queryParameters: <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
    });
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'usersPaged',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('usersPaged', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to fetch team members.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic body = jsonDecode(response.body);
      final items = _extractUserList(body) ?? const <Map<String, dynamic>>[];
      final pagination = _extractPaginationMap(body);
      final resolvedCurrentPage = _readIntFromMap(
              pagination, ['page', 'current_page', 'currentPage']) ??
          page;
      final resolvedPerPage = _readIntFromMap(
              pagination, ['per_page', 'perPage', 'page_size', 'limit']) ??
          perPage;
      final resolvedTotalItems = _readIntFromMap(
            pagination,
            ['total', 'total_items', 'totalItems', 'count'],
          ) ??
          items.length;
      final resolvedTotalPages = _readIntFromMap(
            pagination,
            ['total_pages', 'totalPages', 'last_page', 'lastPage'],
          ) ??
          _deriveTotalPages(
              total: resolvedTotalItems, perPage: resolvedPerPage);
      return LeadsListResult(
        items: items,
        currentPage: resolvedCurrentPage,
        perPage: resolvedPerPage,
        totalItems: resolvedTotalItems,
        totalPages: resolvedTotalPages <= 0 ? 1 : resolvedTotalPages,
      );
    } catch (_) {
      throw Exception('Users response format is not valid.');
    }
  }

  Future<List<Map<String, dynamic>>> assignmentUsers({String? token}) async {
    final resolvedToken = token ?? _authToken;
    final currentUserId = await _resolveCurrentUserId(token: resolvedToken);
    if (currentUserId.isEmpty) {
      throw Exception('Unable to resolve current user for assignment options.');
    }

    final endpoint =
        ApiConstants.userTeamTree.replaceFirst('{id}', currentUserId);
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'assignmentUsers',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('assignmentUsers', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to fetch assignment users.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic body = jsonDecode(response.body);
      final userList = _extractTeamTreeUsers(body);
      if (userList != null) {
        return await _ensureCurrentUserInAssignmentUsers(
          users: userList,
          currentUserId: currentUserId,
          token: resolvedToken,
        );
      }
    } catch (_) {
      // Fall through to generic error below.
    }

    throw Exception('Assignment users response format is not valid.');
  }

  Future<List<Map<String, dynamic>>> eligibleManagers({
    required String forRole,
    String? token,
  }) async {
    final normalizedRole = forRole.trim();
    if (normalizedRole.isEmpty) {
      throw Exception('Role is required to fetch eligible managers.');
    }

    final resolvedToken = token ?? _authToken;
    final uri = Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.eligibleManagers}?for_role=${Uri.encodeQueryComponent(normalizedRole)}',
    );
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'eligibleManagers',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('eligibleManagers', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to fetch eligible managers.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic body = jsonDecode(response.body);
      if (body is List) {
        return body.whereType<Map<String, dynamic>>().toList();
      }
      if (body is Map<String, dynamic>) {
        final data = body['data'];
        if (data is List) {
          return data.whereType<Map<String, dynamic>>().toList();
        }
        if (data is Map<String, dynamic>) {
          final managers = data['managers'];
          if (managers is List) {
            return managers.whereType<Map<String, dynamic>>().toList();
          }
        }
      }
    } catch (_) {
      // Fall through to generic error below.
    }

    throw Exception('Eligible managers response format is not valid.');
  }

  Future<List<Map<String, dynamic>>> usersRoles({String? token}) async {
    final resolvedToken = token ?? _authToken;
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.usersRoles}');
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'usersRoles',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('usersRoles', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to fetch user roles.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic body = jsonDecode(response.body);
      final roles = _extractRoleList(body);
      if (roles != null) {
        return roles;
      }
    } catch (_) {
      // Fall through to generic error below.
    }

    throw Exception('Roles response format is not valid.');
  }

  Future<SalaryEmployeesResult> salaryEmployees({
    String? token,
    int page = 1,
    int perPage = 10,
  }) async {
    final resolvedToken = token ?? _authToken;
    final uri =
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.salaryEmployees}')
            .replace(queryParameters: <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
    });
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'salaryEmployees',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('salaryEmployees', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to fetch employee salaries.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic body = jsonDecode(response.body);
      final payload = _extractSalaryEmployeesPayload(body);
      if (payload == null) {
        throw Exception('Employee salaries response format is not valid.');
      }

      final pagination = _extractPaginationMap(body);
      final totalRaw = payload['total'];
      final total = totalRaw is num
          ? totalRaw.toInt()
          : int.tryParse(totalRaw?.toString() ?? '') ?? 0;
      final employeesRaw = payload['data'];
      if (employeesRaw is! List) {
        throw Exception('Employee salaries data list is missing.');
      }

      final employees = employeesRaw
          .whereType<Map>()
          .map(_stringDynamicMap)
          .map(SalaryEmployee.fromMap)
          .toList();

      final resolvedCurrentPage = _readIntFromMap(
            pagination,
            ['page', 'current_page', 'currentPage'],
          ) ??
          1;
      final resolvedPerPage = _readIntFromMap(
            pagination,
            ['per_page', 'perPage', 'page_size', 'limit'],
          ) ??
          employees.length;
      final resolvedTotalPages = _readIntFromMap(
            pagination,
            ['total_pages', 'totalPages', 'last_page', 'lastPage'],
          ) ??
          _deriveTotalPages(
              total: total > 0 ? total : employees.length,
              perPage: resolvedPerPage);

      return SalaryEmployeesResult(
        currentPage: resolvedCurrentPage,
        perPage: resolvedPerPage,
        total: total > 0 ? total : employees.length,
        totalPages: resolvedTotalPages <= 0 ? 1 : resolvedTotalPages,
        employees: employees,
      );
    } catch (_) {
      throw Exception('Employee salaries response format is not valid.');
    }
  }

  Future<SalarySlipsResult> salarySlips({
    required int month,
    required int year,
    int page = 1,
    int perPage = 20,
    String? token,
  }) async {
    final resolvedToken = token ?? _authToken;
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.salarySlips}')
        .replace(queryParameters: <String, String>{
      'month': month.toString(),
      'year': year.toString(),
      'page': page.toString(),
      'per_page': perPage.toString(),
    });
    final headers = _headers(accept: '*/*', token: resolvedToken);
    _logRequest(
      endpoint: 'salarySlips',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('salarySlips', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to fetch salary slips.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) {
        throw Exception('Salary slips response format is not valid.');
      }

      final data = body['data'];
      if (data is! List) {
        throw Exception('Salary slips data list is missing.');
      }

      final pagination = body['pagination'];
      final paginationMap =
          pagination is Map<String, dynamic> ? pagination : <String, dynamic>{};

      final totalRaw = paginationMap['total'];
      final resolvedTotal = totalRaw is num
          ? totalRaw.toInt()
          : int.tryParse(totalRaw?.toString() ?? '') ?? data.length;
      final pageRaw = paginationMap['page'];
      final resolvedPage = pageRaw is num
          ? pageRaw.toInt()
          : int.tryParse(pageRaw?.toString() ?? '') ?? page;
      final perPageRaw = paginationMap['per_page'];
      final resolvedPerPage = perPageRaw is num
          ? perPageRaw.toInt()
          : int.tryParse(perPageRaw?.toString() ?? '') ?? perPage;
      final totalPagesRaw = paginationMap['total_pages'];
      final resolvedTotalPages = totalPagesRaw is num
          ? totalPagesRaw.toInt()
          : int.tryParse(totalPagesRaw?.toString() ?? '') ?? 1;

      final items = data
          .whereType<Map>()
          .map(_stringDynamicMap)
          .map(SalarySlip.fromMap)
          .toList();

      return SalarySlipsResult(
        items: items,
        total: resolvedTotal,
        page: resolvedPage,
        perPage: resolvedPerPage,
        totalPages: resolvedTotalPages <= 0 ? 1 : resolvedTotalPages,
      );
    } catch (_) {
      throw Exception('Salary slips response format is not valid.');
    }
  }

  Future<SalaryGenerateAllResult> salaryGenerateAll({
    required int month,
    required int year,
    int? workingDaysOverride,
    Map<String, num>? deductionsMap,
    String? notes,
    String? token,
  }) async {
    final resolvedToken = token ?? _authToken;
    final uri =
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.salaryGenerateAll}');
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    final bodyMap = <String, dynamic>{
      'month': month,
      'year': year,
    };
    if (workingDaysOverride != null) {
      bodyMap['working_days_override'] = workingDaysOverride;
    }
    if (deductionsMap != null && deductionsMap.isNotEmpty) {
      bodyMap['deductions_map'] = deductionsMap;
    }
    if (notes != null && notes.trim().isNotEmpty) {
      bodyMap['notes'] = notes.trim();
    }
    final body = jsonEncode(bodyMap);
    _logRequest(
      endpoint: 'salaryGenerateAll',
      method: 'POST',
      uri: uri,
      headers: headers,
      body: body,
    );

    final response = await http
        .post(uri, headers: headers, body: body)
        .timeout(_requestTimeout);
    _logResponse('salaryGenerateAll', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to generate salary slips.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Generate salary slips response format is not valid.');
      }

      final message =
          decoded['message']?.toString().trim() ?? 'Salary slips generated.';
      final data = decoded['data'];
      if (data is! Map<String, dynamic>) {
        throw Exception('Generate salary slips data is missing.');
      }

      int readInt(dynamic value) {
        if (value is int) return value;
        if (value is num) return value.toInt();
        return int.tryParse(value?.toString() ?? '') ?? 0;
      }

      final slipsRaw = data['slips'];
      final slips = slipsRaw is List
          ? slipsRaw
              .whereType<Map>()
              .map(_stringDynamicMap)
              .map(GeneratedSalarySlipItem.fromMap)
              .toList()
          : <GeneratedSalarySlipItem>[];

      return SalaryGenerateAllResult(
        message: message,
        month: data['month']?.toString().trim() ?? '',
        year: readInt(data['year']),
        workingDays: readInt(data['working_days']),
        totalProcessed: readInt(data['total_processed']),
        totalFailed: readInt(data['total_failed']),
        slips: slips,
      );
    } catch (_) {
      throw Exception('Generate salary slips response format is not valid.');
    }
  }

  Future<SalarySetResult> salarySet({
    required String userId,
    required double monthlySalary,
    required double perDaySalary,
    required int workingDaysInMonth,
    required String effectiveFrom,
    String? notes,
    String? token,
  }) async {
    final resolvedToken = token ?? _authToken;
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.salarySet}');
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    final bodyMap = <String, dynamic>{
      'user_id': userId,
      'monthly_salary': monthlySalary,
      'per_day_salary': perDaySalary,
      'working_days_in_month': workingDaysInMonth,
      'effective_from': effectiveFrom,
    };
    if (notes != null && notes.trim().isNotEmpty) {
      bodyMap['notes'] = notes.trim();
    }
    final body = jsonEncode(bodyMap);
    _logRequest(
      endpoint: 'salarySet',
      method: 'POST',
      uri: uri,
      headers: headers,
      body: body,
    );

    final response = await http
        .post(uri, headers: headers, body: body)
        .timeout(_requestTimeout);
    _logResponse('salarySet', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to save employee salary.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Set salary response format is not valid.');
      }
      final data = decoded['data'];
      if (data is! Map<String, dynamic>) {
        throw Exception('Set salary response data is missing.');
      }
      final salaryRaw = data['salary'];
      final employeeRaw = data['employee'];
      return SalarySetResult(
        message: decoded['message']?.toString().trim().isNotEmpty == true
            ? decoded['message'].toString().trim()
            : 'Employee salary saved successfully',
        salary: salaryRaw is Map ? _stringDynamicMap(salaryRaw) : const {},
        employee:
            employeeRaw is Map ? _stringDynamicMap(employeeRaw) : const {},
      );
    } catch (_) {
      throw Exception('Set salary response format is not valid.');
    }
  }

  Future<SalarySetResult> salaryAppraisal({
    required String userId,
    required double newSalary,
    required String effectiveFrom,
    required String appraisalNote,
    required int workingDaysInMonth,
    String? token,
  }) async {
    final resolvedToken = token ?? _authToken;
    final uri =
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.salaryAppraisal}');
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    final bodyMap = <String, dynamic>{
      'user_id': userId,
      'new_salary': newSalary,
      'effective_from': effectiveFrom,
      'appraisal_note': appraisalNote.trim(),
      'working_days_in_month': workingDaysInMonth,
    };
    final body = jsonEncode(bodyMap);
    _logRequest(
      endpoint: 'salaryAppraisal',
      method: 'POST',
      uri: uri,
      headers: headers,
      body: body,
    );

    final response = await http
        .post(uri, headers: headers, body: body)
        .timeout(_requestTimeout);
    _logResponse('salaryAppraisal', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to save employee appraisal.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Appraisal response format is not valid.');
      }
      final data = decoded['data'];
      final salaryRaw = data is Map ? data['salary'] : null;
      final employeeRaw = data is Map ? data['employee'] : null;
      return SalarySetResult(
        message: decoded['message']?.toString().trim().isNotEmpty == true
            ? decoded['message'].toString().trim()
            : 'Employee appraisal saved successfully',
        salary: salaryRaw is Map ? _stringDynamicMap(salaryRaw) : const {},
        employee:
            employeeRaw is Map ? _stringDynamicMap(employeeRaw) : const {},
      );
    } catch (_) {
      throw Exception('Appraisal response format is not valid.');
    }
  }

  Future<SalaryGenerateResult> salaryGenerate({
    required String userId,
    required int month,
    required int year,
    required double deductions,
    int? workingDaysOverride,
    String? notes,
    String? token,
  }) async {
    final resolvedToken = token ?? _authToken;
    final uri =
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.salaryGenerate}');
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    final bodyMap = <String, dynamic>{
      'user_id': userId,
      'month': month,
      'year': year,
      'deductions': deductions,
    };
    if (workingDaysOverride != null) {
      bodyMap['working_days_override'] = workingDaysOverride;
    }
    if (notes != null && notes.trim().isNotEmpty) {
      bodyMap['notes'] = notes.trim();
    }

    final body = jsonEncode(bodyMap);
    _logRequest(
      endpoint: 'salaryGenerate',
      method: 'POST',
      uri: uri,
      headers: headers,
      body: body,
    );

    final response = await http
        .post(uri, headers: headers, body: body)
        .timeout(_requestTimeout);
    _logResponse('salaryGenerate', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to generate salary slip.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Generate salary slip response format is not valid.');
      }
      final data = decoded['data'];
      if (data is! Map<String, dynamic>) {
        throw Exception('Generate salary slip response data is missing.');
      }

      final slipRaw = data['slip'];
      final employeeRaw = data['employee'];
      final breakdownRaw = data['breakdown'];

      return SalaryGenerateResult(
        message: decoded['message']?.toString().trim().isNotEmpty == true
            ? decoded['message'].toString().trim()
            : 'Salary slip generated successfully',
        slip: slipRaw is Map ? _stringDynamicMap(slipRaw) : const {},
        employee:
            employeeRaw is Map ? _stringDynamicMap(employeeRaw) : const {},
        breakdown:
            breakdownRaw is Map ? _stringDynamicMap(breakdownRaw) : const {},
      );
    } catch (_) {
      throw Exception('Generate salary slip response format is not valid.');
    }
  }

  Future<SalaryHistoryResult> salaryHistory({
    required String userId,
    String? token,
  }) async {
    final resolvedToken = token ?? _authToken;
    final endpoint =
        ApiConstants.salaryHistory.replaceFirst('{userId}', userId.trim());
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'salaryHistory',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('salaryHistory', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to fetch salary history.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Salary history response format is not valid.');
      }
      final data = decoded['data'];
      if (data is! Map<String, dynamic>) {
        throw Exception('Salary history data is missing.');
      }
      final employeeRaw = data['employee'];
      final historyRaw = data['history'];
      final history = historyRaw is List
          ? historyRaw
              .whereType<Map>()
              .map(_stringDynamicMap)
              .map(SalaryHistoryEntry.fromMap)
              .toList()
          : <SalaryHistoryEntry>[];
      return SalaryHistoryResult(
        employee:
            employeeRaw is Map ? _stringDynamicMap(employeeRaw) : const {},
        history: history,
      );
    } catch (_) {
      throw Exception('Salary history response format is not valid.');
    }
  }

  Future<List<SalaryHistoryEntry>> mySalaryHistory({String? token}) async {
    final resolvedToken = token ?? _authToken;
    final uri =
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.mySalaryHistory}');
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'mySalaryHistory',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('mySalaryHistory', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to fetch your salary history.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      dynamic source;
      if (decoded is List) {
        source = decoded;
      } else if (decoded is Map<String, dynamic>) {
        final data = decoded['data'];
        if (data is List) {
          source = data;
        } else if (data is Map) {
          source =
              data['history'] ?? data['items'] ?? data['rows'] ?? data['data'];
        } else {
          source = decoded['history'] ?? decoded['items'] ?? decoded['rows'];
        }
      }

      if (source is List) {
        return source
            .whereType<Map>()
            .map(_stringDynamicMap)
            .map(SalaryHistoryEntry.fromMap)
            .toList();
      }
    } catch (_) {}

    throw Exception('My salary history response format is not valid.');
  }

  Future<List<Map<String, dynamic>>> salaryIncentives({
    required String userId,
    String? token,
  }) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      throw Exception('User id is required.');
    }

    final resolvedToken = token ?? _authToken;
    final uri =
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.salaryIncentives}')
            .replace(queryParameters: <String, String>{
      'user_id': normalizedUserId,
    });
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'salaryIncentives',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('salaryIncentives', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to fetch salary incentives.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      dynamic source;
      if (decoded is List) {
        source = decoded;
      } else if (decoded is Map<String, dynamic>) {
        final data = decoded['data'];
        if (data is List) {
          source = data;
        } else if (data is Map) {
          source = data['incentives'] ??
              data['items'] ??
              data['rows'] ??
              data['data'];
        } else {
          source = decoded['incentives'] ?? decoded['items'] ?? decoded['rows'];
        }
      }

      if (source is List) {
        return source
            .whereType<Map>()
            .map((item) => _stringDynamicMap(item))
            .toList();
      }
    } catch (_) {}

    throw Exception('Salary incentives response format is not valid.');
  }

  Future<List<Map<String, dynamic>>> myIncentives({String? token}) async {
    final resolvedToken = token ?? _authToken;
    final uri =
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.myIncentives}');
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'myIncentives',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('myIncentives', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to fetch your incentives.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      dynamic source;
      if (decoded is List) {
        source = decoded;
      } else if (decoded is Map<String, dynamic>) {
        final data = decoded['data'];
        if (data is List) {
          source = data;
        } else if (data is Map) {
          source = data['incentives'] ??
              data['items'] ??
              data['rows'] ??
              data['data'];
        } else {
          source = decoded['incentives'] ?? decoded['items'] ?? decoded['rows'];
        }
      }

      if (source is List) {
        return source
            .whereType<Map>()
            .map((item) => _stringDynamicMap(item))
            .toList();
      }
    } catch (_) {}

    throw Exception('My incentives response format is not valid.');
  }

  Future<SalaryIncentiveCreateResult> salaryAddIncentive({
    required String userId,
    required int month,
    required int year,
    required double amount,
    required String reason,
    String? token,
  }) async {
    final normalizedUserId = userId.trim();
    final normalizedReason = reason.trim();
    if (normalizedUserId.isEmpty) {
      throw Exception('User id is required.');
    }
    if (month < 1 || month > 12) {
      throw Exception('Valid month is required.');
    }
    if (year <= 0) {
      throw Exception('Valid year is required.');
    }
    if (amount <= 0) {
      throw Exception('Valid amount is required.');
    }
    if (normalizedReason.isEmpty) {
      throw Exception('Reason is required.');
    }

    final resolvedToken = token ?? _authToken;
    final uri = Uri.parse(
        '${ApiConstants.baseUrl}${ApiConstants.salaryIncentiveCreate}');
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    final body = jsonEncode(<String, dynamic>{
      'user_id': normalizedUserId,
      'month': month,
      'year': year,
      'amount': amount,
      'reason': normalizedReason,
    });
    _logRequest(
      endpoint: 'salaryAddIncentive',
      method: 'POST',
      uri: uri,
      headers: headers,
      body: body,
    );

    final response = await http
        .post(uri, headers: headers, body: body)
        .timeout(_requestTimeout);
    _logResponse('salaryAddIncentive', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to add salary incentive.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Add incentive response format is not valid.');
      }
      final data = decoded['data'];
      Map<String, dynamic> incentive = const {};
      if (data is Map<String, dynamic>) {
        final incentiveRaw =
            data['incentive'] ?? data['item'] ?? data['row'] ?? data;
        if (incentiveRaw is Map) {
          incentive = _stringDynamicMap(incentiveRaw);
        }
      }
      return SalaryIncentiveCreateResult(
        message: decoded['message']?.toString().trim().isNotEmpty == true
            ? decoded['message'].toString().trim()
            : 'Incentive added successfully',
        incentive: incentive,
      );
    } catch (_) {
      throw Exception('Add incentive response format is not valid.');
    }
  }

  Future<MySalaryResult> mySalary({
    int? month,
    required int year,
    String? token,
  }) async {
    final resolvedToken = token ?? _authToken;
    final query = <String, String>{
      'year': year.toString(),
    };
    if (month != null && month > 0) {
      query['month'] = month.toString();
    }
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.mySalary}')
        .replace(queryParameters: query);
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'mySalary',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('mySalary', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to fetch your salary details.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('My salary response format is not valid.');
      }
      final data = decoded['data'];
      if (data is! Map<String, dynamic>) {
        throw Exception('My salary data is missing.');
      }

      final currentRaw = data['current_monthly_salary'];
      final slipsRaw = data['salary_slips'];
      final slips = slipsRaw is List
          ? slipsRaw
              .whereType<Map>()
              .map(_stringDynamicMap)
              .map(MySalarySlip.fromMap)
              .toList()
          : <MySalarySlip>[];
      return MySalaryResult(
        currentMonthlySalary: currentRaw is Map
            ? MySalaryCurrent.fromMap(_stringDynamicMap(currentRaw))
            : null,
        salarySlips: slips,
        message: decoded['message']?.toString().trim() ?? 'Your salary details',
      );
    } catch (_) {
      throw Exception('My salary response format is not valid.');
    }
  }

  Future<LeadsListResult> leads({
    String? token,
    String? status,
    String? source,
    String? assignedTo,
    String? from,
    String? to,
    String? search,
    int page = 1,
    int perPage = 20,
  }) async {
    final resolvedToken = token ?? _authToken;
    final query = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
    };

    if (status != null && status.trim().isNotEmpty) {
      query['status'] = status.trim();
    }
    if (source != null && source.trim().isNotEmpty) {
      query['source'] = source.trim();
    }
    if (assignedTo != null && assignedTo.trim().isNotEmpty) {
      query['assigned_to'] = assignedTo.trim();
    }
    if (from != null && from.trim().isNotEmpty) {
      query['from'] = from.trim();
    }
    if (to != null && to.trim().isNotEmpty) {
      query['to'] = to.trim();
    }
    if (search != null && search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }

    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.leads}')
        .replace(queryParameters: query);
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'leads',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('leads', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to fetch leads.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic body = jsonDecode(response.body);
      final items = _extractLeadsItems(body);
      final pagination = _extractPaginationMap(body);

      final resolvedCurrentPage = _readIntFromMap(
              pagination, ['page', 'current_page', 'currentPage']) ??
          page;
      final resolvedPerPage = _readIntFromMap(
              pagination, ['per_page', 'perPage', 'page_size', 'limit']) ??
          perPage;
      final resolvedTotalItems = _readIntFromMap(
              pagination, ['total', 'total_items', 'totalItems', 'count']) ??
          items.length;
      final resolvedTotalPages = _readIntFromMap(pagination,
              ['total_pages', 'totalPages', 'last_page', 'lastPage']) ??
          _deriveTotalPages(
              total: resolvedTotalItems, perPage: resolvedPerPage);

      return LeadsListResult(
        items: items,
        currentPage: resolvedCurrentPage,
        perPage: resolvedPerPage,
        totalItems: resolvedTotalItems,
        totalPages: resolvedTotalPages <= 0 ? 1 : resolvedTotalPages,
      );
    } catch (_) {
      throw Exception('Leads response format is not valid.');
    }
  }

  Future<LeadsListResult> myLeads({
    String? token,
    String? status,
    String? source,
    String? from,
    String? to,
    String? search,
    int page = 1,
    int perPage = 20,
  }) async {
    final resolvedToken = token ?? _authToken;
    final query = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
    };

    if (status != null && status.trim().isNotEmpty) {
      query['status'] = status.trim();
    }
    if (source != null && source.trim().isNotEmpty) {
      query['source'] = source.trim();
    }
    if (from != null && from.trim().isNotEmpty) {
      query['from'] = from.trim();
    }
    if (to != null && to.trim().isNotEmpty) {
      query['to'] = to.trim();
    }
    if (search != null && search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }

    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.myLeads}')
        .replace(queryParameters: query);
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'myLeads',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('myLeads', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to fetch my leads.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic body = jsonDecode(response.body);
      final items = _extractLeadsItems(body);
      final pagination = _extractPaginationMap(body);

      final resolvedCurrentPage = _readIntFromMap(
              pagination, ['page', 'current_page', 'currentPage']) ??
          page;
      final resolvedPerPage = _readIntFromMap(
              pagination, ['per_page', 'perPage', 'page_size', 'limit']) ??
          perPage;
      final resolvedTotalItems = _readIntFromMap(
              pagination, ['total', 'total_items', 'totalItems', 'count']) ??
          items.length;
      final resolvedTotalPages = _readIntFromMap(pagination,
              ['total_pages', 'totalPages', 'last_page', 'lastPage']) ??
          _deriveTotalPages(
              total: resolvedTotalItems, perPage: resolvedPerPage);

      return LeadsListResult(
        items: items,
        currentPage: resolvedCurrentPage,
        perPage: resolvedPerPage,
        totalItems: resolvedTotalItems,
        totalPages: resolvedTotalPages <= 0 ? 1 : resolvedTotalPages,
      );
    } catch (_) {
      throw Exception('My leads response format is not valid.');
    }
  }

  Future<void> deleteLead({
    required String id,
    String? token,
  }) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) {
      throw Exception('Lead id is required.');
    }

    final resolvedToken = token ?? _authToken;
    final endpoint =
        ApiConstants.deleteleads.replaceFirst('{id}', normalizedId);
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final headers = _headers(accept: '*/*', token: resolvedToken);
    _logRequest(
      endpoint: 'deleteLead',
      method: 'DELETE',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.delete(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('deleteLead', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to delete lead.',
    );
    if (error != null) {
      throw Exception(error);
    }
  }

  Future<ExportFileResult> exportLeads({
    required String from,
    required String to,
    String? token,
  }) async {
    final resolvedToken = token ?? _authToken;
    final query = <String, String>{
      'from': from.trim(),
      'to': to.trim(),
    };
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.exportLeads}')
        .replace(queryParameters: query);
    final headers = _headers(
      accept:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      token: resolvedToken,
    );
    _logRequest(
      endpoint: 'exportLeads',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('exportLeads', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to export leads.',
    );
    if (error != null) {
      throw Exception(error);
    }

    final contentTypeHeader = response.headers['content-type'] ?? '';
    final contentType = contentTypeHeader.trim().isEmpty
        ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        : contentTypeHeader;
    final disposition = response.headers['content-disposition'] ?? '';
    final fileName = _readFileNameFromDisposition(disposition) ??
        'leads_${from}_to_$to.xlsx';

    return ExportFileResult(
      fileName: fileName,
      bytes: response.bodyBytes,
      contentType: contentType,
    );
  }

  Future<ExportFileResult> downloadLeadBulkTemplate({String? token}) async {
    final resolvedToken = token ?? _authToken;
    final uri =
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.leadsBulkTemplate}');
    final headers = _headers(
      accept:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      token: resolvedToken,
    );
    _logRequest(
      endpoint: 'downloadLeadBulkTemplate',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('downloadLeadBulkTemplate', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to download lead upload template.',
    );
    if (error != null) {
      throw Exception(error);
    }

    final disposition = response.headers['content-disposition'] ?? '';
    final fileName =
        _readFileNameFromDisposition(disposition) ?? 'lead_bulk_template.xlsx';
    final contentTypeHeader = response.headers['content-type'] ?? '';
    final contentType = contentTypeHeader.trim().isEmpty
        ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        : contentTypeHeader;

    return ExportFileResult(
      fileName: fileName,
      bytes: response.bodyBytes,
      contentType: contentType,
    );
  }

  Future<Map<String, dynamic>> uploadLeadBulkFile({
    required String filePath,
    String? assignedTo,
    String? token,
  }) async {
    final resolvedToken = token ?? _authToken;
    final normalizedPath = filePath.trim();
    if (normalizedPath.isEmpty) {
      throw Exception('Select an Excel file to upload.');
    }

    final uri =
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.leadsBulkUpload}');
    final request = http.MultipartRequest('POST', uri);
    request.headers['accept'] = 'application/json';
    if (resolvedToken != null && resolvedToken.trim().isNotEmpty) {
      request.headers['Authorization'] = 'Bearer ${resolvedToken.trim()}';
    }
    final normalizedAssignee = assignedTo?.trim();
    if (normalizedAssignee != null && normalizedAssignee.isNotEmpty) {
      request.fields['assigned_to'] = normalizedAssignee;
    }
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        normalizedPath,
        contentType: _spreadsheetMediaType(normalizedPath),
      ),
    );

    _logRequest(
      endpoint: 'uploadLeadBulkFile',
      method: 'POST',
      uri: uri,
      headers: request.headers,
      body: 'multipart/form-data',
    );

    http.StreamedResponse streamedResponse;
    try {
      streamedResponse = await request.send().timeout(_requestTimeout);
    } on TimeoutException {
      throw Exception(
          'Server is taking too long to respond. Please try again.');
    } on SocketException {
      throw Exception('No internet connection or server is unreachable.');
    } on HandshakeException {
      throw Exception(
          'Secure connection failed. Check phone date/time and try again.');
    } on http.ClientException {
      throw Exception(
          'Network error while contacting server. Please try again.');
    }

    final response = await http.Response.fromStream(streamedResponse);
    _logResponse('uploadLeadBulkFile', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to upload leads file.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // handled below
    }

    throw Exception('Lead bulk upload response is not valid JSON.');
  }

  Future<ExportFileResult> downloadLeadBulkResult({
    required String filename,
    String? token,
  }) async {
    final normalizedFilename = filename.trim();
    if (normalizedFilename.isEmpty) {
      throw Exception('Result filename is required.');
    }

    final resolvedToken = token ?? _authToken;
    final endpoint = ApiConstants.leadsBulkResult.replaceFirst(
      '{filename}',
      Uri.encodeComponent(normalizedFilename),
    );
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final headers = _headers(
      accept:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      token: resolvedToken,
    );
    _logRequest(
      endpoint: 'downloadLeadBulkResult',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('downloadLeadBulkResult', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to download lead upload result.',
    );
    if (error != null) {
      throw Exception(error);
    }

    final disposition = response.headers['content-disposition'] ?? '';
    final fileName =
        _readFileNameFromDisposition(disposition) ?? normalizedFilename;
    final contentTypeHeader = response.headers['content-type'] ?? '';
    final contentType = contentTypeHeader.trim().isEmpty
        ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        : contentTypeHeader;

    return ExportFileResult(
      fileName: fileName,
      bytes: response.bodyBytes,
      contentType: contentType,
    );
  }

  Future<ExportFileResult> exportSiteVisits({String? token}) async {
    final resolvedToken = token ?? _authToken;
    final uri =
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.exportSiteVisits}');
    final headers = _headers(
      accept:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      token: resolvedToken,
    );
    _logRequest(
      endpoint: 'exportSiteVisits',
      method: 'GET',
      uri: uri,
      headers: headers,
    );
    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('exportSiteVisits', response);
    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to export site visits.',
    );
    if (error != null) {
      throw Exception(error);
    }
    final disposition = response.headers['content-disposition'] ?? '';
    final fileName =
        _readFileNameFromDisposition(disposition) ?? 'site_visits_export.xlsx';
    final contentTypeHeader = response.headers['content-type'] ?? '';
    final contentType = contentTypeHeader.trim().isEmpty
        ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        : contentTypeHeader;
    return ExportFileResult(
      fileName: fileName,
      bytes: response.bodyBytes,
      contentType: contentType,
    );
  }

  Future<ExportFileResult> exportFollowUps({String? token}) async {
    final resolvedToken = token ?? _authToken;
    final uri =
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.exportFollowUps}');
    final headers = _headers(
      accept:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      token: resolvedToken,
    );
    _logRequest(
      endpoint: 'exportFollowUps',
      method: 'GET',
      uri: uri,
      headers: headers,
    );
    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('exportFollowUps', response);
    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to export follow-ups.',
    );
    if (error != null) {
      throw Exception(error);
    }
    final disposition = response.headers['content-disposition'] ?? '';
    final fileName =
        _readFileNameFromDisposition(disposition) ?? 'follow_ups_export.xlsx';
    final contentTypeHeader = response.headers['content-type'] ?? '';
    final contentType = contentTypeHeader.trim().isEmpty
        ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        : contentTypeHeader;
    return ExportFileResult(
      fileName: fileName,
      bytes: response.bodyBytes,
      contentType: contentType,
    );
  }

  Future<ExportFileResult> exportProjects({String? token}) async {
    final resolvedToken = token ?? _authToken;
    final uri =
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.exportProjects}');
    final headers = _headers(
      accept:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      token: resolvedToken,
    );
    _logRequest(
      endpoint: 'exportProjects',
      method: 'GET',
      uri: uri,
      headers: headers,
    );
    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('exportProjects', response);
    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to export projects.',
    );
    if (error != null) {
      throw Exception(error);
    }
    final disposition = response.headers['content-disposition'] ?? '';
    final fileName =
        _readFileNameFromDisposition(disposition) ?? 'projects_export.xlsx';
    final contentTypeHeader = response.headers['content-type'] ?? '';
    final contentType = contentTypeHeader.trim().isEmpty
        ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        : contentTypeHeader;
    return ExportFileResult(
      fileName: fileName,
      bytes: response.bodyBytes,
      contentType: contentType,
    );
  }

  Future<ExportFileResult> exportUsers({String? token}) async {
    final resolvedToken = token ?? _authToken;
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.exportUsers}');
    final headers = _headers(
      accept:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      token: resolvedToken,
    );
    _logRequest(
      endpoint: 'exportUsers',
      method: 'GET',
      uri: uri,
      headers: headers,
    );
    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('exportUsers', response);
    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to export users.',
    );
    if (error != null) {
      throw Exception(error);
    }
    final disposition = response.headers['content-disposition'] ?? '';
    final fileName =
        _readFileNameFromDisposition(disposition) ?? 'users_export.xlsx';
    final contentTypeHeader = response.headers['content-type'] ?? '';
    final contentType = contentTypeHeader.trim().isEmpty
        ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        : contentTypeHeader;
    return ExportFileResult(
      fileName: fileName,
      bytes: response.bodyBytes,
      contentType: contentType,
    );
  }

  Future<ExportFileResult> exportAttendance({
    required String from,
    required String to,
    String? token,
  }) async {
    final resolvedToken = token ?? _authToken;
    final uri =
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.exportAttendance}')
            .replace(queryParameters: <String, String>{
      'from': from.trim(),
      'to': to.trim(),
    });
    final headers = _headers(
      accept:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      token: resolvedToken,
    );
    _logRequest(
      endpoint: 'exportAttendance',
      method: 'GET',
      uri: uri,
      headers: headers,
    );
    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('exportAttendance', response);
    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to export attendance.',
    );
    if (error != null) {
      throw Exception(error);
    }
    final disposition = response.headers['content-disposition'] ?? '';
    final fileName = _readFileNameFromDisposition(disposition) ??
        'attendance_${from}_to_$to.xlsx';
    final contentTypeHeader = response.headers['content-type'] ?? '';
    final contentType = contentTypeHeader.trim().isEmpty
        ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        : contentTypeHeader;
    return ExportFileResult(
      fileName: fileName,
      bytes: response.bodyBytes,
      contentType: contentType,
    );
  }

  Future<ExportFileResult> exportAll({String? token}) async {
    final resolvedToken = token ?? _authToken;
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.exportAll}');
    final headers = _headers(
      accept:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      token: resolvedToken,
    );
    _logRequest(
      endpoint: 'exportAll',
      method: 'GET',
      uri: uri,
      headers: headers,
    );
    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('exportAll', response);
    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to export all modules.',
    );
    if (error != null) {
      throw Exception(error);
    }
    final disposition = response.headers['content-disposition'] ?? '';
    final fileName =
        _readFileNameFromDisposition(disposition) ?? 'all_modules_export.xlsx';
    final contentTypeHeader = response.headers['content-type'] ?? '';
    final contentType = contentTypeHeader.trim().isEmpty
        ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        : contentTypeHeader;
    return ExportFileResult(
      fileName: fileName,
      bytes: response.bodyBytes,
      contentType: contentType,
    );
  }

  Future<Map<String, dynamic>> uploadAttendancePhoto({
    required String type,
    required String photoPath,
    String? token,
  }) async {
    final resolvedToken = token ?? _authToken;
    final normalizedType = type.trim().toLowerCase();
    if (normalizedType != 'checkin' && normalizedType != 'checkout') {
      throw Exception('Invalid attendance photo type.');
    }
    if (photoPath.trim().isEmpty) {
      throw Exception('Photo path is required.');
    }

    final uri = Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.attendanceUploadPhoto}',
    ).replace(queryParameters: <String, String>{'type': normalizedType});

    final request = http.MultipartRequest('POST', uri);
    request.headers['accept'] = 'application/json';
    if (resolvedToken != null && resolvedToken.trim().isNotEmpty) {
      request.headers['Authorization'] = 'Bearer ${resolvedToken.trim()}';
    }
    request.files.add(
      await http.MultipartFile.fromPath(
        'photo',
        photoPath.trim(),
        contentType: _imageMediaType(photoPath.trim()),
      ),
    );

    _logRequest(
      endpoint: 'uploadAttendancePhoto',
      method: 'POST',
      uri: uri,
      headers: request.headers,
      body: 'multipart/form-data',
    );

    http.StreamedResponse streamedResponse;
    try {
      streamedResponse = await request.send().timeout(_requestTimeout);
    } on TimeoutException {
      throw Exception(
          'Server is taking too long to respond. Please try again.');
    } on SocketException {
      throw Exception('No internet connection or server is unreachable.');
    } on HandshakeException {
      throw Exception(
          'Secure connection failed. Check phone date/time and try again.');
    } on http.ClientException {
      throw Exception(
          'Network error while contacting server. Please try again.');
    }

    final response = await http.Response.fromStream(streamedResponse);
    _logResponse('uploadAttendancePhoto', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to upload attendance photo.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // handled below
    }
    throw Exception('Attendance photo upload response is not valid JSON.');
  }

  Future<Map<String, dynamic>> attendanceCheckIn({
    required String photoUrl,
    required double latitude,
    required double longitude,
    required String address,
    required String device,
    required String notes,
    String? token,
  }) async {
    final resolvedToken = token ?? _authToken;
    final uri =
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.attendanceCheckin}');
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    final body = jsonEncode(<String, dynamic>{
      'photo_url': photoUrl,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'device': device,
      'notes': notes,
    });
    _logRequest(
      endpoint: 'attendanceCheckIn',
      method: 'POST',
      uri: uri,
      headers: headers,
      body: body,
    );

    final response = await http
        .post(uri, headers: headers, body: body)
        .timeout(_requestTimeout);
    _logResponse('attendanceCheckIn', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to check in.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // handled below
    }
    throw Exception('Attendance check-in response is not valid JSON.');
  }

  Future<Map<String, dynamic>> attendanceCheckOut({
    required String photoUrl,
    required double latitude,
    required double longitude,
    required String address,
    required String device,
    required String notes,
    String? token,
  }) async {
    final resolvedToken = token ?? _authToken;
    final uri =
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.attendanceCheckout}');
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    final body = jsonEncode(<String, dynamic>{
      'photo_url': photoUrl,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'device': device,
      'notes': notes,
    });
    _logRequest(
      endpoint: 'attendanceCheckOut',
      method: 'POST',
      uri: uri,
      headers: headers,
      body: body,
    );

    final response = await http
        .post(uri, headers: headers, body: body)
        .timeout(_requestTimeout);
    _logResponse('attendanceCheckOut', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to check out.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // handled below
    }
    throw Exception('Attendance check-out response is not valid JSON.');
  }

  Future<Map<String, dynamic>> attendanceToday({String? token}) async {
    final resolvedToken = token ?? _authToken;
    final uri =
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.attendanceToday}');
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'attendanceToday',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('attendanceToday', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to fetch today attendance.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final dynamic data = decoded['data'];
        if (data is Map<String, dynamic>) {
          return data;
        }
        return decoded;
      }
    } catch (_) {
      // handled below
    }

    throw Exception('Today attendance response is not valid JSON.');
  }

  Future<Map<String, dynamic>> attendanceCalendar({
    required int month,
    required int year,
    String? token,
  }) async {
    final resolvedToken = token ?? _authToken;
    final uri = Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.attendanceCalendar}',
    ).replace(queryParameters: <String, String>{
      'month': month.toString(),
      'year': year.toString(),
    });
    final headers = _headers(accept: '*/*', token: resolvedToken);
    _logRequest(
      endpoint: 'attendanceCalendar',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('attendanceCalendar', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to fetch attendance calendar.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final dynamic data = decoded['data'];
        if (data is Map<String, dynamic>) {
          return data;
        }
        return decoded;
      }
    } catch (_) {
      // handled below
    }

    throw Exception('Attendance calendar response is not valid JSON.');
  }

  Future<Map<String, dynamic>> attendanceMe({
    int page = 1,
    int perPage = 30,
    String? token,
  }) async {
    final resolvedToken = token ?? _authToken;
    final uri = Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.attendanceMe}',
    ).replace(queryParameters: <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
    });
    final headers = _headers(accept: '*/*', token: resolvedToken);
    _logRequest(
      endpoint: 'attendanceMe',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('attendanceMe', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to fetch attendance history.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // handled below
    }

    throw Exception('Attendance history response is not valid JSON.');
  }

  Future<Map<String, dynamic>> attendanceUserHistory({
    required String userId,
    String? from,
    String? to,
    String? status,
    int page = 1,
    int perPage = 30,
    String? token,
  }) async {
    final resolvedToken = token ?? _authToken;
    final path =
        ApiConstants.attendanceUserHistory.replaceFirst('{userId}', userId);
    final queryParameters = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
      if (from != null && from.trim().isNotEmpty) 'from': from.trim(),
      if (to != null && to.trim().isNotEmpty) 'to': to.trim(),
      if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
    };
    final uri = Uri.parse(
      '${ApiConstants.baseUrl}$path',
    ).replace(queryParameters: queryParameters);
    final headers = _headers(accept: '*/*', token: resolvedToken);
    _logRequest(
      endpoint: 'attendanceUserHistory',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('attendanceUserHistory', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to fetch user attendance history.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // handled below
    }

    throw Exception('User attendance history response is not valid JSON.');
  }

  Future<Map<String, dynamic>> attendanceUser({
    required String userId,
    String? from,
    String? to,
    String? status,
    int page = 1,
    int perPage = 30,
    String? token,
  }) {
    return attendanceUserHistory(
      userId: userId,
      from: from,
      to: to,
      status: status,
      page: page,
      perPage: perPage,
      token: token,
    );
  }

  Future<Map<String, dynamic>> attendanceByMonth({
    required int month,
    required int year,
    int page = 1,
    int perPage = 50,
    String? token,
  }) async {
    final resolvedToken = token ?? _authToken;
    final uri = Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.attendanceByMonth}',
    ).replace(queryParameters: <String, String>{
      'month': month.toString(),
      'year': year.toString(),
      'page': page.toString(),
      'per_page': perPage.toString(),
    });
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'attendanceByMonth',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('attendanceByMonth', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to fetch monthly attendance grid.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // handled below
    }

    throw Exception('Monthly attendance grid response is not valid JSON.');
  }

  Future<Map<String, dynamic>> attendanceByDate({
    required String date,
    String? token,
  }) async {
    final resolvedToken = token ?? _authToken;
    final uri = Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.attendanceByDate}',
    ).replace(queryParameters: <String, String>{
      'date': date,
    });
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'attendanceByDate',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('attendanceByDate', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to fetch daily attendance.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final dynamic data = decoded['data'];
        if (data is Map<String, dynamic>) {
          return data;
        }
        return decoded;
      }
    } catch (_) {
      // handled below
    }

    throw Exception('Daily attendance response is not valid JSON.');
  }

  Future<Map<String, dynamic>> attendanceSummary({
    String? from,
    String? to,
    String? token,
  }) async {
    final resolvedToken = token ?? _authToken;
    final query = <String, String>{};
    if (from != null && from.trim().isNotEmpty) {
      query['from'] = from.trim();
    }
    if (to != null && to.trim().isNotEmpty) {
      query['to'] = to.trim();
    }

    final uri = query.isEmpty
        ? Uri.parse('${ApiConstants.baseUrl}${ApiConstants.attendanceSummary}')
        : Uri.parse('${ApiConstants.baseUrl}${ApiConstants.attendanceSummary}')
            .replace(queryParameters: query);
    final headers = _headers(accept: '*/*', token: resolvedToken);
    _logRequest(
      endpoint: 'attendanceSummary',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('attendanceSummary', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to fetch attendance summary.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final dynamic data = decoded['data'];
        if (data is Map<String, dynamic>) {
          return data;
        }
        return decoded;
      }
    } catch (_) {
      // handled below
    }

    throw Exception('Attendance summary response is not valid JSON.');
  }

  Future<Map<String, dynamic>> attendanceLate({String? token}) async {
    final resolvedToken = token ?? _authToken;
    final uri =
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.attendanceLate}');
    final headers = _headers(accept: '*/*', token: resolvedToken);
    _logRequest(
      endpoint: 'attendanceLate',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('attendanceLate', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to fetch late attendance reports.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final dynamic data = decoded['data'];
        if (data is Map<String, dynamic>) {
          return data;
        }
        return decoded;
      }
    } catch (_) {
      // handled below
    }

    throw Exception('Late attendance response is not valid JSON.');
  }

  Future<Map<String, dynamic>> attendanceTeam({
    String? from,
    String? to,
    int page = 1,
    int perPage = 100,
    String? token,
  }) async {
    final resolvedToken = token ?? _authToken;
    final query = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
    if (from != null && from.trim().isNotEmpty) {
      query['from'] = from.trim();
    }
    if (to != null && to.trim().isNotEmpty) {
      query['to'] = to.trim();
    }

    final uri =
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.attendanceTeam}')
            .replace(queryParameters: query);
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'attendanceTeam',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('attendanceTeam', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to fetch team attendance.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // handled below
    }

    throw Exception('Team attendance response is not valid JSON.');
  }

  Future<Map<String, dynamic>> attendancePending({
    String? date,
    String? token,
  }) async {
    final resolvedToken = token ?? _authToken;
    final query = <String, String>{};
    if (date != null && date.trim().isNotEmpty) {
      query['date'] = date.trim();
    }

    final uri = query.isEmpty
        ? Uri.parse('${ApiConstants.baseUrl}${ApiConstants.attendancePending}')
        : Uri.parse('${ApiConstants.baseUrl}${ApiConstants.attendancePending}')
            .replace(queryParameters: query);
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'attendancePending',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('attendancePending', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to fetch pending attendance approvals.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final dynamic data = decoded['data'];
        if (data is Map<String, dynamic>) {
          return data;
        }
        return decoded;
      }
    } catch (_) {
      // handled below
    }

    throw Exception('Pending approvals response is not valid JSON.');
  }

  Future<Map<String, dynamic>> attendanceApprove({
    required String id,
    required String status,
    String? reason,
    String? token,
  }) async {
    final resolvedToken = token ?? _authToken;
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) {
      throw Exception('Attendance approval id is required.');
    }
    final endpoint =
        ApiConstants.attendanceapprove.replaceAll('{id}', normalizedId);
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    final payload = <String, dynamic>{
      'status': status.trim(),
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    };
    _logRequest(
      endpoint: 'attendanceApprove',
      method: 'PATCH',
      uri: uri,
      headers: headers,
      body: jsonEncode(payload),
    );

    final response = await http
        .patch(uri, headers: headers, body: jsonEncode(payload))
        .timeout(_requestTimeout);
    _logResponse('attendanceApprove', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to update attendance status.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final dynamic data = decoded['data'];
        if (data is Map<String, dynamic>) {
          return data;
        }
        return decoded;
      }
    } catch (_) {
      // handled below
    }

    return <String, dynamic>{'id': normalizedId, 'status': status};
  }

  Future<LeadsListResult> phoneRevealMyRequests({
    int page = 1,
    int perPage = 20,
    String? token,
  }) async {
    return _phoneRevealList(
      endpoint: ApiConstants.phoneRevealMyRequests,
      page: page,
      perPage: perPage,
      token: token,
      fallbackMessage: 'Unable to fetch your phone requests.',
    );
  }

  Future<LeadsListResult> phoneRevealPending({
    int page = 1,
    int perPage = 20,
    String? token,
  }) async {
    return _phoneRevealList(
      endpoint: ApiConstants.phoneRevealPending,
      page: page,
      perPage: perPage,
      token: token,
      fallbackMessage: 'Unable to fetch pending phone requests.',
    );
  }

  Future<LeadsListResult> phoneRevealAll({
    int page = 1,
    int perPage = 20,
    String? token,
  }) async {
    return _phoneRevealList(
      endpoint: ApiConstants.phoneRevealAll,
      page: page,
      perPage: perPage,
      token: token,
      fallbackMessage: 'Unable to fetch all phone requests.',
    );
  }

  Future<Map<String, dynamic>> phoneRevealCheck({
    required String leadId,
    String? token,
  }) async {
    final normalizedLeadId = leadId.trim();
    if (normalizedLeadId.isEmpty) {
      throw Exception('Lead id is required.');
    }

    final resolvedToken = token ?? _authToken;
    final endpoint = ApiConstants.phoneRevealCheck
        .replaceFirst('{leadId}', normalizedLeadId);
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final headers = _headers(accept: 'application/json', token: resolvedToken);

    _logRequest(
      endpoint: 'phoneRevealCheck',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('phoneRevealCheck', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to verify phone access.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final data = decoded['data'];
        if (data is Map<String, dynamic>) {
          return data;
        }
        return decoded;
      }
    } catch (_) {
      // fall through
    }

    throw Exception('Phone access check response is not valid JSON.');
  }

  Future<Map<String, dynamic>> requestPhoneReveal({
    required String leadId,
    required String reason,
    String? token,
  }) async {
    final normalizedLeadId = leadId.trim();
    if (normalizedLeadId.isEmpty) {
      throw Exception('Lead id is required.');
    }

    final resolvedToken = token ?? _authToken;
    final uri =
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.phoneRevealRequest}');
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    final body = jsonEncode({
      'lead_id': normalizedLeadId,
      'reason': reason.trim(),
    });

    _logRequest(
      endpoint: 'requestPhoneReveal',
      method: 'POST',
      uri: uri,
      headers: headers,
      body: body,
    );

    final response = await http
        .post(uri, headers: headers, body: body)
        .timeout(_requestTimeout);
    _logResponse('requestPhoneReveal', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to submit phone access request.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final data = decoded['data'];
        if (data is Map<String, dynamic>) {
          return data;
        }
        return decoded;
      }
    } catch (_) {
      // fall through
    }

    throw Exception('Phone request response is not valid JSON.');
  }

  Future<Map<String, dynamic>> bulkRequestPhoneReveal({
    required List<String> leadIds,
    required String reason,
    String? token,
  }) async {
    final normalizedLeadIds =
        leadIds.map((id) => id.trim()).where((id) => id.isNotEmpty).toList();
    if (normalizedLeadIds.isEmpty) {
      throw Exception('Select at least one lead.');
    }

    final resolvedToken = token ?? _authToken;
    final uri = Uri.parse(
        '${ApiConstants.baseUrl}${ApiConstants.phoneRevealBulkRequest}');
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    final body = jsonEncode({
      'lead_ids': normalizedLeadIds,
      'reason': reason.trim(),
    });

    _logRequest(
      endpoint: 'bulkRequestPhoneReveal',
      method: 'POST',
      uri: uri,
      headers: headers,
      body: body,
    );

    final response = await http
        .post(uri, headers: headers, body: body)
        .timeout(_requestTimeout);
    _logResponse('bulkRequestPhoneReveal', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to submit bulk phone access request.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final data = decoded['data'];
        if (data is Map<String, dynamic>) {
          return data;
        }
        return decoded;
      }
    } catch (_) {
      // fall through
    }

    throw Exception('Bulk phone request response is not valid JSON.');
  }

  Future<Map<String, dynamic>> approvePhoneReveal({
    required String id,
    required String note,
    String? token,
  }) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) {
      throw Exception('Phone request id is required.');
    }

    final resolvedToken = token ?? _authToken;
    final endpoint =
        ApiConstants.phoneRevealApprove.replaceFirst('{id}', normalizedId);
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    final body = jsonEncode({'note': note.trim()});

    _logRequest(
      endpoint: 'approvePhoneReveal',
      method: 'PATCH',
      uri: uri,
      headers: headers,
      body: body,
    );

    final response = await http
        .patch(uri, headers: headers, body: body)
        .timeout(_requestTimeout);
    _logResponse('approvePhoneReveal', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to approve phone request.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final data = decoded['data'];
        if (data is Map<String, dynamic>) {
          return data;
        }
        return decoded;
      }
    } catch (_) {
      // Some endpoints may return empty/non-json body.
    }

    return <String, dynamic>{'id': normalizedId, 'status': 'approved'};
  }

  Future<Map<String, dynamic>> declinePhoneReveal({
    required String id,
    required String note,
    String? token,
  }) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) {
      throw Exception('Phone request id is required.');
    }

    final resolvedToken = token ?? _authToken;
    final endpoint =
        ApiConstants.phoneRevealDecline.replaceFirst('{id}', normalizedId);
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    final body = jsonEncode({'note': note.trim()});

    _logRequest(
      endpoint: 'declinePhoneReveal',
      method: 'PATCH',
      uri: uri,
      headers: headers,
      body: body,
    );

    final response = await http
        .patch(uri, headers: headers, body: body)
        .timeout(_requestTimeout);
    _logResponse('declinePhoneReveal', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to decline phone request.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final data = decoded['data'];
        if (data is Map<String, dynamic>) {
          return data;
        }
        return decoded;
      }
    } catch (_) {
      // Some endpoints may return empty/non-json body.
    }

    return <String, dynamic>{'id': normalizedId, 'status': 'declined'};
  }

  Future<LeadsListResult> _phoneRevealList({
    required String endpoint,
    required int page,
    required int perPage,
    required String fallbackMessage,
    String? token,
  }) async {
    final resolvedToken = token ?? _authToken;
    final query = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint')
        .replace(queryParameters: query);
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: endpoint,
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse(endpoint, response);

    final error = _handleResponse(
      response,
      fallbackMessage: fallbackMessage,
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic body = jsonDecode(response.body);
      final items = _extractLeadsItems(body);
      final pagination = _extractPaginationMap(body);
      final resolvedCurrentPage = _readIntFromMap(
            pagination,
            ['page', 'current_page', 'currentPage'],
          ) ??
          page;
      final resolvedPerPage = _readIntFromMap(
            pagination,
            ['per_page', 'perPage', 'page_size', 'limit'],
          ) ??
          perPage;
      final resolvedTotalItems = _readIntFromMap(
            pagination,
            ['total', 'total_items', 'totalItems', 'count'],
          ) ??
          items.length;
      final resolvedTotalPages = _readIntFromMap(
            pagination,
            ['total_pages', 'totalPages', 'last_page', 'lastPage'],
          ) ??
          _deriveTotalPages(
              total: resolvedTotalItems, perPage: resolvedPerPage);

      return LeadsListResult(
        items: items,
        currentPage: resolvedCurrentPage,
        perPage: resolvedPerPage,
        totalItems: resolvedTotalItems,
        totalPages: resolvedTotalPages <= 0 ? 1 : resolvedTotalPages,
      );
    } catch (_) {
      throw Exception('$fallbackMessage Invalid response format.');
    }
  }

  Future<LeadsListResult> followUps({
    String? token,
    String? assignedTo,
    String? dueFrom,
    String? dueTo,
    String? search,
    int? page,
    int? perPage,
  }) async {
    final resolvedToken = token ?? _authToken;
    final query = <String, String>{};

    if (page != null && page > 0) {
      query['page'] = page.toString();
    }
    if (perPage != null && perPage > 0) {
      query['per_page'] = perPage.toString();
    }
    if (assignedTo != null && assignedTo.trim().isNotEmpty) {
      query['assigned_to'] = assignedTo.trim();
    }

    if (dueFrom != null && dueFrom.trim().isNotEmpty) {
      query['due_from'] = dueFrom.trim();
    }
    if (dueTo != null && dueTo.trim().isNotEmpty) {
      query['due_to'] = dueTo.trim();
    }
    if (search != null && search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }

    final uri = query.isEmpty
        ? Uri.parse('${ApiConstants.baseUrl}${ApiConstants.followups}')
        : Uri.parse('${ApiConstants.baseUrl}${ApiConstants.followups}')
            .replace(queryParameters: query);
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'followUps',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('followUps', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to fetch follow-ups.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic body = jsonDecode(response.body);
      final items = _extractLeadsItems(body);
      final pagination = _extractPaginationMap(body);

      final resolvedCurrentPage = _readIntFromMap(
              pagination, ['page', 'current_page', 'currentPage']) ??
          (page ?? 1);
      final resolvedPerPage = _readIntFromMap(
              pagination, ['per_page', 'perPage', 'page_size', 'limit']) ??
          (perPage ?? items.length);
      final resolvedTotalItems = _readIntFromMap(
              pagination, ['total', 'total_items', 'totalItems', 'count']) ??
          items.length;
      final resolvedTotalPages = _readIntFromMap(pagination,
              ['total_pages', 'totalPages', 'last_page', 'lastPage']) ??
          _deriveTotalPages(
              total: resolvedTotalItems, perPage: resolvedPerPage);

      return LeadsListResult(
        items: items,
        currentPage: resolvedCurrentPage,
        perPage: resolvedPerPage,
        totalItems: resolvedTotalItems,
        totalPages: resolvedTotalPages <= 0 ? 1 : resolvedTotalPages,
      );
    } catch (_) {
      throw Exception('Follow-ups response format is not valid.');
    }
  }

  Future<LeadsListResult> myFollowUps({
    String? token,
    int page = 1,
    int perPage = 20,
  }) async {
    final resolvedToken = token ?? _authToken;
    final query = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
    };

    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.myFollowUps}')
        .replace(queryParameters: query);
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'myFollowUps',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('myFollowUps', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to fetch my follow-ups.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic body = jsonDecode(response.body);
      final items = _extractLeadsItems(body);
      final pagination = _extractPaginationMap(body);

      final resolvedCurrentPage = _readIntFromMap(
              pagination, ['page', 'current_page', 'currentPage']) ??
          page;
      final resolvedPerPage = _readIntFromMap(
              pagination, ['per_page', 'perPage', 'page_size', 'limit']) ??
          perPage;
      final resolvedTotalItems = _readIntFromMap(
              pagination, ['total', 'total_items', 'totalItems', 'count']) ??
          items.length;
      final resolvedTotalPages = _readIntFromMap(pagination,
              ['total_pages', 'totalPages', 'last_page', 'lastPage']) ??
          _deriveTotalPages(
              total: resolvedTotalItems, perPage: resolvedPerPage);

      return LeadsListResult(
        items: items,
        currentPage: resolvedCurrentPage,
        perPage: resolvedPerPage,
        totalItems: resolvedTotalItems,
        totalPages: resolvedTotalPages <= 0 ? 1 : resolvedTotalPages,
      );
    } catch (_) {
      throw Exception('My follow-ups response format is not valid.');
    }
  }

  Future<Map<String, dynamic>> createFollowUp({
    required String title,
    required String leadId,
    required String dueDate,
    required String priority,
    required String notes,
    String? token,
  }) async {
    final resolvedToken = token ?? _authToken;
    final uri =
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.createfollowups}');
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    final body = jsonEncode({
      'title': title.trim(),
      'lead_id': leadId.trim(),
      'due_date': dueDate.trim(),
      'priority': priority.trim(),
      'notes': notes.trim(),
    });

    _logRequest(
      endpoint: 'createFollowUp',
      method: 'POST',
      uri: uri,
      headers: headers,
      body: body,
    );

    final response = await http
        .post(uri, headers: headers, body: body)
        .timeout(_requestTimeout);
    _logResponse('createFollowUp', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to create follow-up.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final data = decoded['data'];
        if (data is Map<String, dynamic>) {
          return data;
        }
        return decoded;
      }
    } catch (_) {
      // fall through
    }

    return <String, dynamic>{
      'title': title.trim(),
      'lead_id': leadId.trim(),
      'due_date': dueDate.trim(),
      'priority': priority.trim(),
      'notes': notes.trim(),
    };
  }

  Future<Map<String, dynamic>> editFollowUp({
    required String id,
    String? title,
    String? leadId,
    String? dueDate,
    String? priority,
    String? notes,
    String? token,
  }) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) {
      throw Exception('Follow-up id is required.');
    }

    final payload = <String, dynamic>{};
    if (title != null && title.trim().isNotEmpty) {
      payload['title'] = title.trim();
    }
    if (leadId != null && leadId.trim().isNotEmpty) {
      payload['lead_id'] = leadId.trim();
    }
    if (dueDate != null && dueDate.trim().isNotEmpty) {
      payload['due_date'] = dueDate.trim();
    }
    if (priority != null && priority.trim().isNotEmpty) {
      payload['priority'] = priority.trim();
    }
    if (notes != null) {
      payload['notes'] = notes.trim();
    }
    if (payload.isEmpty) {
      throw Exception('No fields provided for follow-up update.');
    }

    final resolvedToken = token ?? _authToken;
    final endpoint =
        ApiConstants.editfollowups.replaceFirst('{id}', normalizedId);
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final headers = _headers(accept: '*/*', token: resolvedToken);
    final body = jsonEncode(payload);

    _logRequest(
      endpoint: 'editFollowUp',
      method: 'PUT',
      uri: uri,
      headers: headers,
      body: body,
    );

    final response = await http
        .put(uri, headers: headers, body: body)
        .timeout(_requestTimeout);
    _logResponse('editFollowUp', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to update follow-up.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final data = decoded['data'];
        if (data is Map<String, dynamic>) {
          return data;
        }
        return decoded;
      }
    } catch (_) {
      // Some endpoints may return empty/non-json body on update.
    }

    return <String, dynamic>{'id': normalizedId, ...payload};
  }

  Future<Map<String, dynamic>> followUpDetail({
    required String id,
    String? token,
  }) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) {
      throw Exception('Follow-up id is required.');
    }

    final resolvedToken = token ?? _authToken;
    final endpoint =
        ApiConstants.followupsdetail.replaceFirst('{id}', normalizedId);
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final headers = _headers(accept: '*/*', token: resolvedToken);
    _logRequest(
      endpoint: 'followUpDetail',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('followUpDetail', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to fetch follow-up details.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final data = decoded['data'];
        if (data is Map<String, dynamic>) {
          return data;
        }
        return decoded;
      }
    } catch (_) {
      // Fall through to generic error below.
    }

    throw Exception('Follow-up details response format is not valid.');
  }

  Future<Map<String, dynamic>> completeFollowUpStatus({
    required String id,
    required bool isCompleted,
    String? token,
  }) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) {
      throw Exception('Follow-up id is required.');
    }

    final resolvedToken = token ?? _authToken;
    final endpoint =
        ApiConstants.completestatusfollowups.replaceFirst('{id}', normalizedId);
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    final body = jsonEncode({'is_completed': isCompleted});

    _logRequest(
      endpoint: 'completeFollowUpStatus',
      method: 'PATCH',
      uri: uri,
      headers: headers,
      body: body,
    );

    final response = await http
        .patch(uri, headers: headers, body: body)
        .timeout(_requestTimeout);
    _logResponse('completeFollowUpStatus', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to update follow-up status.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final data = decoded['data'];
        if (data is Map<String, dynamic>) {
          return data;
        }
        return decoded;
      }
    } catch (_) {
      // Some endpoints may return empty/non-json body.
    }

    return <String, dynamic>{
      'id': normalizedId,
      'is_completed': isCompleted,
    };
  }

  Future<LeadsListResult> siteVisits({
    String? token,
    String? status,
    int page = 1,
    int perPage = 20,
  }) async {
    final resolvedToken = token ?? _authToken;
    final queryParams = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
    final normalizedStatus = status?.trim() ?? '';
    if (normalizedStatus.isNotEmpty) {
      queryParams['status'] = normalizedStatus;
    }

    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.sitevisits}')
        .replace(queryParameters: queryParams);
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'siteVisits',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('siteVisits', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to fetch site visits.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic body = jsonDecode(response.body);
      final items = _extractLeadsItems(body);
      final pagination = _extractPaginationMap(body);

      final resolvedCurrentPage = _readIntFromMap(
              pagination, ['page', 'current_page', 'currentPage']) ??
          page;
      final resolvedPerPage = _readIntFromMap(
              pagination, ['per_page', 'perPage', 'page_size', 'limit']) ??
          perPage;
      final resolvedTotalItems = _readIntFromMap(
              pagination, ['total', 'total_items', 'totalItems', 'count']) ??
          items.length;
      final resolvedTotalPages = _readIntFromMap(pagination,
              ['total_pages', 'totalPages', 'last_page', 'lastPage']) ??
          _deriveTotalPages(
              total: resolvedTotalItems, perPage: resolvedPerPage);

      return LeadsListResult(
        items: items,
        currentPage: resolvedCurrentPage,
        perPage: resolvedPerPage,
        totalItems: resolvedTotalItems,
        totalPages: resolvedTotalPages <= 0 ? 1 : resolvedTotalPages,
      );
    } catch (_) {
      throw Exception('Site visits response format is not valid.');
    }
  }

  Future<LeadsListResult> mySiteVisits({
    String? token,
    int page = 1,
    int perPage = 20,
  }) async {
    final resolvedToken = token ?? _authToken;
    final query = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
    };

    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.mySiteVisits}')
        .replace(queryParameters: query);
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'mySiteVisits',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('mySiteVisits', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to fetch my site visits.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic body = jsonDecode(response.body);
      final items = _extractLeadsItems(body);
      final pagination = _extractPaginationMap(body);

      final resolvedCurrentPage = _readIntFromMap(
              pagination, ['page', 'current_page', 'currentPage']) ??
          page;
      final resolvedPerPage = _readIntFromMap(
              pagination, ['per_page', 'perPage', 'page_size', 'limit']) ??
          perPage;
      final resolvedTotalItems = _readIntFromMap(
              pagination, ['total', 'total_items', 'totalItems', 'count']) ??
          items.length;
      final resolvedTotalPages = _readIntFromMap(pagination,
              ['total_pages', 'totalPages', 'last_page', 'lastPage']) ??
          _deriveTotalPages(
              total: resolvedTotalItems, perPage: resolvedPerPage);

      return LeadsListResult(
        items: items,
        currentPage: resolvedCurrentPage,
        perPage: resolvedPerPage,
        totalItems: resolvedTotalItems,
        totalPages: resolvedTotalPages <= 0 ? 1 : resolvedTotalPages,
      );
    } catch (_) {
      throw Exception('My site visits response format is not valid.');
    }
  }

  Future<Map<String, dynamic>> mySummary({String? token}) async {
    final resolvedToken = token ?? _authToken;
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.mySummary}');
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'mySummary',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('mySummary', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to fetch my summary.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Summary response format is not valid.');
      }

      final dynamic data = decoded['data'];
      if (data is Map<String, dynamic>) {
        final dynamic summary = data['summary'];
        if (summary is Map<String, dynamic>) {
          return _stringDynamicMap(summary);
        }
        if (summary is Map) {
          return _stringDynamicMap(summary);
        }
        return _stringDynamicMap(data);
      }

      final dynamic summary = decoded['summary'];
      if (summary is Map<String, dynamic>) {
        return _stringDynamicMap(summary);
      }
      if (summary is Map) {
        return _stringDynamicMap(summary);
      }

      return _stringDynamicMap(decoded);
    } catch (_) {
      throw Exception('Summary response format is not valid.');
    }
  }

  Future<List<Map<String, dynamic>>> myActivities({
    int limit = 8,
    String? token,
  }) async {
    final resolvedToken = token ?? _authToken;
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.myActivities}')
        .replace(queryParameters: <String, String>{
      'limit': limit.toString(),
    });
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'myActivities',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('myActivities', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to fetch my activity feed.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Activities response format is not valid.');
      }

      dynamic activities = decoded['data'];
      if (activities is Map<String, dynamic>) {
        activities = activities['activities'] ??
            activities['items'] ??
            activities['results'] ??
            activities['data'];
      }
      if (activities is! List) {
        return const <Map<String, dynamic>>[];
      }

      return activities
          .whereType<Map>()
          .map((entry) => _stringDynamicMap(entry))
          .toList();
    } catch (_) {
      throw Exception('Activities response format is not valid.');
    }
  }

  Future<LeadsListResult> siteRevisits({
    String? token,
    String? status,
    int page = 1,
    int perPage = 20,
  }) async {
    final resolvedToken = token ?? _authToken;
    final query = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
    if (status != null && status.trim().isNotEmpty) {
      query['status'] = status.trim();
    }

    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.siteRevisits}')
        .replace(queryParameters: query);
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'siteRevisits',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('siteRevisits', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to fetch site re-visits.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic body = jsonDecode(response.body);
      final items = _extractLeadsItems(body);
      final pagination = _extractPaginationMap(body);

      final resolvedCurrentPage = _readIntFromMap(
            pagination,
            ['page', 'current_page', 'currentPage'],
          ) ??
          page;
      final resolvedPerPage = _readIntFromMap(
            pagination,
            ['per_page', 'perPage', 'page_size', 'limit'],
          ) ??
          perPage;
      final resolvedTotalItems = _readIntFromMap(
            pagination,
            ['total', 'total_items', 'totalItems', 'count'],
          ) ??
          items.length;
      final resolvedTotalPages = _readIntFromMap(
            pagination,
            ['total_pages', 'totalPages', 'last_page', 'lastPage'],
          ) ??
          _deriveTotalPages(
              total: resolvedTotalItems, perPage: resolvedPerPage);

      return LeadsListResult(
        items: items,
        currentPage: resolvedCurrentPage,
        perPage: resolvedPerPage,
        totalItems: resolvedTotalItems,
        totalPages: resolvedTotalPages <= 0 ? 1 : resolvedTotalPages,
      );
    } catch (_) {
      throw Exception('Site re-visits response format is not valid.');
    }
  }

  Future<LeadsListResult> myRevisits({
    required String from,
    required String to,
    String? token,
    int page = 1,
    int perPage = 20,
  }) async {
    final resolvedToken = token ?? _authToken;
    final query = <String, String>{
      'from': from.trim(),
      'to': to.trim(),
      'page': page.toString(),
      'per_page': perPage.toString(),
    };

    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.myRevisits}')
        .replace(queryParameters: query);
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'myRevisits',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('myRevisits', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to fetch my re-visits.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic body = jsonDecode(response.body);
      final items = _extractLeadsItems(body);
      final pagination = _extractPaginationMap(body);

      final resolvedCurrentPage = _readIntFromMap(
              pagination, ['page', 'current_page', 'currentPage']) ??
          page;
      final resolvedPerPage = _readIntFromMap(
              pagination, ['per_page', 'perPage', 'page_size', 'limit']) ??
          perPage;
      final resolvedTotalItems = _readIntFromMap(
              pagination, ['total', 'total_items', 'totalItems', 'count']) ??
          items.length;
      final resolvedTotalPages = _readIntFromMap(pagination,
              ['total_pages', 'totalPages', 'last_page', 'lastPage']) ??
          _deriveTotalPages(
              total: resolvedTotalItems, perPage: resolvedPerPage);

      return LeadsListResult(
        items: items,
        currentPage: resolvedCurrentPage,
        perPage: resolvedPerPage,
        totalItems: resolvedTotalItems,
        totalPages: resolvedTotalPages <= 0 ? 1 : resolvedTotalPages,
      );
    } catch (_) {
      throw Exception('My re-visits response format is not valid.');
    }
  }

  Future<LeadsListResult> closures({
    String? token,
    String? status,
    int page = 1,
    int perPage = 20,
  }) async {
    final resolvedToken = token ?? _authToken;
    final queryParameters = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
    if (status != null && status.trim().isNotEmpty) {
      queryParameters['status'] = status.trim();
    }

    final uri =
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.closures}').replace(
      queryParameters: queryParameters,
    );
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'closures',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('closures', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to fetch closures.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic body = jsonDecode(response.body);
      final items = _extractLeadsItems(body);
      final pagination = _extractPaginationMap(body);

      final resolvedCurrentPage = _readIntFromMap(
              pagination, ['page', 'current_page', 'currentPage']) ??
          page;
      final resolvedPerPage = _readIntFromMap(
              pagination, ['per_page', 'perPage', 'page_size', 'limit']) ??
          perPage;
      final resolvedTotalItems = _readIntFromMap(
              pagination, ['total', 'total_items', 'totalItems', 'count']) ??
          items.length;
      final resolvedTotalPages = _readIntFromMap(pagination,
              ['total_pages', 'totalPages', 'last_page', 'lastPage']) ??
          _deriveTotalPages(
              total: resolvedTotalItems, perPage: resolvedPerPage);

      return LeadsListResult(
        items: items,
        currentPage: resolvedCurrentPage,
        perPage: resolvedPerPage,
        totalItems: resolvedTotalItems,
        totalPages: resolvedTotalPages <= 0 ? 1 : resolvedTotalPages,
      );
    } catch (_) {
      throw Exception('Closures response format is not valid.');
    }
  }

  Future<Map<String, dynamic>> siteVisitDetail({
    required String id,
    String? token,
  }) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) {
      throw Exception('Site visit id is required.');
    }

    final resolvedToken = token ?? _authToken;
    final endpoint =
        ApiConstants.sitevisitsdetail.replaceFirst('{id}', normalizedId);
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'siteVisitDetail',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('siteVisitDetail', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to fetch site visit details.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      final data = _extractLeadMap(decoded);
      if (data != null) {
        return data;
      }
    } catch (_) {}

    throw Exception('Site visit details response format is not valid.');
  }

  Future<Map<String, dynamic>> siteRevisitDetail({
    required String id,
    String? token,
  }) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) {
      throw Exception('Re-visit id is required.');
    }

    final resolvedToken = token ?? _authToken;
    final endpoint = '${ApiConstants.siteRevisits}/$normalizedId';
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final headers = _headers(accept: '*/*', token: resolvedToken);
    _logRequest(
      endpoint: 'siteRevisitDetail',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('siteRevisitDetail', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to fetch re-visit details.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      final data = _extractLeadMap(decoded);
      if (data != null) {
        return data;
      }
    } catch (_) {}

    throw Exception('Re-visit details response format is not valid.');
  }

  Future<Map<String, dynamic>> createSiteVisit({
    required String leadId,
    required String projectId,
    required String visitDate,
    required String visitTime,
    required String assignedTo,
    required String notes,
    required bool transportArranged,
    String? token,
  }) async {
    final resolvedToken = token ?? _authToken;
    final uri =
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.createsitevisits}');
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    final body = jsonEncode({
      'lead_id': leadId.trim(),
      'project_id': projectId.trim(),
      'visit_date': visitDate.trim(),
      'visit_time': visitTime.trim(),
      'assigned_to': assignedTo.trim(),
      'notes': notes.trim(),
      'transport_arranged': transportArranged,
    });

    _logRequest(
      endpoint: 'createSiteVisit',
      method: 'POST',
      uri: uri,
      headers: headers,
      body: body,
    );

    final response = await http
        .post(uri, headers: headers, body: body)
        .timeout(_requestTimeout);
    _logResponse('createSiteVisit', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to create site visit.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      final data = _extractLeadMap(decoded);
      if (data != null) {
        return data;
      }
    } catch (_) {}

    return <String, dynamic>{
      'lead_id': leadId.trim(),
      'project_id': projectId.trim(),
      'visit_date': visitDate.trim(),
      'visit_time': visitTime.trim(),
      'assigned_to': assignedTo.trim(),
      'notes': notes.trim(),
      'transport_arranged': transportArranged,
    };
  }

  Future<Map<String, dynamic>> createSiteRevisit({
    required String originalVisitId,
    required String visitDate,
    required String visitTime,
    required String reason,
    required String notes,
    required bool transportArranged,
    String? token,
  }) async {
    final resolvedToken = token ?? _authToken;
    final uri =
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.siteRevisits}');
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    final body = jsonEncode({
      'original_visit_id': originalVisitId.trim(),
      'visit_date': visitDate.trim(),
      'visit_time': visitTime.trim(),
      'reason': reason.trim(),
      'notes': notes.trim(),
      'transport_arranged': transportArranged,
    });

    _logRequest(
      endpoint: 'createSiteRevisit',
      method: 'POST',
      uri: uri,
      headers: headers,
      body: body,
    );

    final response = await http
        .post(uri, headers: headers, body: body)
        .timeout(_requestTimeout);
    _logResponse('createSiteRevisit', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to schedule re-visit.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      final data = _extractLeadMap(decoded);
      if (data != null) {
        return data;
      }
    } catch (_) {}

    return <String, dynamic>{
      'original_visit_id': originalVisitId.trim(),
      'visit_date': visitDate.trim(),
      'visit_time': visitTime.trim(),
      'reason': reason.trim(),
      'notes': notes.trim(),
      'transport_arranged': transportArranged,
    };
  }

  Future<Map<String, dynamic>> createClosure({
    required String leadId,
    required String projectId,
    String? siteVisitId,
    required String bookingDate,
    required String unitNumber,
    required String towerBlock,
    required int floorNumber,
    required String unitType,
    required num carpetAreaSqft,
    required num superAreaSqft,
    required num agreedPrice,
    required num bookingAmount,
    required String paymentPlan,
    required bool loanRequired,
    String? loanBank,
    required num commissionPercent,
    required bool commissionPaid,
    List<String>? closedByManagerIds,
    required String closureNotes,
    String? token,
  }) async {
    final resolvedToken = token ?? _authToken;
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.closures}');
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    final payload = <String, dynamic>{
      'lead_id': leadId.trim(),
      'project_id': projectId.trim(),
      'site_visit_id':
          siteVisitId?.trim().isEmpty ?? true ? null : siteVisitId!.trim(),
      'booking_date': bookingDate.trim(),
      'unit_number': unitNumber.trim(),
      'tower_block': towerBlock.trim(),
      'floor_number': floorNumber,
      'unit_type': unitType.trim(),
      'carpet_area_sqft': carpetAreaSqft,
      'super_area_sqft': superAreaSqft,
      'agreed_price': agreedPrice,
      'booking_amount': bookingAmount,
      'payment_plan': paymentPlan.trim(),
      'loan_required': loanRequired,
      'loan_bank': loanBank?.trim().isEmpty ?? true ? null : loanBank!.trim(),
      'commission_percent': commissionPercent,
      'commission_paid': commissionPaid,
      'closed_by_manager': closedByManagerIds == null ||
              closedByManagerIds.where((id) => id.trim().isNotEmpty).isEmpty
          ? null
          : closedByManagerIds
              .map((id) => id.trim())
              .where((id) => id.isNotEmpty)
              .toList(growable: false),
      'closure_notes': closureNotes.trim(),
    };
    final body = jsonEncode(payload);

    _logRequest(
      endpoint: 'createClosure',
      method: 'POST',
      uri: uri,
      headers: headers,
      body: body,
    );

    final response = await http
        .post(uri, headers: headers, body: body)
        .timeout(_requestTimeout);
    _logResponse('createClosure', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to create closure.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      final data = _extractLeadMap(decoded);
      if (data != null) {
        return data;
      }
    } catch (_) {}

    return payload;
  }

  Future<Map<String, dynamic>> editClosure({
    required String id,
    required String bookingDate,
    required String unitNumber,
    required String towerBlock,
    required int floorNumber,
    required String unitType,
    required num carpetAreaSqft,
    required num superAreaSqft,
    required num agreedPrice,
    required num bookingAmount,
    required String paymentPlan,
    required bool loanRequired,
    String? loanBank,
    required num commissionPercent,
    required bool commissionPaid,
    String? commissionPaidDate,
    List<String>? closedByManagerIds,
    required String closureNotes,
    String? token,
  }) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) {
      throw Exception('Closure id is required.');
    }

    final resolvedToken = token ?? _authToken;
    final endpoint =
        ApiConstants.closuresDetail.replaceFirst('{id}', normalizedId);
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    final payload = <String, dynamic>{
      'booking_date': bookingDate.trim(),
      'unit_number': unitNumber.trim(),
      'tower_block': towerBlock.trim(),
      'floor_number': floorNumber,
      'unit_type': unitType.trim(),
      'carpet_area_sqft': carpetAreaSqft,
      'super_area_sqft': superAreaSqft,
      'agreed_price': agreedPrice,
      'booking_amount': bookingAmount,
      'payment_plan': paymentPlan.trim(),
      'loan_required': loanRequired,
      'loan_bank': loanBank?.trim().isEmpty ?? true ? null : loanBank!.trim(),
      'commission_percent': commissionPercent,
      'commission_paid': commissionPaid,
      'commission_paid_date': commissionPaidDate?.trim().isEmpty ?? true
          ? null
          : commissionPaidDate!.trim(),
      'closed_by_manager': closedByManagerIds == null ||
              closedByManagerIds.where((id) => id.trim().isNotEmpty).isEmpty
          ? null
          : closedByManagerIds
              .map((id) => id.trim())
              .where((id) => id.isNotEmpty)
              .toList(growable: false),
      'closure_notes': closureNotes.trim(),
    };
    final body = jsonEncode(payload);

    _logRequest(
      endpoint: 'editClosure',
      method: 'PUT',
      uri: uri,
      headers: headers,
      body: body,
    );

    final response = await http
        .put(uri, headers: headers, body: body)
        .timeout(_requestTimeout);
    _logResponse('editClosure', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to update closure.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      final data = _extractLeadMap(decoded);
      if (data != null) {
        return data;
      }
    } catch (_) {}

    return <String, dynamic>{
      'id': normalizedId,
      ...payload,
    };
  }

  Future<Map<String, dynamic>> updateClosureStatus({
    required String id,
    required String status,
    String note = '',
    String? token,
  }) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) {
      throw Exception('Closure id is required.');
    }
    final normalizedStatus = status.trim().toLowerCase();
    if (normalizedStatus.isEmpty) {
      throw Exception('Status is required.');
    }

    final resolvedToken = token ?? _authToken;
    final endpoint =
        ApiConstants.closuresStatus.replaceFirst('{id}', normalizedId);
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final headers = _headers(accept: '*/*', token: resolvedToken);
    final body = jsonEncode(<String, dynamic>{
      'status': normalizedStatus,
      'note': note.trim(),
    });

    _logRequest(
      endpoint: 'updateClosureStatus',
      method: 'PATCH',
      uri: uri,
      headers: headers,
      body: body,
    );

    final response = await http
        .patch(uri, headers: headers, body: body)
        .timeout(_requestTimeout);
    _logResponse('updateClosureStatus', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to update closure status.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}

    return <String, dynamic>{
      'id': normalizedId,
      'status': normalizedStatus,
      'note': note.trim(),
    };
  }

  Future<Map<String, dynamic>> closureLeadDetail({
    required String id,
    String? token,
  }) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) {
      throw Exception('Closure lead id is required.');
    }

    final resolvedToken = token ?? _authToken;
    final endpoint =
        ApiConstants.closuresLeadDetail.replaceFirst('{id}', normalizedId);
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final headers = _headers(accept: '*/*', token: resolvedToken);
    _logRequest(
      endpoint: 'closureLeadDetail',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('closureLeadDetail', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to fetch closure detail.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      final data = _extractLeadMap(decoded);
      if (data != null) return data;
    } catch (_) {}

    throw Exception('Closure detail response format is not valid.');
  }

  Future<Map<String, dynamic>> editSiteRevisit({
    required String id,
    String? visitDate,
    String? visitTime,
    String? rescheduleReason,
    String? assignedTo,
    String? reason,
    String? notes,
    bool? transportArranged,
    String? token,
  }) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) {
      throw Exception('Re-visit id is required.');
    }

    final payload = <String, dynamic>{};
    if (visitDate != null && visitDate.trim().isNotEmpty) {
      payload['visit_date'] = visitDate.trim();
    }
    if (visitTime != null && visitTime.trim().isNotEmpty) {
      payload['visit_time'] = visitTime.trim();
    }
    if (rescheduleReason != null && rescheduleReason.trim().isNotEmpty) {
      payload['reschedule_reason'] = rescheduleReason.trim();
    }
    if (assignedTo != null && assignedTo.trim().isNotEmpty) {
      payload['assigned_to'] = assignedTo.trim();
    }
    if (reason != null) {
      payload['reason'] = reason.trim();
    }
    if (notes != null) {
      payload['notes'] = notes.trim();
    }
    if (transportArranged != null) {
      payload['transport_arranged'] = transportArranged;
    }
    if (payload.isEmpty) {
      throw Exception('No fields provided for re-visit update.');
    }

    final resolvedToken = token ?? _authToken;
    final endpoint = '${ApiConstants.siteRevisits}/$normalizedId';
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final headers = _headers(accept: '*/*', token: resolvedToken);
    final body = jsonEncode(payload);

    _logRequest(
      endpoint: 'editSiteRevisit',
      method: 'PUT',
      uri: uri,
      headers: headers,
      body: body,
    );

    final response = await http
        .put(uri, headers: headers, body: body)
        .timeout(_requestTimeout);
    _logResponse('editSiteRevisit', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to update re-visit.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      final data = _extractLeadMap(decoded);
      if (data != null) {
        return data;
      }
    } catch (_) {}

    return <String, dynamic>{
      'id': normalizedId,
      ...payload,
    };
  }

  Future<Map<String, dynamic>> updateSiteRevisitStatus({
    required String id,
    required String status,
    String note = '',
    String? token,
  }) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) {
      throw Exception('Re-visit id is required.');
    }
    final normalizedStatus = status.trim();
    if (normalizedStatus.isEmpty) {
      throw Exception('Status is required.');
    }

    final resolvedToken = token ?? _authToken;
    final endpoint = '${ApiConstants.siteRevisits}/$normalizedId/status';
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final headers = _headers(accept: '*/*', token: resolvedToken);
    final body = jsonEncode({
      'status': normalizedStatus,
      'note': note.trim(),
    });

    _logRequest(
      endpoint: 'updateSiteRevisitStatus',
      method: 'PATCH',
      uri: uri,
      headers: headers,
      body: body,
    );

    final response = await http
        .patch(uri, headers: headers, body: body)
        .timeout(_requestTimeout);
    _logResponse('updateSiteRevisitStatus', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to update re-visit status.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}

    return <String, dynamic>{
      'id': normalizedId,
      'status': normalizedStatus,
      'note': note.trim(),
    };
  }

  Future<Map<String, dynamic>> editSiteVisit({
    required String id,
    String? visitDate,
    String? visitTime,
    String? rescheduleReason,
    String? token,
  }) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) {
      throw Exception('Site visit id is required.');
    }

    final payload = <String, dynamic>{};
    if (visitDate != null && visitDate.trim().isNotEmpty) {
      payload['visit_date'] = visitDate.trim();
    }
    if (visitTime != null && visitTime.trim().isNotEmpty) {
      payload['visit_time'] = visitTime.trim();
    }
    if (rescheduleReason != null) {
      payload['reschedule_reason'] = rescheduleReason.trim();
    }
    if (payload.isEmpty) {
      throw Exception('No fields provided for site visit update.');
    }

    final resolvedToken = token ?? _authToken;
    final endpoint =
        ApiConstants.editsitevisits.replaceFirst('{id}', normalizedId);
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    final body = jsonEncode(payload);

    _logRequest(
      endpoint: 'editSiteVisit',
      method: 'PUT',
      uri: uri,
      headers: headers,
      body: body,
    );

    final response = await http
        .put(uri, headers: headers, body: body)
        .timeout(_requestTimeout);
    _logResponse('editSiteVisit', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to update site visit.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      final data = _extractLeadMap(decoded);
      if (data != null) {
        return data;
      }
    } catch (_) {}

    return <String, dynamic>{'id': normalizedId, ...payload};
  }

  Future<Map<String, dynamic>> updateSiteVisitStatus({
    required String id,
    required String status,
    String? token,
  }) async {
    final normalizedId = id.trim();
    final normalizedStatus = status.trim();
    if (normalizedId.isEmpty) {
      throw Exception('Site visit id is required.');
    }
    if (normalizedStatus.isEmpty) {
      throw Exception('Status is required.');
    }

    final resolvedToken = token ?? _authToken;
    final endpoint =
        ApiConstants.updatestatussitevisits.replaceFirst('{id}', normalizedId);
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    final body = jsonEncode({'status': normalizedStatus});

    _logRequest(
      endpoint: 'updateSiteVisitStatus',
      method: 'PATCH',
      uri: uri,
      headers: headers,
      body: body,
    );

    final response = await http
        .patch(uri, headers: headers, body: body)
        .timeout(_requestTimeout);
    _logResponse('updateSiteVisitStatus', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to update site visit status.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      final data = _extractLeadMap(decoded);
      if (data != null) {
        return data;
      }
    } catch (_) {}

    return <String, dynamic>{'id': normalizedId, 'status': normalizedStatus};
  }

  Future<Map<String, dynamic>> submitSiteVisitFeedback({
    required String id,
    required int rating,
    required String clientReaction,
    required String interestedIn,
    required String nextStep,
    required String remarks,
    String? token,
  }) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) {
      throw Exception('Site visit id is required.');
    }

    final resolvedToken = token ?? _authToken;
    final endpoint = ApiConstants.submitfeedbacksitevisits
        .replaceFirst('{id}', normalizedId);
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final normalizedClientReaction =
        _normalizeFeedbackEnumValue(clientReaction);
    final normalizedNextStep = _normalizeFeedbackEnumValue(nextStep);
    final headers = _headers(accept: '*/*', token: resolvedToken);
    final body = jsonEncode({
      'rating': rating,
      'client_reaction': normalizedClientReaction,
      'interested_in': interestedIn.trim(),
      'next_step': normalizedNextStep,
      'remarks': remarks.trim(),
    });

    _logRequest(
      endpoint: 'submitSiteVisitFeedback',
      method: 'POST',
      uri: uri,
      headers: headers,
      body: body,
    );

    final response = await http
        .post(uri, headers: headers, body: body)
        .timeout(_requestTimeout);
    _logResponse('submitSiteVisitFeedback', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to submit site visit feedback.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      final data = _extractLeadMap(decoded);
      if (data != null) {
        return data;
      }
    } catch (_) {}

    return <String, dynamic>{
      'id': normalizedId,
      'rating': rating,
      'client_reaction': normalizedClientReaction,
      'interested_in': interestedIn.trim(),
      'next_step': normalizedNextStep,
      'remarks': remarks.trim(),
    };
  }

  Future<Map<String, dynamic>> submitSiteRevisitFeedback({
    required String id,
    required int rating,
    required String clientReaction,
    required String interestedIn,
    required String nextStep,
    required String remarks,
    String? token,
  }) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) {
      throw Exception('Site revisit id is required.');
    }

    final resolvedToken = token ?? _authToken;
    final endpoint = ApiConstants.submitfeedbacksiteRevisits
        .replaceFirst('{id}', normalizedId);
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final normalizedClientReaction =
        _normalizeFeedbackEnumValue(clientReaction);
    final normalizedNextStep = _normalizeFeedbackEnumValue(nextStep);
    final headers = _headers(accept: '*/*', token: resolvedToken);
    final body = jsonEncode({
      'rating': rating,
      'client_reaction': normalizedClientReaction,
      'interested_in': interestedIn.trim(),
      'next_step': normalizedNextStep,
      'remarks': remarks.trim(),
    });

    _logRequest(
      endpoint: 'submitSiteRevisitFeedback',
      method: 'POST',
      uri: uri,
      headers: headers,
      body: body,
    );

    final response = await http
        .post(uri, headers: headers, body: body)
        .timeout(_requestTimeout);
    _logResponse('submitSiteRevisitFeedback', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to submit site revisit feedback.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      final data = _extractLeadMap(decoded);
      if (data != null) {
        return data;
      }
    } catch (_) {}

    return <String, dynamic>{
      'id': normalizedId,
      'rating': rating,
      'client_reaction': normalizedClientReaction,
      'interested_in': interestedIn.trim(),
      'next_step': normalizedNextStep,
      'remarks': remarks.trim(),
    };
  }

  String _normalizeFeedbackEnumValue(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('&', 'and')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  Future<void> deleteFollowUp({
    required String id,
    String? token,
  }) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) {
      throw Exception('Follow-up id is required.');
    }

    final resolvedToken = token ?? _authToken;
    final endpoint =
        ApiConstants.deletefollowups.replaceFirst('{id}', normalizedId);
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'deleteFollowUp',
      method: 'DELETE',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.delete(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('deleteFollowUp', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to delete follow-up.',
    );
    if (error != null) {
      throw Exception(error);
    }
  }

  Future<Map<String, dynamic>> leadDetail({
    required String id,
    String? token,
  }) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) {
      throw Exception('Lead id is required.');
    }

    final resolvedToken = token ?? _authToken;
    final endpoint =
        ApiConstants.leadsdetail.replaceFirst('{id}', normalizedId);
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'leadDetail',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('leadDetail', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to fetch lead details.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic body = jsonDecode(response.body);
      final leadMap = _extractLeadMap(body);
      if (leadMap != null) {
        return leadMap;
      }
    } catch (_) {
      // Fall through to generic error below.
    }

    throw Exception('Lead details response format is not valid.');
  }

  Future<List<Map<String, dynamic>>> leadActivity({
    required String id,
    String? token,
  }) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) {
      throw Exception('Lead id is required.');
    }

    final resolvedToken = token ?? _authToken;
    final uri = Uri.parse(
      '${ApiConstants.baseUrl}/leads/$normalizedId/activity',
    );
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'leadActivity',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('leadActivity', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to fetch lead activity.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic body = jsonDecode(response.body);
      return _extractLeadsItems(body);
    } catch (_) {
      throw Exception('Lead activity response format is not valid.');
    }
  }

  Future<List<Map<String, dynamic>>> leadCallRecordings({
    required String id,
    String? token,
  }) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) {
      throw Exception('Lead id is required.');
    }

    final resolvedToken = token ?? _authToken;
    final uri = Uri.parse(
      '${ApiConstants.baseUrl}/leads/$normalizedId/call-recordings',
    );
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'leadCallRecordings',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('leadCallRecordings', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to fetch lead call recordings.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        final data = body['data'];
        if (data is Map<String, dynamic>) {
          final recordings = data['recordings'];
          if (recordings is List) {
            return recordings
                .whereType<Map>()
                .map((item) => item.map(
                      (key, value) => MapEntry(key.toString(), value),
                    ))
                .toList();
          }
        }
      }
      return _extractLeadsItems(body);
    } catch (_) {
      throw Exception('Lead call recordings response format is not valid.');
    }
  }

  Future<Map<String, dynamic>> uploadLeadCallRecording({
    required String id,
    required String filePath,
    String phoneNumber = '',
    String name = '',
    String? token,
  }) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) {
      throw Exception('Lead id is required.');
    }

    final normalizedPath = filePath.trim();
    if (normalizedPath.isEmpty) {
      throw Exception('Select an audio file to upload.');
    }

    final resolvedToken = token ?? _authToken;
    final uri = Uri.parse(
      '${ApiConstants.baseUrl}/leads/$normalizedId/call-recordings',
    );
    final request = http.MultipartRequest('POST', uri);
    request.headers['accept'] = 'application/json';
    if (resolvedToken != null && resolvedToken.trim().isNotEmpty) {
      request.headers['Authorization'] = 'Bearer ${resolvedToken.trim()}';
    }
    if (phoneNumber.trim().isNotEmpty) {
      request.fields['phone_number'] = phoneNumber.trim();
    }
    if (name.trim().isNotEmpty) {
      request.fields['name'] = name.trim();
    }
    request.files.add(
      await http.MultipartFile.fromPath(
        'voice_recording',
        normalizedPath,
        contentType: _audioMediaType(normalizedPath),
      ),
    );

    _logRequest(
      endpoint: 'uploadLeadCallRecording',
      method: 'POST',
      uri: uri,
      headers: request.headers,
      body: 'multipart/form-data',
    );

    http.StreamedResponse streamedResponse;
    try {
      streamedResponse = await request.send().timeout(_requestTimeout);
    } on TimeoutException {
      throw Exception(
        'Server is taking too long to respond. Please try again.',
      );
    }

    final response = await http.Response.fromStream(streamedResponse);
    _logResponse('uploadLeadCallRecording', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to upload call recording.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      final leadMap = _extractLeadMap(decoded);
      if (leadMap != null) {
        return leadMap;
      }
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // Fall through to fallback payload.
    }

    return <String, dynamic>{
      'lead_id': normalizedId,
      'url': normalizedPath,
      'phone_number': phoneNumber.trim(),
      'name': name.trim(),
    };
  }

  Future<Map<String, dynamic>> updateLeadCallRecording({
    required String leadId,
    required String recordingId,
    String name = '',
    String phoneNumber = '',
    String? token,
  }) async {
    final normalizedLeadId = leadId.trim();
    final normalizedRecordingId = recordingId.trim();
    if (normalizedLeadId.isEmpty || normalizedRecordingId.isEmpty) {
      throw Exception('Lead id and recording id are required.');
    }

    final resolvedToken = token ?? _authToken;
    final uri = Uri.parse(
      '${ApiConstants.baseUrl}/leads/$normalizedLeadId/call-recordings/$normalizedRecordingId',
    );
    final headers = _headers(accept: '*/*', token: resolvedToken);
    final body = jsonEncode({
      'name': name.trim(),
      'phone_number': phoneNumber.trim(),
    });

    _logRequest(
      endpoint: 'updateLeadCallRecording',
      method: 'PATCH',
      uri: uri,
      headers: headers,
      body: body,
    );

    final response = await http
        .patch(uri, headers: headers, body: body)
        .timeout(_requestTimeout);
    _logResponse('updateLeadCallRecording', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to update call recording.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      final leadMap = _extractLeadMap(decoded);
      if (leadMap != null) {
        return leadMap;
      }
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // Fall through to fallback payload.
    }

    return <String, dynamic>{
      'id': normalizedRecordingId,
      'lead_id': normalizedLeadId,
      'name': name.trim(),
      'phone_number': phoneNumber.trim(),
    };
  }

  Future<void> deleteLeadCallRecording({
    required String leadId,
    required String recordingId,
    String? token,
  }) async {
    final normalizedLeadId = leadId.trim();
    final normalizedRecordingId = recordingId.trim();
    if (normalizedLeadId.isEmpty || normalizedRecordingId.isEmpty) {
      throw Exception('Lead id and recording id are required.');
    }

    final resolvedToken = token ?? _authToken;
    final uri = Uri.parse(
      '${ApiConstants.baseUrl}/leads/$normalizedLeadId/call-recordings/$normalizedRecordingId',
    );
    final headers = _headers(accept: '*/*', token: resolvedToken);
    _logRequest(
      endpoint: 'deleteLeadCallRecording',
      method: 'DELETE',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.delete(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('deleteLeadCallRecording', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to delete call recording.',
    );
    if (error != null) {
      throw Exception(error);
    }
  }

  Future<LeadsListResult> leadReassignmentHistory({
    required String id,
    String? token,
    int page = 1,
    int perPage = 20,
  }) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) {
      throw Exception('Lead id is required.');
    }

    final resolvedToken = token ?? _authToken;
    final uri = Uri.parse(
      '${ApiConstants.baseUrl}/leads/$normalizedId/reassignment-history',
    ).replace(
      queryParameters: <String, String>{
        'page': page.toString(),
        'per_page': perPage.toString(),
      },
    );
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'leadReassignmentHistory',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('leadReassignmentHistory', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to fetch lead reassignment history.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic body = jsonDecode(response.body);
      final items = _extractLeadsItems(body);
      final pagination = _extractPaginationMap(body);

      final resolvedCurrentPage = _readIntFromMap(
              pagination, ['page', 'current_page', 'currentPage']) ??
          page;
      final resolvedPerPage = _readIntFromMap(
            pagination,
            ['per_page', 'perPage', 'page_size', 'limit'],
          ) ??
          perPage;
      final resolvedTotalItems = _readIntFromMap(
            pagination,
            ['total', 'total_items', 'totalItems', 'count'],
          ) ??
          items.length;
      final resolvedTotalPages = _readIntFromMap(
            pagination,
            ['total_pages', 'totalPages', 'last_page', 'lastPage'],
          ) ??
          _deriveTotalPages(
            total: resolvedTotalItems,
            perPage: resolvedPerPage,
          );

      return LeadsListResult(
        items: items,
        currentPage: resolvedCurrentPage,
        perPage: resolvedPerPage,
        totalItems: resolvedTotalItems,
        totalPages: resolvedTotalPages <= 0 ? 1 : resolvedTotalPages,
      );
    } catch (_) {
      throw Exception(
          'Lead reassignment history response format is not valid.');
    }
  }

  Future<Map<String, dynamic>> createLead({
    required String name,
    required String phone,
    String alternatePhoneNumber = '',
    required String email,
    required String source,
    String callbackTime = '',
    String nextFollowUpTime = '',
    required String assignedTo,
    String projectId = '',
    required String budget,
    required String locationPreference,
    required String notes,
    String? token,
  }) async {
    final resolvedToken = token ?? _authToken;
    final uri =
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.createsleads}');
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    final body = jsonEncode({
      'name': name.trim(),
      'phone': phone.trim(),
      'alternate_phone_number': alternatePhoneNumber.trim(),
      'email': email.trim(),
      'source': source.trim(),
      'callback_time': callbackTime.trim(),
      'next_followup_time': nextFollowUpTime.trim(),
      'assigned_to': assignedTo.trim(),
      'project_id': projectId.trim(),
      'budget': budget.trim(),
      'location_preference': locationPreference.trim(),
      'notes': notes.trim(),
    });

    _logRequest(
      endpoint: 'createLead',
      method: 'POST',
      uri: uri,
      headers: headers,
      body: body,
    );

    final response = await http
        .post(uri, headers: headers, body: body)
        .timeout(_requestTimeout);
    _logResponse('createLead', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to create lead.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      final leadMap = _extractLeadMap(decoded);
      if (leadMap != null) {
        return leadMap;
      }
    } catch (_) {
      // Fall through and return submitted payload as a fallback.
    }

    return <String, dynamic>{
      'name': name.trim(),
      'phone': phone.trim(),
      'alternate_phone_number': alternatePhoneNumber.trim(),
      'email': email.trim(),
      'source': source.trim(),
      'callback_time': callbackTime.trim(),
      'next_followup_time': nextFollowUpTime.trim(),
      'assigned_to': assignedTo.trim(),
      'project_id': projectId.trim(),
      'budget': budget.trim(),
      'location_preference': locationPreference.trim(),
      'notes': notes.trim(),
    };
  }

  Future<Map<String, dynamic>> editLead({
    required String id,
    required String phone,
    String source = '',
    String callbackTime = '',
    String nextFollowUpTime = '',
    String assignedTo = '',
    String projectId = '',
    required String budget,
    required String locationPreference,
    String? token,
  }) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) {
      throw Exception('Lead id is required.');
    }

    final resolvedToken = token ?? _authToken;
    final endpoint = ApiConstants.editleads.replaceFirst('{id}', normalizedId);
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    final body = jsonEncode({
      'phone': phone.trim(),
      'source': source.trim(),
      'callback_time': callbackTime.trim(),
      'next_followup_time': nextFollowUpTime.trim(),
      'assigned_to': assignedTo.trim(),
      'project_id': projectId.trim(),
      'budget': budget.trim(),
      'location_preference': locationPreference.trim(),
    });

    _logRequest(
      endpoint: 'editLead',
      method: 'PUT',
      uri: uri,
      headers: headers,
      body: body,
    );

    var response = await http
        .put(uri, headers: headers, body: body)
        .timeout(_requestTimeout);
    _logResponse('editLead', response);

    if (response.statusCode == 404 || response.statusCode == 405) {
      _logRequest(
        endpoint: 'editLead',
        method: 'PATCH',
        uri: uri,
        headers: headers,
        body: body,
      );
      response = await http
          .patch(uri, headers: headers, body: body)
          .timeout(_requestTimeout);
      _logResponse('editLead', response);
    }

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to update lead.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      final leadMap = _extractLeadMap(decoded);
      if (leadMap != null) {
        return leadMap;
      }
    } catch (_) {
      // Fall through and return submitted payload as a fallback.
    }

    return <String, dynamic>{
      'id': normalizedId,
      'phone': phone.trim(),
      'callback_time': callbackTime.trim(),
      'next_followup_time': nextFollowUpTime.trim(),
      'budget': budget.trim(),
      'location_preference': locationPreference.trim(),
    };
  }

  Future<Map<String, dynamic>> updateLeadStatus({
    required String id,
    required String status,
    String note = '',
    String? token,
  }) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) {
      throw Exception('Lead id is required.');
    }

    final normalizedStatus = status.trim();
    if (normalizedStatus.isEmpty) {
      throw Exception('Status is required.');
    }

    final resolvedToken = token ?? _authToken;
    final endpoint =
        ApiConstants.updatestatusleads.replaceFirst('{id}', normalizedId);
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    final body = jsonEncode({
      'status': normalizedStatus,
      'note': note.trim(),
    });

    _logRequest(
      endpoint: 'updateLeadStatus',
      method: 'PATCH',
      uri: uri,
      headers: headers,
      body: body,
    );

    final response = await http
        .patch(uri, headers: headers, body: body)
        .timeout(_requestTimeout);
    _logResponse('updateLeadStatus', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to update lead status.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      final leadMap = _extractLeadMap(decoded);
      if (leadMap != null) {
        return leadMap;
      }
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // Fall through to fallback payload.
    }

    return <String, dynamic>{
      'id': normalizedId,
      'status': normalizedStatus,
      'note': note.trim(),
    };
  }

  Future<Map<String, dynamic>> reassignLead({
    required String id,
    required String assignedTo,
    String note = '',
    String? token,
  }) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) {
      throw Exception('Lead id is required.');
    }

    final normalizedAssignee = assignedTo.trim();
    if (normalizedAssignee.isEmpty) {
      throw Exception('Assigned user id is required.');
    }

    final resolvedToken = token ?? _authToken;
    final endpoint =
        ApiConstants.reassignmemberleads.replaceFirst('{id}', normalizedId);
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    final body = jsonEncode({
      'assigned_to': normalizedAssignee,
      'note': note.trim(),
    });

    _logRequest(
      endpoint: 'reassignLead',
      method: 'PATCH',
      uri: uri,
      headers: headers,
      body: body,
    );

    final response = await http
        .patch(uri, headers: headers, body: body)
        .timeout(_requestTimeout);
    _logResponse('reassignLead', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to reassign lead.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      final leadMap = _extractLeadMap(decoded);
      if (leadMap != null) {
        return leadMap;
      }
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // Fall through to fallback payload.
    }

    return <String, dynamic>{
      'id': normalizedId,
      'assigned_to': normalizedAssignee,
      'note': note.trim(),
    };
  }

  Future<Map<String, dynamic>> usersDetail({
    required String id,
    String? token,
  }) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) {
      throw Exception('User id is required.');
    }

    final resolvedToken = token ?? _authToken;
    final endpoint =
        ApiConstants.usersdetail.replaceFirst('{id}', normalizedId);
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'usersDetail',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('usersDetail', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to fetch user details.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        final dynamic data = body['data'];
        if (data is Map<String, dynamic>) {
          return data;
        }
        return body;
      }
    } catch (_) {
      // Fall through to generic error below.
    }

    throw Exception('User details response format is not valid.');
  }

  Future<Map<String, dynamic>> userPerformance({
    required String id,
    required String from,
    required String to,
    String? token,
  }) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) {
      throw Exception('User id is required.');
    }

    final normalizedFrom = from.trim();
    final normalizedTo = to.trim();
    if (normalizedFrom.isEmpty || normalizedTo.isEmpty) {
      throw Exception('From and to date are required.');
    }

    final resolvedToken = token ?? _authToken;
    final endpoint =
        ApiConstants.userPerformance.replaceFirst('{id}', normalizedId);
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint').replace(
      queryParameters: <String, String>{
        'from': normalizedFrom,
        'to': normalizedTo,
      },
    );
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'userPerformance',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('userPerformance', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to fetch user performance.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        final data = body['data'];
        if (data is Map<String, dynamic>) {
          return data;
        }
        return body;
      }
    } catch (_) {
      // Fall through to generic parsing error below.
    }

    throw Exception('User performance response format is not valid.');
  }

  Future<LeadsListResult> teamHistoryLeads({
    required String userId,
    int page = 1,
    int perPage = 20,
    String? token,
  }) {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      throw Exception('User id is required.');
    }
    final endpoint = ApiConstants.teamHistoryLeads
        .replaceFirst('{userId}', normalizedUserId);
    return _teamHistoryList(
      endpointName: 'teamHistoryLeads',
      endpointPath: endpoint,
      fallbackMessage: 'Unable to fetch team history leads.',
      token: token,
      page: page,
      perPage: perPage,
    );
  }

  Future<LeadsListResult> teamHistoryFollowUps({
    required String userId,
    bool? isCompleted,
    String? priority,
    String? from,
    String? to,
    int page = 1,
    int perPage = 20,
    String? token,
  }) {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      throw Exception('User id is required.');
    }
    final endpoint = ApiConstants.teamHistoryFollowUps
        .replaceFirst('{userId}', normalizedUserId);
    final query = <String, String>{};
    if (isCompleted != null) {
      query['is_completed'] = isCompleted.toString();
    }
    if (priority != null && priority.trim().isNotEmpty) {
      query['priority'] = priority.trim();
    }
    if (from != null && from.trim().isNotEmpty) {
      query['from'] = from.trim();
    }
    if (to != null && to.trim().isNotEmpty) {
      query['to'] = to.trim();
    }
    return _teamHistoryList(
      endpointName: 'teamHistoryFollowUps',
      endpointPath: endpoint,
      fallbackMessage: 'Unable to fetch team history follow-ups.',
      token: token,
      page: page,
      perPage: perPage,
      query: query,
    );
  }

  Future<LeadsListResult> teamHistorySiteVisits({
    required String userId,
    String? status,
    String? from,
    String? to,
    int page = 1,
    int perPage = 20,
    String? token,
  }) {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      throw Exception('User id is required.');
    }
    final endpoint = ApiConstants.teamHistorySiteVisits
        .replaceFirst('{userId}', normalizedUserId);
    final query = <String, String>{};
    if (status != null && status.trim().isNotEmpty) {
      query['status'] = status.trim();
    }
    if (from != null && from.trim().isNotEmpty) {
      query['from'] = from.trim();
    }
    if (to != null && to.trim().isNotEmpty) {
      query['to'] = to.trim();
    }
    return _teamHistoryList(
      endpointName: 'teamHistorySiteVisits',
      endpointPath: endpoint,
      fallbackMessage: 'Unable to fetch team history site visits.',
      token: token,
      page: page,
      perPage: perPage,
      query: query,
    );
  }

  Future<void> deleteUser({
    required String id,
    String? token,
  }) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) {
      throw Exception('User id is required.');
    }

    final resolvedToken = token ?? _authToken;
    final endpoint = ApiConstants.deleteuser.replaceFirst('{id}', normalizedId);
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'deleteUser',
      method: 'DELETE',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.delete(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('deleteUser', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to delete user.',
    );
    if (error != null) {
      throw Exception(error);
    }
  }

  Future<void> editUser({
    required String id,
    required String firstName,
    required String lastName,
    required String phoneNumber,
    String? token,
  }) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) {
      throw Exception('User id is required.');
    }

    final resolvedToken = token ?? _authToken;
    final endpoint = ApiConstants.edituser.replaceFirst('{id}', normalizedId);
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    final body = jsonEncode({
      'first_name': firstName.trim(),
      'last_name': lastName.trim(),
      'phone_number': phoneNumber.trim(),
    });

    _logRequest(
      endpoint: 'editUser',
      method: 'PUT',
      uri: uri,
      headers: headers,
      body: body,
    );

    final response = await http
        .put(uri, headers: headers, body: body)
        .timeout(_requestTimeout);
    _logResponse('editUser', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to update user.',
    );
    if (error != null) {
      throw Exception(error);
    }
  }

  Future<void> editUserRole({
    required String id,
    required String role,
    String? token,
  }) async {
    final normalizedId = id.trim();
    final normalizedRole = role.trim();

    if (normalizedId.isEmpty) {
      throw Exception('User id is required.');
    }
    if (normalizedRole.isEmpty) {
      throw Exception('Role is required.');
    }

    final resolvedToken = token ?? _authToken;
    final endpoint =
        ApiConstants.edituserrole.replaceFirst('{id}', normalizedId);
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    final body = jsonEncode({'role': normalizedRole});

    _logRequest(
      endpoint: 'editUserRole',
      method: 'PATCH',
      uri: uri,
      headers: headers,
      body: body,
    );

    final response = await http
        .patch(uri, headers: headers, body: body)
        .timeout(_requestTimeout);
    _logResponse('editUserRole', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to change user role.',
    );
    if (error != null) {
      throw Exception(error);
    }
  }

  Future<LeadsListResult> projects({
    String? token,
    String? city,
    String? status,
    String? search,
    int page = 1,
    int perPage = 20,
  }) async {
    final resolvedToken = token ?? _authToken;
    final query = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
    if (city != null && city.trim().isNotEmpty) {
      query['city'] = city.trim();
    }
    if (status != null && status.trim().isNotEmpty) {
      query['status'] = status.trim();
    }
    if (search != null && search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }

    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.projects}')
        .replace(queryParameters: query);
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'projects',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('projects', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to fetch projects.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic body = jsonDecode(response.body);
      final items = _extractLeadsItems(body);
      final pagination = _extractPaginationMap(body);

      final resolvedCurrentPage = _readIntFromMap(
              pagination, ['page', 'current_page', 'currentPage']) ??
          page;
      final resolvedPerPage = _readIntFromMap(
              pagination, ['per_page', 'perPage', 'page_size', 'limit']) ??
          perPage;
      final resolvedTotalItems = _readIntFromMap(
              pagination, ['total', 'total_items', 'totalItems', 'count']) ??
          items.length;
      final resolvedTotalPages = _readIntFromMap(pagination,
              ['total_pages', 'totalPages', 'last_page', 'lastPage']) ??
          _deriveTotalPages(
              total: resolvedTotalItems, perPage: resolvedPerPage);

      return LeadsListResult(
        items: items,
        currentPage: resolvedCurrentPage,
        perPage: resolvedPerPage,
        totalItems: resolvedTotalItems,
        totalPages: resolvedTotalPages <= 0 ? 1 : resolvedTotalPages,
      );
    } catch (_) {
      throw Exception('Projects response format is not valid.');
    }
  }

  Future<Map<String, dynamic>> createProject({
    required String name,
    required String developer,
    required String city,
    required String locality,
    required String address,
    required List<String> configurations,
    required String priceRange,
    required int totalUnits,
    required String possessionDate,
    required String reraNumber,
    required List<String> amenities,
    required String status,
    required String description,
    List<String> unitPlanFilePaths = const <String>[],
    List<String> creativeFilePaths = const <String>[],
    List<String> paymentPlanFilePaths = const <String>[],
    List<String> videoFilePaths = const <String>[],
    String brochureUrl = '',
    String videoUrl = '',
    String paymentPlanUrl = '',
    String homeLoanInfo = '',
    String? token,
  }) async {
    final resolvedToken = token ?? _authToken;
    final uri =
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.createprojects}');
    final request = http.MultipartRequest('POST', uri);
    request.headers['accept'] = 'application/json';
    if (resolvedToken != null && resolvedToken.trim().isNotEmpty) {
      request.headers['Authorization'] = 'Bearer ${resolvedToken.trim()}';
    }
    _addProjectFields(
      request,
      name: name,
      developer: developer,
      city: city,
      locality: locality,
      address: address,
      configurations: configurations,
      priceRange: priceRange,
      totalUnits: totalUnits,
      possessionDate: possessionDate,
      reraNumber: reraNumber,
      amenities: amenities,
      status: status,
      description: description,
      brochureUrl: brochureUrl,
      videoUrl: videoUrl,
      paymentPlanUrl: paymentPlanUrl,
      homeLoanInfo: homeLoanInfo,
    );
    await _addProjectFiles(
      request,
      fieldName: 'unit_plans',
      filePaths: unitPlanFilePaths,
    );
    await _addProjectFiles(
      request,
      fieldName: 'creatives',
      filePaths: creativeFilePaths,
    );
    await _addProjectFiles(
      request,
      fieldName: 'payment_plans',
      filePaths: paymentPlanFilePaths,
    );
    await _addProjectFiles(
      request,
      fieldName: 'videos',
      filePaths: videoFilePaths,
    );

    _logRequest(
      endpoint: 'createProject',
      method: 'POST',
      uri: uri,
      headers: request.headers,
      body: 'multipart/form-data',
    );

    final streamedResponse = await request.send().timeout(_requestTimeout);
    final response = await http.Response.fromStream(streamedResponse);
    _logResponse('createProject', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to create project.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      final projectMap = _extractLeadMap(decoded);
      if (projectMap != null) {
        return projectMap;
      }
    } catch (_) {}

    return <String, dynamic>{
      'name': name.trim(),
      'developer': developer.trim(),
      'city': city.trim(),
      'locality': locality.trim(),
      'address': address.trim(),
      'configurations': configurations,
      'price_range': priceRange.trim(),
      'total_units': totalUnits,
      'possession_date': possessionDate.trim(),
      'rera_number': reraNumber.trim(),
      'amenities': amenities,
      'status': status.trim(),
      'description': description.trim(),
      'brochure_url': brochureUrl.trim(),
      'video_url': videoUrl.trim(),
      'payment_plan_url': paymentPlanUrl.trim(),
      'home_loan_info': homeLoanInfo.trim(),
    };
  }

  void _addProjectFields(
    http.MultipartRequest request, {
    required String name,
    required String developer,
    required String city,
    required String locality,
    required String address,
    required List<String> configurations,
    required String priceRange,
    required int totalUnits,
    required String possessionDate,
    required String reraNumber,
    required List<String> amenities,
    required String status,
    required String description,
    required String brochureUrl,
    required String videoUrl,
    required String paymentPlanUrl,
    required String homeLoanInfo,
  }) {
    request.fields.addAll({
      'name': name.trim(),
      'developer': developer.trim(),
      'city': city.trim(),
      'locality': locality.trim(),
      'address': address.trim(),
      'price_range': priceRange.trim(),
      'total_units': totalUnits.toString(),
      'possession_date': possessionDate.trim(),
      'rera_number': reraNumber.trim(),
      'status': status.trim(),
      'description': description.trim(),
      'brochure_url': brochureUrl.trim(),
      'video_url': videoUrl.trim(),
      'payment_plan_url': paymentPlanUrl.trim(),
      'home_loan_info': homeLoanInfo.trim(),
    });

    for (final configuration in configurations) {
      final value = configuration.trim();
      if (value.isNotEmpty) {
        request.fields['configurations'] = [
          request.fields['configurations'],
          value,
        ].whereType<String>().join(',');
      }
    }
    for (final amenity in amenities) {
      final value = amenity.trim();
      if (value.isNotEmpty) {
        request.fields['amenities'] = [
          request.fields['amenities'],
          value,
        ].whereType<String>().join(',');
      }
    }
  }

  Future<void> _addProjectFiles(
    http.MultipartRequest request, {
    required String fieldName,
    required List<String> filePaths,
  }) async {
    for (final path in filePaths) {
      final normalizedPath = path.trim();
      if (normalizedPath.isEmpty) {
        continue;
      }
      request.files.add(
        await http.MultipartFile.fromPath(
          fieldName,
          normalizedPath,
          contentType: _documentMediaType(normalizedPath),
        ),
      );
    }
  }

  Future<Map<String, dynamic>> projectDetail({
    required String id,
    String? token,
  }) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) {
      throw Exception('Project id is required.');
    }

    final resolvedToken = token ?? _authToken;
    final endpoint =
        ApiConstants.projectsdetail.replaceFirst('{id}', normalizedId);
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'projectDetail',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('projectDetail', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to fetch project details.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      final projectMap = _extractLeadMap(decoded);
      if (projectMap != null) {
        return projectMap;
      }
    } catch (_) {}

    throw Exception('Project details response format is not valid.');
  }

  Future<Map<String, dynamic>> projectDocuments({
    required String id,
    String? token,
  }) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) {
      throw Exception('Project id is required.');
    }

    final resolvedToken = token ?? _authToken;
    final endpoint =
        ApiConstants.projectDocuments.replaceFirst('{id}', normalizedId);
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'projectDocuments',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('projectDocuments', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to fetch project documents.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}

    throw Exception('Project documents response format is not valid.');
  }

  Future<LeadsListResult> projectLeads({
    required String id,
    String? token,
    String? search,
    int page = 1,
    int perPage = 20,
  }) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) {
      throw Exception('Project id is required.');
    }

    final resolvedToken = token ?? _authToken;
    final endpoint =
        ApiConstants.projectLeads.replaceFirst('{id}', normalizedId);
    final query = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
    if (search != null && search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }

    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint')
        .replace(queryParameters: query);
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'projectLeads',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('projectLeads', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to fetch project leads.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic body = jsonDecode(response.body);
      final items = _extractLeadsItems(body);
      final pagination = _extractPaginationMap(body);

      final resolvedCurrentPage = _readIntFromMap(
              pagination, ['page', 'current_page', 'currentPage']) ??
          page;
      final resolvedPerPage = _readIntFromMap(
              pagination, ['per_page', 'perPage', 'page_size', 'limit']) ??
          perPage;
      final resolvedTotalItems = _readIntFromMap(
              pagination, ['total', 'total_items', 'totalItems', 'count']) ??
          items.length;
      final resolvedTotalPages = _readIntFromMap(pagination,
              ['total_pages', 'totalPages', 'last_page', 'lastPage']) ??
          _deriveTotalPages(
              total: resolvedTotalItems, perPage: resolvedPerPage);

      return LeadsListResult(
        items: items,
        currentPage: resolvedCurrentPage,
        perPage: resolvedPerPage,
        totalItems: resolvedTotalItems,
        totalPages: resolvedTotalPages <= 0 ? 1 : resolvedTotalPages,
      );
    } catch (_) {
      throw Exception('Project leads response format is not valid.');
    }
  }

  Future<Map<String, dynamic>> shareProject({
    required String id,
    required List<String> emails,
    String? message,
    List<String> fields = const <String>[],
    List<String> documentIds = const <String>[],
    String? token,
  }) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) {
      throw Exception('Project id is required.');
    }
    final normalizedEmails = emails
        .map((email) => email.trim())
        .where((email) => email.isNotEmpty)
        .toList();
    final normalizedFields = fields
        .map((field) => field.trim())
        .where((field) => field.isNotEmpty)
        .toList();
    final normalizedDocumentIds = documentIds
        .map((documentId) => documentId.trim())
        .where((documentId) => documentId.isNotEmpty)
        .toList();
    if (normalizedEmails.isEmpty) {
      throw Exception('At least one email is required.');
    }

    final resolvedToken = token ?? _authToken;
    final endpoint =
        ApiConstants.projectShare.replaceFirst('{id}', normalizedId);
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final headers = _headers(
      accept: 'application/json',
      token: resolvedToken,
    );
    final bodyMap = <String, dynamic>{
      'emails': normalizedEmails,
      'message': (message ?? '').trim(),
      'fields': normalizedFields,
      'document_ids': normalizedDocumentIds,
    };
    final body = jsonEncode(bodyMap);
    _logRequest(
      endpoint: 'shareProject',
      method: 'POST',
      uri: uri,
      headers: headers,
      body: body,
    );

    final response = await http
        .post(uri, headers: headers, body: body)
        .timeout(_requestTimeout);
    _logResponse('shareProject', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to share project.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}

    throw Exception('Share project response format is not valid.');
  }

  Future<Map<String, dynamic>> uploadProjectDocuments({
    required String id,
    List<String> unitPlanFilePaths = const <String>[],
    List<String> creativeFilePaths = const <String>[],
    List<String> paymentPlanFilePaths = const <String>[],
    List<String> videoFilePaths = const <String>[],
    String? token,
  }) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) {
      throw Exception('Project id is required.');
    }
    if (unitPlanFilePaths.isEmpty &&
        creativeFilePaths.isEmpty &&
        paymentPlanFilePaths.isEmpty &&
        videoFilePaths.isEmpty) {
      throw Exception('Select at least one document to upload.');
    }

    final resolvedToken = token ?? _authToken;
    final endpoint =
        ApiConstants.projectDocuments.replaceFirst('{id}', normalizedId);
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final request = http.MultipartRequest('POST', uri);
    request.headers['accept'] = 'application/json';
    if (resolvedToken != null && resolvedToken.trim().isNotEmpty) {
      request.headers['Authorization'] = 'Bearer ${resolvedToken.trim()}';
    }
    await _addProjectFiles(
      request,
      fieldName: 'unit_plans',
      filePaths: unitPlanFilePaths,
    );
    await _addProjectFiles(
      request,
      fieldName: 'creatives',
      filePaths: creativeFilePaths,
    );
    await _addProjectFiles(
      request,
      fieldName: 'payment_plans',
      filePaths: paymentPlanFilePaths,
    );
    await _addProjectFiles(
      request,
      fieldName: 'videos',
      filePaths: videoFilePaths,
    );

    _logRequest(
      endpoint: 'uploadProjectDocuments',
      method: 'POST',
      uri: uri,
      headers: request.headers,
      body: 'multipart/form-data',
    );

    final streamedResponse = await request.send().timeout(_requestTimeout);
    final response = await http.Response.fromStream(streamedResponse);
    _logResponse('uploadProjectDocuments', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to upload project documents.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}

    return <String, dynamic>{'id': normalizedId};
  }

  Future<ExportFileResult> downloadAllProjectDocuments({
    required String id,
    String? token,
  }) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) {
      throw Exception('Project id is required.');
    }

    final resolvedToken = token ?? _authToken;
    final endpoint = ApiConstants.projectDocumentsDownloadAll
        .replaceFirst('{id}', normalizedId);
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final headers = _headers(accept: 'application/zip', token: resolvedToken);
    _logRequest(
      endpoint: 'downloadAllProjectDocuments',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('downloadAllProjectDocuments', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to download project documents.',
    );
    if (error != null) {
      throw Exception(error);
    }

    final disposition = response.headers['content-disposition'] ?? '';
    final fileName = _readFileNameFromDisposition(disposition) ??
        'project_${normalizedId}_documents.zip';
    final contentTypeHeader = response.headers['content-type'] ?? '';
    return ExportFileResult(
      fileName: fileName,
      bytes: response.bodyBytes,
      contentType: contentTypeHeader.trim().isEmpty
          ? 'application/zip'
          : contentTypeHeader,
    );
  }

  Future<ExportFileResult> downloadAllProjectPaymentPlans({
    required String id,
    String? token,
  }) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) {
      throw Exception('Project id is required.');
    }

    final resolvedToken = token ?? _authToken;
    final endpoint = ApiConstants.projectPaymentPlansDownloadAll
        .replaceFirst('{id}', normalizedId);
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final headers = _headers(accept: 'application/zip', token: resolvedToken);
    _logRequest(
      endpoint: 'downloadAllProjectPaymentPlans',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('downloadAllProjectPaymentPlans', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to download project payment plans.',
    );
    if (error != null) {
      throw Exception(error);
    }

    final disposition = response.headers['content-disposition'] ?? '';
    final fileName = _readFileNameFromDisposition(disposition) ??
        'project_${normalizedId}_payment_plans.zip';
    final contentTypeHeader = response.headers['content-type'] ?? '';
    return ExportFileResult(
      fileName: fileName,
      bytes: response.bodyBytes,
      contentType: contentTypeHeader.trim().isEmpty
          ? 'application/zip'
          : contentTypeHeader,
    );
  }

  Future<ExportFileResult> downloadAllProjectVideos({
    required String id,
    String? token,
  }) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) {
      throw Exception('Project id is required.');
    }

    final resolvedToken = token ?? _authToken;
    final endpoint = ApiConstants.projectVideosDownloadAll
        .replaceFirst('{id}', normalizedId);
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final headers = _headers(accept: 'application/zip', token: resolvedToken);
    _logRequest(
      endpoint: 'downloadAllProjectVideos',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('downloadAllProjectVideos', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to download project videos.',
    );
    if (error != null) {
      throw Exception(error);
    }

    final disposition = response.headers['content-disposition'] ?? '';
    final fileName = _readFileNameFromDisposition(disposition) ??
        'project_${normalizedId}_videos.zip';
    final contentTypeHeader = response.headers['content-type'] ?? '';
    return ExportFileResult(
      fileName: fileName,
      bytes: response.bodyBytes,
      contentType: contentTypeHeader.trim().isEmpty
          ? 'application/zip'
          : contentTypeHeader,
    );
  }

  Future<ExportFileResult> downloadProjectDocument({
    required String projectId,
    required String documentId,
    String? token,
  }) async {
    final normalizedProjectId = projectId.trim();
    final normalizedDocumentId = documentId.trim();
    if (normalizedProjectId.isEmpty) {
      throw Exception('Project id is required.');
    }
    if (normalizedDocumentId.isEmpty) {
      throw Exception('Document id is required.');
    }

    final resolvedToken = token ?? _authToken;
    final endpoint = ApiConstants.projectDocumentDownload
        .replaceFirst('{id}', normalizedProjectId)
        .replaceFirst('{docId}', normalizedDocumentId);
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final headers = _headers(accept: '*/*', token: resolvedToken);
    _logRequest(
      endpoint: 'downloadProjectDocument',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('downloadProjectDocument', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to download project document.',
    );
    if (error != null) {
      throw Exception(error);
    }

    final disposition = response.headers['content-disposition'] ?? '';
    final fileName = _readFileNameFromDisposition(disposition) ??
        'project_document_$normalizedDocumentId';
    final contentTypeHeader = response.headers['content-type'] ?? '';
    return ExportFileResult(
      fileName: fileName,
      bytes: response.bodyBytes,
      contentType: contentTypeHeader.trim().isEmpty
          ? 'application/octet-stream'
          : contentTypeHeader,
    );
  }

  Future<void> deleteProjectDocument({
    required String projectId,
    required String documentId,
    String? token,
  }) async {
    final normalizedProjectId = projectId.trim();
    final normalizedDocumentId = documentId.trim();
    if (normalizedProjectId.isEmpty) {
      throw Exception('Project id is required.');
    }
    if (normalizedDocumentId.isEmpty) {
      throw Exception('Document id is required.');
    }

    final resolvedToken = token ?? _authToken;
    final endpoint = ApiConstants.projectDocumentDelete
        .replaceFirst('{id}', normalizedProjectId)
        .replaceFirst('{docId}', normalizedDocumentId);
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'deleteProjectDocument',
      method: 'DELETE',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.delete(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('deleteProjectDocument', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to delete project document.',
    );
    if (error != null) {
      throw Exception(error);
    }
  }

  Future<Map<String, dynamic>> editProject({
    required String id,
    required String name,
    required String developer,
    required String city,
    required String locality,
    required String address,
    required List<String> configurations,
    required String priceRange,
    required int totalUnits,
    required String possessionDate,
    required String reraNumber,
    required List<String> amenities,
    required String status,
    required String description,
    List<String> unitPlanFilePaths = const <String>[],
    List<String> creativeFilePaths = const <String>[],
    List<String> paymentPlanFilePaths = const <String>[],
    List<String> videoFilePaths = const <String>[],
    String brochureUrl = '',
    String videoUrl = '',
    String paymentPlanUrl = '',
    String homeLoanInfo = '',
    String? token,
  }) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) {
      throw Exception('Project id is required.');
    }

    final resolvedToken = token ?? _authToken;
    final endpoint =
        ApiConstants.editprojects.replaceFirst('{id}', normalizedId);
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final request = http.MultipartRequest('PUT', uri);
    request.headers['accept'] = 'application/json';
    if (resolvedToken != null && resolvedToken.trim().isNotEmpty) {
      request.headers['Authorization'] = 'Bearer ${resolvedToken.trim()}';
    }
    _addProjectFields(
      request,
      name: name,
      developer: developer,
      city: city,
      locality: locality,
      address: address,
      configurations: configurations,
      priceRange: priceRange,
      totalUnits: totalUnits,
      possessionDate: possessionDate,
      reraNumber: reraNumber,
      amenities: amenities,
      status: status,
      description: description,
      brochureUrl: brochureUrl,
      videoUrl: videoUrl,
      paymentPlanUrl: paymentPlanUrl,
      homeLoanInfo: homeLoanInfo,
    );
    await _addProjectFiles(
      request,
      fieldName: 'unit_plans',
      filePaths: unitPlanFilePaths,
    );
    await _addProjectFiles(
      request,
      fieldName: 'creatives',
      filePaths: creativeFilePaths,
    );
    await _addProjectFiles(
      request,
      fieldName: 'payment_plans',
      filePaths: paymentPlanFilePaths,
    );
    await _addProjectFiles(
      request,
      fieldName: 'videos',
      filePaths: videoFilePaths,
    );

    _logRequest(
      endpoint: 'editProject',
      method: 'PUT',
      uri: uri,
      headers: request.headers,
      body: 'multipart/form-data',
    );

    final streamedResponse = await request.send().timeout(_requestTimeout);
    final response = await http.Response.fromStream(streamedResponse);
    _logResponse('editProject', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to update project.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      final projectMap = _extractLeadMap(decoded);
      if (projectMap != null) {
        return projectMap;
      }
    } catch (_) {}

    return <String, dynamic>{'id': normalizedId};
  }

  Future<void> deleteProject({
    required String id,
    String? token,
  }) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) {
      throw Exception('Project id is required.');
    }

    final resolvedToken = token ?? _authToken;
    final endpoint =
        ApiConstants.deleteprojects.replaceFirst('{id}', normalizedId);
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'deleteProject',
      method: 'DELETE',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.delete(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('deleteProject', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to delete project.',
    );
    if (error != null) {
      throw Exception(error);
    }
  }

  Future<void> assignUserManager({
    required String id,
    required String managerId,
    String? token,
  }) async {
    final normalizedId = id.trim();
    final normalizedManagerId = managerId.trim();

    if (normalizedId.isEmpty) {
      throw Exception('User id is required.');
    }
    if (normalizedManagerId.isEmpty) {
      throw Exception('Manager id is required.');
    }

    final resolvedToken = token ?? _authToken;
    final endpoint =
        ApiConstants.assignUserManager.replaceFirst('{id}', normalizedId);
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    final body = jsonEncode({'manager_id': normalizedManagerId});

    _logRequest(
      endpoint: 'assignUserManager',
      method: 'PATCH',
      uri: uri,
      headers: headers,
      body: body,
    );

    final response = await http
        .patch(uri, headers: headers, body: body)
        .timeout(_requestTimeout);
    _logResponse('assignUserManager', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to assign manager.',
    );
    if (error != null) {
      throw Exception(error);
    }
  }

  Future<List<Map<String, dynamic>>> notifications({
    String? token,
    String? type,
    bool? unreadOnly,
    int page = 1,
    int perPage = 30,
  }) async {
    final resolvedToken = token ?? _authToken;
    final query = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
    if (type != null && type.trim().isNotEmpty) {
      query['type'] = type.trim();
    }
    if (unreadOnly != null) {
      query['unread'] = unreadOnly.toString();
    }

    final uri =
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.notifications}')
            .replace(queryParameters: query);
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'notifications',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('notifications', response);
    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to fetch notifications.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      return _extractLeadsItems(decoded);
    } catch (_) {
      throw Exception('Notifications response format is not valid.');
    }
  }

  Future<LeadsListResult> notificationsPaged({
    String? token,
    String? type,
    bool? unreadOnly,
    int page = 1,
    int perPage = 10,
  }) async {
    final resolvedToken = token ?? _authToken;
    final query = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
    if (type != null && type.trim().isNotEmpty) {
      query['type'] = type.trim();
    }
    if (unreadOnly != null) {
      query['unread'] = unreadOnly.toString();
    }

    final uri =
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.notifications}')
            .replace(queryParameters: query);
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'notificationsPaged',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('notificationsPaged', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to fetch notifications.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      final items = _extractLeadsItems(decoded);
      final pagination = _extractPaginationMap(decoded);
      final resolvedCurrentPage = _readIntFromMap(
            pagination,
            ['page', 'current_page', 'currentPage'],
          ) ??
          page;
      final resolvedPerPage = _readIntFromMap(
            pagination,
            ['per_page', 'perPage', 'page_size', 'limit'],
          ) ??
          perPage;
      final resolvedTotalItems = _readIntFromMap(
            pagination,
            ['total', 'total_items', 'totalItems', 'count'],
          ) ??
          items.length;
      final resolvedTotalPages = _readIntFromMap(
            pagination,
            ['total_pages', 'totalPages', 'last_page', 'lastPage'],
          ) ??
          _deriveTotalPages(
              total: resolvedTotalItems, perPage: resolvedPerPage);
      return LeadsListResult(
        items: items,
        currentPage: resolvedCurrentPage,
        perPage: resolvedPerPage,
        totalItems: resolvedTotalItems,
        totalPages: resolvedTotalPages <= 0 ? 1 : resolvedTotalPages,
      );
    } catch (_) {
      throw Exception('Notifications response format is not valid.');
    }
  }

  Future<void> deleteAllNotifications({String? token}) async {
    final resolvedToken = token ?? _authToken;
    final uri = Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.deletenotifications}',
    );
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'deleteAllNotifications',
      method: 'DELETE',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.delete(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('deleteAllNotifications', response);
    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to delete all notifications.',
    );
    if (error != null) {
      throw Exception(error);
    }
  }

  Future<int> unreadNotificationsCount({String? token}) async {
    final resolvedToken = token ?? _authToken;
    final uri = Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.unreadcountnotifications}',
    );
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'unreadNotificationsCount',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('unreadNotificationsCount', response);
    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to fetch unread notifications count.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final rootCount = _readIntFromMap(decoded, ['count', 'unread_count']);
        if (rootCount != null) {
          return rootCount;
        }
        final dynamic data = decoded['data'];
        if (data is Map<String, dynamic>) {
          final nestedCount =
              _readIntFromMap(data, ['count', 'unread_count', 'unreadCount']);
          if (nestedCount != null) {
            return nestedCount;
          }
        }
      }
    } catch (_) {
      // Fall back to default.
    }
    return 0;
  }

  Future<List<String>> notificationTypes({String? token}) async {
    final resolvedToken = token ?? _authToken;
    final uri =
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.typesnotifications}');
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'notificationTypes',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('notificationTypes', response);
    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to fetch notification types.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      List<String> parseList(dynamic raw) {
        if (raw is! List) {
          return const <String>[];
        }
        return raw
            .map((item) => item?.toString().trim() ?? '')
            .where((item) => item.isNotEmpty)
            .toList();
      }

      final fromRoot = parseList(decoded);
      if (fromRoot.isNotEmpty) {
        return fromRoot;
      }
      if (decoded is Map<String, dynamic>) {
        final fromData = parseList(decoded['data']);
        if (fromData.isNotEmpty) {
          return fromData;
        }
        final dynamic data = decoded['data'];
        if (data is Map<String, dynamic>) {
          final fromNested = parseList(data['types']);
          if (fromNested.isNotEmpty) {
            return fromNested;
          }
        }
      }
    } catch (_) {
      // Fall through to default empty list.
    }

    return const <String>[];
  }

  Future<void> markAllNotificationsRead({String? token}) async {
    final resolvedToken = token ?? _authToken;
    final uri = Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.readallnotifications}',
    );
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'markAllNotificationsRead',
      method: 'PATCH',
      uri: uri,
      headers: headers,
      body: '{}',
    );

    final response = await http
        .patch(uri, headers: headers, body: jsonEncode(<String, dynamic>{}))
        .timeout(_requestTimeout);
    _logResponse('markAllNotificationsRead', response);
    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to mark all notifications as read.',
    );
    if (error != null) {
      throw Exception(error);
    }
  }

  Future<Map<String, dynamic>> markSingleNotificationRead({
    required String id,
    String? token,
  }) async {
    final resolvedToken = token ?? _authToken;
    final endpoint = ApiConstants.readsinglenotification.replaceAll('{id}', id);
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'markSingleNotificationRead',
      method: 'PATCH',
      uri: uri,
      headers: headers,
      body: '{}',
    );

    final response = await http
        .patch(uri, headers: headers, body: jsonEncode(<String, dynamic>{}))
        .timeout(_requestTimeout);
    _logResponse('markSingleNotificationRead', response);
    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to mark notification as read.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final dynamic data = decoded['data'];
        if (data is Map<String, dynamic>) {
          return _stringDynamicMap(data);
        }
        return _stringDynamicMap(decoded);
      }
    } catch (_) {
      // Fall through to default map.
    }

    return <String, dynamic>{'id': id, 'is_read': true};
  }

  Future<void> deleteSingleNotification({
    required String id,
    String? token,
  }) async {
    final resolvedToken = token ?? _authToken;
    final endpoint =
        ApiConstants.deletesinglenotification.replaceAll('{id}', id);
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'deleteSingleNotification',
      method: 'DELETE',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.delete(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('deleteSingleNotification', response);
    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to delete notification.',
    );
    if (error != null) {
      throw Exception(error);
    }
  }

  Future<void> registerFcmToken({
    required String fcmToken,
    required String platform,
    String? token,
  }) async {
    final resolvedToken = token ?? _authToken;
    if (resolvedToken == null || resolvedToken.trim().isEmpty) {
      throw Exception('Authentication token is required.');
    }
    final normalizedFcmToken = fcmToken.trim();
    if (normalizedFcmToken.isEmpty) {
      throw Exception('FCM token is required.');
    }

    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.fcmToken}');
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    final body = jsonEncode({
      'fcm_token': normalizedFcmToken,
      'platform': platform.trim().toLowerCase(),
    });
    _logRequest(
      endpoint: 'registerFcmToken',
      method: 'POST',
      uri: uri,
      headers: headers,
      body: body,
    );

    final response = await http
        .post(uri, headers: headers, body: body)
        .timeout(_requestTimeout);
    _logResponse('registerFcmToken', response);
    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to register FCM token.',
    );
    if (error != null) {
      throw Exception(error);
    }
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
    AppErrorHandler.logDebug(
      '[$endpoint] REQUEST $method $uri\nHeaders: $headers${body == null ? '' : '\nBody: $body'}',
      name: 'AuthService',
    );
  }

  void _logResponse(String endpoint, http.Response response) {
    AppErrorHandler.logDebug(
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

    return AppErrorHandler.friendlyMessageFromResponse(
      response.statusCode,
      response.body,
      fallbackMessage: fallbackMessage,
      reasonPhrase: response.reasonPhrase,
    );
  }

  Future<void> _storeTokensFromResponse(String responseBody) async {
    try {
      final dynamic body = jsonDecode(responseBody);
      if (body is! Map<String, dynamic>) {
        return;
      }

      final result = _tokenResultFromBody(body);
      _authToken = result.accessToken ?? _authToken;
      _refreshToken = result.refreshToken ?? _refreshToken;
      _currentPermissions = const EffectivePermissionsResult.empty();
      await _persistTokens();
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

  Map<String, dynamic>? _decodeJsonMap(String responseBody) {
    try {
      final dynamic decoded = jsonDecode(responseBody);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // Ignore malformed JSON and fall back to the default message.
    }
    return null;
  }

  String? _readForgotPasswordToken(dynamic source) {
    if (source is! Map<String, dynamic>) {
      return null;
    }

    for (final key in const <String>[
      'token',
      'reset_token',
      'resetToken',
      'reset_password_token',
    ]) {
      final dynamic value = source[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    return null;
  }

  String? _readForgotPasswordErrorMessage(String responseBody) {
    try {
      final dynamic decoded = jsonDecode(responseBody);
      if (decoded is Map<String, dynamic>) {
        for (final key in const <String>['message', 'error', 'detail']) {
          final dynamic value = decoded[key];
          if (value is String && value.trim().isNotEmpty) {
            return value.trim();
          }
        }
      }
    } catch (_) {
      // Fall back to the default message below.
    }

    return null;
  }

  String? _readStringValue(
    Map<String, dynamic> source,
    List<String> keys,
  ) {
    for (final key in keys) {
      final dynamic value = source[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  EffectivePermissionsResult _effectivePermissionsResultFromBody(
    Map<String, dynamic> body,
  ) {
    final payload = body['data'];
    final data = payload is Map<String, dynamic> ? payload : body;
    final permissionsMap = <String, ModulePermissionSet>{};
    final rawPermissions = data['permissions'];

    if (rawPermissions is Map) {
      for (final entry in rawPermissions.entries) {
        final moduleKey = entry.key.toString().trim().toLowerCase();
        final rawModulePermissions = entry.value;
        if (moduleKey.isEmpty || rawModulePermissions is! Map) {
          continue;
        }
        final actions = <String, bool>{};
        for (final actionEntry in rawModulePermissions.entries) {
          final actionKey = actionEntry.key.toString().trim().toLowerCase();
          if (actionKey.isEmpty) {
            continue;
          }
          final rawValue = actionEntry.value;
          final isAllowed = rawValue is bool
              ? rawValue
              : (rawValue is num
                  ? rawValue != 0
                  : rawValue.toString().trim().toLowerCase() == 'true');
          actions[actionKey] = isAllowed;
        }
        permissionsMap[moduleKey] = ModulePermissionSet(actions);
      }
    }

    List<String> readStringList(dynamic value) {
      if (value is! List) {
        return const <String>[];
      }
      return value
          .map((item) => item.toString().trim().toLowerCase())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    return EffectivePermissionsResult(
      role: (data['role'] ?? '').toString().trim().toLowerCase(),
      permissions: permissionsMap,
      modules: readStringList(data['modules']),
      permissionKeys: readStringList(data['permission_keys']),
      message: _readMessage(body) ?? 'Effective permissions fetched.',
    );
  }

  Future<LeadsListResult> _teamHistoryList({
    required String endpointName,
    required String endpointPath,
    required String fallbackMessage,
    required int page,
    required int perPage,
    String? token,
    Map<String, String>? query,
  }) async {
    final normalizedPath = endpointPath.trim();
    if (normalizedPath.isEmpty) {
      throw Exception('Invalid team history endpoint.');
    }

    final resolvedToken = token ?? _authToken;
    final queryParams = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
      ...?query,
    };

    final uri = Uri.parse('${ApiConstants.baseUrl}$normalizedPath')
        .replace(queryParameters: queryParams);
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: endpointName,
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse(endpointName, response);

    final error = _handleResponse(
      response,
      fallbackMessage: fallbackMessage,
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic body = jsonDecode(response.body);
      final items = _extractLeadsItems(body);
      final pagination = _extractPaginationMap(body);

      final resolvedCurrentPage = _readIntFromMap(
            pagination,
            ['page', 'current_page', 'currentPage'],
          ) ??
          page;
      final resolvedPerPage = _readIntFromMap(
            pagination,
            ['per_page', 'perPage', 'page_size', 'limit'],
          ) ??
          perPage;
      final resolvedTotalItems = _readIntFromMap(
            pagination,
            ['total', 'total_items', 'totalItems', 'count'],
          ) ??
          items.length;
      final resolvedTotalPages = _readIntFromMap(
            pagination,
            ['total_pages', 'totalPages', 'last_page', 'lastPage'],
          ) ??
          _deriveTotalPages(
            total: resolvedTotalItems,
            perPage: resolvedPerPage,
          );

      return LeadsListResult(
        items: items,
        currentPage: resolvedCurrentPage,
        perPage: resolvedPerPage,
        totalItems: resolvedTotalItems,
        totalPages: resolvedTotalPages <= 0 ? 1 : resolvedTotalPages,
      );
    } catch (_) {
      throw Exception('$fallbackMessage Invalid response format.');
    }
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

  List<Map<String, dynamic>>? _extractTeamTreeUsers(dynamic source) {
    if (source is! Map<String, dynamic>) {
      return null;
    }

    final data = source['data'];
    if (data is! Map<String, dynamic>) {
      return null;
    }

    final uniqueUsers = <String, Map<String, dynamic>>{};

    void addUser(dynamic rawUser) {
      if (rawUser is! Map) {
        return;
      }
      final user = _stringDynamicMap(rawUser);
      final id = _readId(user);
      if (id.isEmpty) {
        return;
      }
      uniqueUsers[id] = <String, dynamic>{
        ...user,
        if (!user.containsKey('is_active')) 'is_active': true,
      };
    }

    addUser(data['manager']);

    final team = data['team'];
    if (team is List) {
      for (final member in team) {
        addUser(member);
      }
    }

    return uniqueUsers.values.toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _ensureCurrentUserInAssignmentUsers({
    required List<Map<String, dynamic>> users,
    required String currentUserId,
    String? token,
  }) async {
    if (currentUserId.isEmpty) {
      return users;
    }

    final uniqueUsers = <String, Map<String, dynamic>>{
      for (final user in users)
        if (_readId(user).isNotEmpty)
          _readId(user): Map<String, dynamic>.from(user),
    };

    if (uniqueUsers.containsKey(currentUserId)) {
      return uniqueUsers.values.toList(growable: false);
    }

    try {
      final profileResult = await profile(token: token);
      final profileData = profileResult.data;
      final profileId = _readId(profileData);
      if (profileId.isNotEmpty) {
        uniqueUsers[profileId] = <String, dynamic>{
          ...profileData,
          if (!profileData.containsKey('full_name'))
            'full_name': _buildUserFullName(profileData),
          if (!profileData.containsKey('is_active')) 'is_active': true,
        };
      }
    } catch (_) {
      // Keep the team tree result usable even if the profile lookup fails.
    }

    return uniqueUsers.values.toList(growable: false);
  }

  String _buildUserFullName(Map<String, dynamic> user) {
    String read(dynamic value) {
      if (value is String) {
        return value.trim();
      }
      if (value is num || value is bool) {
        return value.toString().trim();
      }
      return '';
    }

    final firstName = read(user['first_name'] ?? user['firstName']);
    final lastName = read(user['last_name'] ?? user['lastName']);
    final combined = <String>[
      if (firstName.isNotEmpty) firstName,
      if (lastName.isNotEmpty) lastName,
    ].join(' ').trim();
    if (combined.isNotEmpty) {
      return combined;
    }
    return read(
      user['full_name'] ?? user['fullName'] ?? user['name'] ?? user['email'],
    );
  }

  List<Map<String, dynamic>>? _extractRoleList(dynamic source) {
    if (source is List) {
      return source.whereType<Map>().map(_stringDynamicMap).toList();
    }

    if (source is! Map<String, dynamic>) {
      return null;
    }

    final data = source['data'];
    if (data is List) {
      return data.whereType<Map>().map(_stringDynamicMap).toList();
    }

    final roles = source['roles'];
    if (roles is List) {
      return roles.whereType<Map>().map(_stringDynamicMap).toList();
    }

    return null;
  }

  Map<String, dynamic>? _extractSalaryEmployeesPayload(dynamic source) {
    if (source is! Map<String, dynamic>) {
      return null;
    }

    final data = source['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }

    return null;
  }

  Map<String, dynamic> _stringDynamicMap(Map source) {
    return source.map(
      (key, value) => MapEntry(key.toString(), value),
    );
  }

  Future<String> _resolveCurrentUserId({String? token}) async {
    final resolvedToken = token ?? _authToken;
    final fromToken = _extractUserIdFromToken(resolvedToken);
    if (fromToken.isNotEmpty) {
      return fromToken;
    }

    try {
      final profileResult = await profile(token: resolvedToken);
      return _readId(profileResult.data);
    } catch (_) {
      return '';
    }
  }

  String _extractUserIdFromToken(String? token) {
    final value = token?.trim() ?? '';
    if (value.isEmpty) {
      return '';
    }

    final parts = value.split('.');
    if (parts.length < 2) {
      return '';
    }

    try {
      final normalized = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final payload = jsonDecode(decoded);
      if (payload is Map<String, dynamic>) {
        return _readId(payload);
      }
    } catch (_) {
      return '';
    }

    return '';
  }

  String _readId(Map<String, dynamic> source) {
    for (final key in const ['id', 'user_id', 'userId', 'uuid']) {
      final value = source[key];
      if (value == null) {
        continue;
      }
      final normalized = value.toString().trim();
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
    return '';
  }

  List<Map<String, dynamic>> _extractLeadsItems(dynamic source) {
    List<Map<String, dynamic>>? readList(dynamic candidate) {
      if (candidate is List) {
        return candidate.whereType<Map>().map(_stringDynamicMap).toList();
      }
      return null;
    }

    final fromRootList = readList(source);
    if (fromRootList != null) {
      return fromRootList;
    }

    if (source is! Map<String, dynamic>) {
      return const <Map<String, dynamic>>[];
    }

    for (final key in [
      'data',
      'leads',
      'projects',
      'items',
      'results',
      'rows'
    ]) {
      final fromKey = readList(source[key]);
      if (fromKey != null) {
        return fromKey;
      }
    }

    final dynamic data = source['data'];
    if (data is Map<String, dynamic>) {
      for (final key in [
        'leads',
        'projects',
        'items',
        'results',
        'data',
        'rows'
      ]) {
        final fromNested = readList(data[key]);
        if (fromNested != null) {
          return fromNested;
        }
      }
    }

    return const <Map<String, dynamic>>[];
  }

  Map<String, dynamic> _extractPaginationMap(dynamic source) {
    if (source is Map<String, dynamic>) {
      if (source['pagination'] is Map<String, dynamic>) {
        return source['pagination'] as Map<String, dynamic>;
      }
      if (source['meta'] is Map<String, dynamic>) {
        return source['meta'] as Map<String, dynamic>;
      }

      final dynamic data = source['data'];
      if (data is Map<String, dynamic>) {
        if (data['pagination'] is Map<String, dynamic>) {
          return data['pagination'] as Map<String, dynamic>;
        }
        if (data['meta'] is Map<String, dynamic>) {
          return data['meta'] as Map<String, dynamic>;
        }
        return data;
      }

      return source;
    }

    return const <String, dynamic>{};
  }

  int? _readIntFromMap(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final dynamic value = map[key];
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }

  Map<String, dynamic>? _extractLeadMap(dynamic source) {
    if (source is Map<String, dynamic>) {
      final data = source['data'];
      if (data is Map<String, dynamic>) {
        return data;
      }

      for (final key in ['lead', 'item', 'result']) {
        final dynamic value = source[key];
        if (value is Map<String, dynamic>) {
          return value;
        }
      }
      return source;
    }
    return null;
  }

  List<Map<String, dynamic>> _extractLeadSourceItems(dynamic source) {
    List<Map<String, dynamic>> readList(dynamic value) {
      if (value is List) {
        return value.whereType<Map>().map(_stringDynamicMap).toList();
      }
      return const <Map<String, dynamic>>[];
    }

    final fromRootList = readList(source);
    if (fromRootList.isNotEmpty) {
      return fromRootList;
    }

    if (source is! Map<String, dynamic>) {
      return const <Map<String, dynamic>>[];
    }

    for (final key in ['data', 'sources', 'items', 'results']) {
      final fromKey = readList(source[key]);
      if (fromKey.isNotEmpty) {
        return fromKey;
      }
    }

    final data = source['data'];
    if (data is Map<String, dynamic>) {
      for (final key in ['sources', 'items', 'results']) {
        final fromNested = readList(data[key]);
        if (fromNested.isNotEmpty) {
          return fromNested;
        }
      }
    }

    return const <Map<String, dynamic>>[];
  }

  Map<String, dynamic>? _extractLeadSourceMap(dynamic source) {
    if (source is Map<String, dynamic>) {
      final data = source['data'];
      if (data is Map<String, dynamic>) {
        return _stringDynamicMap(data);
      }

      for (final key in ['source', 'item', 'result']) {
        final value = source[key];
        if (value is Map<String, dynamic>) {
          return _stringDynamicMap(value);
        }
      }
      return _stringDynamicMap(source);
    }
    return null;
  }

  int _deriveTotalPages({required int total, required int perPage}) {
    if (total <= 0) {
      return 1;
    }
    if (perPage <= 0) {
      return 1;
    }
    return (total / perPage).ceil();
  }

  MediaType _imageMediaType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) {
      return MediaType('image', 'png');
    }
    if (lower.endsWith('.webp')) {
      return MediaType('image', 'webp');
    }
    return MediaType('image', 'jpeg');
  }

  MediaType _audioMediaType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.mp3')) {
      return MediaType('audio', 'mpeg');
    }
    if (lower.endsWith('.wav')) {
      return MediaType('audio', 'wav');
    }
    if (lower.endsWith('.m4a')) {
      return MediaType('audio', 'mp4');
    }
    if (lower.endsWith('.aac')) {
      return MediaType('audio', 'aac');
    }
    if (lower.endsWith('.ogg')) {
      return MediaType('audio', 'ogg');
    }
    return MediaType('application', 'octet-stream');
  }

  MediaType _documentMediaType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.pdf')) {
      return MediaType('application', 'pdf');
    }
    if (lower.endsWith('.png')) {
      return MediaType('image', 'png');
    }
    if (lower.endsWith('.webp')) {
      return MediaType('image', 'webp');
    }
    if (lower.endsWith('.doc')) {
      return MediaType('application', 'msword');
    }
    if (lower.endsWith('.docx')) {
      return MediaType(
        'application',
        'vnd.openxmlformats-officedocument.wordprocessingml.document',
      );
    }
    return MediaType('image', 'jpeg');
  }

  MediaType _spreadsheetMediaType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.csv')) {
      return MediaType('text', 'csv');
    }
    if (lower.endsWith('.xls')) {
      return MediaType('application', 'vnd.ms-excel');
    }
    return MediaType(
      'application',
      'vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  Future<Map<String, dynamic>> dashboardStats({
    required String from,
    required String to,
    String? token,
  }) async {
    final resolvedToken = token ?? _authToken;
    final query = <String, String>{
      'from': from.trim(),
      'to': to.trim(),
    };
    final uri =
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.dashboardStats}')
            .replace(queryParameters: query);
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'dashboardStats',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('dashboardStats', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to fetch dashboard stats.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Dashboard stats response format is not valid.');
      }
      final dynamic data = decoded['data'];
      if (data is! Map<String, dynamic>) {
        throw Exception('Dashboard stats payload is missing.');
      }
      final dynamic stats = data['stats'];
      if (stats is! Map<String, dynamic>) {
        throw Exception('Dashboard stats data is missing.');
      }
      return _stringDynamicMap(stats);
    } catch (_) {
      throw Exception('Dashboard stats response format is not valid.');
    }
  }

  Future<List<Map<String, dynamic>>> dashboardUpcomingSiteVisits({
    int limit = 5,
    String? token,
  }) async {
    final resolvedToken = token ?? _authToken;
    final query = <String, String>{'limit': limit.toString()};
    final uri = Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.dashboardUpcomingSiteVisits}',
    ).replace(queryParameters: query);
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'dashboardUpcomingSiteVisits',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('dashboardUpcomingSiteVisits', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to fetch upcoming site visits.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Upcoming site visits response format is not valid.');
      }
      final dynamic data = decoded['data'];
      dynamic siteVisits;
      if (data is List) {
        siteVisits = data;
      } else if (data is Map<String, dynamic>) {
        siteVisits = data['site_visits'];
      }

      if (siteVisits is! List) {
        return const <Map<String, dynamic>>[];
      }

      return siteVisits
          .whereType<Map>()
          .map((entry) => _stringDynamicMap(entry))
          .toList();
    } catch (_) {
      throw Exception('Upcoming site visits response format is not valid.');
    }
  }

  Future<List<Map<String, dynamic>>> dashboardRecentActivity({
    int limit = 5,
    String? token,
  }) async {
    final resolvedToken = token ?? _authToken;
    final query = <String, String>{'limit': limit.toString()};
    final uri = Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.dashboardRecentActivity}',
    ).replace(queryParameters: query);
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'dashboardRecentActivity',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('dashboardRecentActivity', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to fetch recent activity.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Recent activity response format is not valid.');
      }
      final dynamic data = decoded['data'];
      if (data is! List) {
        return const <Map<String, dynamic>>[];
      }

      return data
          .whereType<Map>()
          .map((entry) => _stringDynamicMap(entry))
          .toList();
    } catch (_) {
      throw Exception('Recent activity response format is not valid.');
    }
  }

  Future<Map<String, dynamic>> dashboardMyTargets({
    required String month,
    String? token,
  }) async {
    final resolvedToken = token ?? _authToken;
    final uri = Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.dashboardMyTargets}',
    ).replace(queryParameters: <String, String>{'month': month.trim()});
    final headers = _headers(accept: '*/*', token: resolvedToken);
    _logRequest(
      endpoint: 'dashboardMyTargets',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('dashboardMyTargets', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to fetch target details.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Target response format is not valid.');
      }
      final dynamic data = decoded['data'];
      if (data is Map<String, dynamic>) {
        return data;
      }
      if (data is Map) {
        return _stringDynamicMap(data);
      }
    } catch (_) {
      throw Exception('Target response format is not valid.');
    }

    throw Exception('Target response format is not valid.');
  }

  Future<Map<String, dynamic>> targets({
    required String month,
    int page = 1,
    int perPage = 10,
    String? token,
  }) async {
    final resolvedToken = token ?? _authToken;
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.targets}')
        .replace(queryParameters: <String, String>{
      'month': month.trim(),
      'page': page.toString(),
      'per_page': perPage.toString(),
    });
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'targets',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('targets', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to fetch targets.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Targets response format is not valid.');
      }
      final dynamic data = decoded['data'];
      if (data is Map<String, dynamic>) {
        return data;
      }
      if (data is Map) {
        return _stringDynamicMap(data);
      }
    } catch (_) {
      throw Exception('Targets response format is not valid.');
    }

    throw Exception('Targets response format is not valid.');
  }

  Future<Map<String, dynamic>> setTarget({
    required String userId,
    required String month,
    required int siteVisitTarget,
    required int closureTarget,
    String? token,
  }) async {
    final resolvedToken = token ?? _authToken;
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      throw Exception('User id is required.');
    }

    final endpoint =
        ApiConstants.targetSet.replaceFirst('{userId}', normalizedUserId);
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final headers = _headers(accept: '*/*', token: resolvedToken);
    final body = jsonEncode(<String, dynamic>{
      'month': month.trim(),
      'site_visit_target': siteVisitTarget,
      'closure_target': closureTarget,
    });
    _logRequest(
      endpoint: 'setTarget',
      method: 'POST',
      uri: uri,
      headers: headers,
      body: body,
    );

    final response = await http
        .post(uri, headers: headers, body: body)
        .timeout(_requestTimeout);
    _logResponse('setTarget', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to set target.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final dynamic data = decoded['data'];
        if (data is Map<String, dynamic>) {
          return data;
        }
        return decoded;
      }
    } catch (_) {
      // Some successful updates may not return a structured payload.
    }

    return <String, dynamic>{
      'user_id': normalizedUserId,
      'month': month.trim(),
      'site_visit_target': siteVisitTarget,
      'closure_target': closureTarget,
    };
  }

  Future<Map<String, dynamic>> dashboardLeadPipeline({String? token}) async {
    final resolvedToken = token ?? _authToken;
    final uri = Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.dashboardLeadPipeline}',
    );
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'dashboardLeadPipeline',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('dashboardLeadPipeline', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to fetch lead pipeline.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Lead pipeline response format is not valid.');
      }
      final dynamic data = decoded['data'];
      if (data is! Map<String, dynamic>) {
        throw Exception('Lead pipeline payload is missing.');
      }
      return _stringDynamicMap(data);
    } catch (_) {
      throw Exception('Lead pipeline response format is not valid.');
    }
  }

  Future<Map<String, dynamic>> dashboardLeadSources({
    required String from,
    required String to,
    String? token,
  }) async {
    final resolvedToken = token ?? _authToken;
    final query = <String, String>{
      'from': from.trim(),
      'to': to.trim(),
    };
    final uri = Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.dashboardLeadSources}',
    ).replace(queryParameters: query);
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'dashboardLeadSources',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('dashboardLeadSources', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to fetch lead sources.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Lead sources response format is not valid.');
      }
      final dynamic data = decoded['data'];
      if (data is! Map<String, dynamic>) {
        throw Exception('Lead sources payload is missing.');
      }
      return _stringDynamicMap(data);
    } catch (_) {
      throw Exception('Lead sources response format is not valid.');
    }
  }

  Future<List<Map<String, dynamic>>> leadSourcesConfig({String? token}) async {
    final resolvedToken = token ?? _authToken;
    final uri = Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.leadSourcesConfig}',
    );
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'leadSourcesConfig',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('leadSourcesConfig', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to fetch lead sources.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      final items = _extractLeadSourceItems(decoded);
      return items;
    } catch (_) {
      throw Exception('Lead sources response format is not valid.');
    }
  }

  Future<Map<String, dynamic>> createLeadSource({
    required String name,
    String? token,
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw Exception('Lead source name is required.');
    }

    final resolvedToken = token ?? _authToken;
    final uri = Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.leadSourcesConfig}',
    );
    final headers = _headers(
      accept: 'application/json',
      token: resolvedToken,
    );
    final payload = jsonEncode(<String, dynamic>{'name': normalizedName});
    _logRequest(
      endpoint: 'createLeadSource',
      method: 'POST',
      uri: uri,
      headers: headers,
      body: payload,
    );

    final response = await http
        .post(uri, headers: headers, body: payload)
        .timeout(_requestTimeout);
    _logResponse('createLeadSource', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to create lead source.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      final item = _extractLeadSourceMap(decoded);
      if (item != null) {
        return item;
      }
    } catch (_) {}
    return <String, dynamic>{'name': normalizedName, 'is_active': true};
  }

  Future<Map<String, dynamic>> updateLeadSource({
    required String id,
    required String name,
    required bool isActive,
    String? token,
  }) async {
    final normalizedId = id.trim();
    final normalizedName = name.trim();
    if (normalizedId.isEmpty) {
      throw Exception('Lead source id is required.');
    }
    if (normalizedName.isEmpty) {
      throw Exception('Lead source name is required.');
    }

    final resolvedToken = token ?? _authToken;
    final endpoint =
        ApiConstants.leadSourceConfigDetail.replaceFirst('{id}', normalizedId);
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final headers = _headers(
      accept: 'application/json',
      token: resolvedToken,
    );
    final payload = jsonEncode(<String, dynamic>{
      'name': normalizedName,
      'is_active': isActive,
    });
    _logRequest(
      endpoint: 'updateLeadSource',
      method: 'PUT',
      uri: uri,
      headers: headers,
      body: payload,
    );

    final response = await http
        .put(uri, headers: headers, body: payload)
        .timeout(_requestTimeout);
    _logResponse('updateLeadSource', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to update lead source.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      final item = _extractLeadSourceMap(decoded);
      if (item != null) {
        return item;
      }
    } catch (_) {}
    return <String, dynamic>{
      'id': normalizedId,
      'name': normalizedName,
      'is_active': isActive,
    };
  }

  Future<void> deleteLeadSource({
    required String id,
    String? token,
  }) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) {
      throw Exception('Lead source id is required.');
    }

    final resolvedToken = token ?? _authToken;
    final endpoint =
        ApiConstants.leadSourceConfigDetail.replaceFirst('{id}', normalizedId);
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final headers = _headers(accept: '*/*', token: resolvedToken);
    _logRequest(
      endpoint: 'deleteLeadSource',
      method: 'DELETE',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.delete(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('deleteLeadSource', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to delete lead source.',
    );
    if (error != null) {
      throw Exception(error);
    }
  }

  Future<List<Map<String, dynamic>>> leadStatusesConfig({String? token}) async {
    final resolvedToken = token ?? _authToken;
    final uri = Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.leadStatusesConfig}',
    );
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'leadStatusesConfig',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('leadStatusesConfig', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to fetch lead statuses.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      return _extractLeadSourceItems(decoded);
    } catch (_) {
      throw Exception('Lead statuses response format is not valid.');
    }
  }

  Future<Map<String, dynamic>> createLeadStatus({
    required String key,
    required String label,
    required String color,
    required int sortOrder,
    String? token,
  }) async {
    final normalizedKey = key.trim();
    final normalizedLabel = label.trim();
    if (normalizedKey.isEmpty || normalizedLabel.isEmpty) {
      throw Exception('Status key and label are required.');
    }

    final resolvedToken = token ?? _authToken;
    final uri = Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.leadStatusesConfig}',
    );
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    final payload = jsonEncode(<String, dynamic>{
      'key': normalizedKey,
      'label': normalizedLabel,
      'color': color.trim(),
      'sort_order': sortOrder,
    });
    _logRequest(
      endpoint: 'createLeadStatus',
      method: 'POST',
      uri: uri,
      headers: headers,
      body: payload,
    );

    final response = await http
        .post(uri, headers: headers, body: payload)
        .timeout(_requestTimeout);
    _logResponse('createLeadStatus', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to create lead status.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      final item = _extractLeadSourceMap(decoded);
      if (item != null) {
        return item;
      }
    } catch (_) {}
    return <String, dynamic>{
      'key': normalizedKey,
      'label': normalizedLabel,
      'color': color.trim(),
      'sort_order': sortOrder,
      'is_active': true,
    };
  }

  Future<Map<String, dynamic>> updateLeadStatusConfig({
    required String id,
    required String label,
    required String color,
    required bool isActive,
    String? token,
  }) async {
    final normalizedId = id.trim();
    final normalizedLabel = label.trim();
    if (normalizedId.isEmpty || normalizedLabel.isEmpty) {
      throw Exception('Status id and label are required.');
    }

    final resolvedToken = token ?? _authToken;
    final endpoint =
        ApiConstants.leadStatusConfigDetail.replaceFirst('{id}', normalizedId);
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    final payload = jsonEncode(<String, dynamic>{
      'label': normalizedLabel,
      'color': color.trim(),
      'is_active': isActive,
    });
    _logRequest(
      endpoint: 'updateLeadStatusConfig',
      method: 'PUT',
      uri: uri,
      headers: headers,
      body: payload,
    );

    final response = await http
        .put(uri, headers: headers, body: payload)
        .timeout(_requestTimeout);
    _logResponse('updateLeadStatusConfig', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to update lead status config.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      final item = _extractLeadSourceMap(decoded);
      if (item != null) {
        return item;
      }
    } catch (_) {}
    return <String, dynamic>{
      'id': normalizedId,
      'label': normalizedLabel,
      'color': color.trim(),
      'is_active': isActive,
    };
  }

  Future<void> deleteLeadStatusConfig({
    required String id,
    String? token,
  }) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) {
      throw Exception('Status id is required.');
    }

    final resolvedToken = token ?? _authToken;
    final endpoint =
        ApiConstants.leadStatusConfigDetail.replaceFirst('{id}', normalizedId);
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final headers = _headers(accept: '*/*', token: resolvedToken);
    _logRequest(
      endpoint: 'deleteLeadStatusConfig',
      method: 'DELETE',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.delete(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('deleteLeadStatusConfig', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to delete lead status config.',
    );
    if (error != null) {
      throw Exception(error);
    }
  }

  Future<Map<String, dynamic>> dashboardRevenue({
    required String range,
    String? token,
  }) async {
    final resolvedToken = token ?? _authToken;
    final query = <String, String>{'range': range.trim()};
    final uri = Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.dashboardRevenue}',
    ).replace(queryParameters: query);
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'dashboardRevenue',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response =
        await http.get(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('dashboardRevenue', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to fetch revenue trend.',
    );
    if (error != null) {
      throw Exception(error);
    }

    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Revenue trend response format is not valid.');
      }
      final dynamic data = decoded['data'];
      if (data is! Map<String, dynamic>) {
        throw Exception('Revenue trend payload is missing.');
      }
      return _stringDynamicMap(data);
    } catch (_) {
      throw Exception('Revenue trend response format is not valid.');
    }
  }

  String? _readFileNameFromDisposition(String disposition) {
    if (disposition.trim().isEmpty) {
      return null;
    }
    final fileNameStar =
        RegExp("filename\\*=UTF-8''([^;]+)", caseSensitive: false)
            .firstMatch(disposition)
            ?.group(1);
    if (fileNameStar != null && fileNameStar.trim().isNotEmpty) {
      return Uri.decodeFull(fileNameStar.trim().replaceAll('"', ''));
    }
    final fileName = RegExp(r'filename="?([^\";]+)"?', caseSensitive: false)
        .firstMatch(disposition)
        ?.group(1);
    if (fileName == null || fileName.trim().isEmpty) {
      return null;
    }
    return fileName.trim();
  }

  Future<void> _clearTokens() async {
    _authToken = null;
    _refreshToken = null;
    _currentPermissions = const EffectivePermissionsResult.empty();
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_authTokenStorageKey);
    await preferences.remove(_refreshTokenStorageKey);
  }

  static Future<void> _restoreTokensFromStorage() async {
    final preferences = await SharedPreferences.getInstance();
    final storedAuthToken = preferences.getString(_authTokenStorageKey);
    final storedRefreshToken = preferences.getString(_refreshTokenStorageKey);

    _authToken = (storedAuthToken != null && storedAuthToken.trim().isNotEmpty)
        ? storedAuthToken
        : null;
    _refreshToken =
        (storedRefreshToken != null && storedRefreshToken.trim().isNotEmpty)
            ? storedRefreshToken
            : null;
  }

  static Future<void> _persistTokens() async {
    final preferences = await SharedPreferences.getInstance();

    if (_authToken != null && _authToken!.trim().isNotEmpty) {
      await preferences.setString(_authTokenStorageKey, _authToken!.trim());
    } else {
      await preferences.remove(_authTokenStorageKey);
    }

    if (_refreshToken != null && _refreshToken!.trim().isNotEmpty) {
      await preferences.setString(
        _refreshTokenStorageKey,
        _refreshToken!.trim(),
      );
    } else {
      await preferences.remove(_refreshTokenStorageKey);
    }
  }

  static Future<void> _pingBackend() async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.profile}');
    AppErrorHandler.logDebug(
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
      AppErrorHandler.logDebug(
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
        AppErrorHandler.logDebug(
          'Request attempt $attempt failed with timeout: $error',
          name: 'AuthService',
        );
      } on SocketException catch (error) {
        lastError = error;
        AppErrorHandler.logDebug(
          'Request attempt $attempt failed with socket error: $error',
          name: 'AuthService',
        );
      } on HandshakeException catch (error) {
        lastError = error;
        AppErrorHandler.logDebug(
          'Request attempt $attempt failed with handshake error: $error',
          name: 'AuthService',
        );
      } on http.ClientException catch (error) {
        lastError = error;
        AppErrorHandler.logDebug(
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

    throw Exception(AppErrorHandler.unknownMessage);
  }
}
