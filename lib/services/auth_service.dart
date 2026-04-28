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

  Future<LeadsListResult> leads({
    String? token,
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

    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.leads}')
        .replace(queryParameters: query);
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'leads',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response = await http.get(uri, headers: headers).timeout(_requestTimeout);
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

      final resolvedCurrentPage =
          _readIntFromMap(pagination, ['page', 'current_page', 'currentPage']) ??
          page;
      final resolvedPerPage =
          _readIntFromMap(pagination, ['per_page', 'perPage', 'page_size', 'limit']) ??
          perPage;
      final resolvedTotalItems =
          _readIntFromMap(pagination, ['total', 'total_items', 'totalItems', 'count']) ??
          items.length;
      final resolvedTotalPages =
          _readIntFromMap(pagination, ['total_pages', 'totalPages', 'last_page', 'lastPage']) ??
          _deriveTotalPages(total: resolvedTotalItems, perPage: resolvedPerPage);

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

  Future<LeadsListResult> followUps({
    String? token,
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

    final response = await http.get(uri, headers: headers).timeout(_requestTimeout);
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

      final resolvedCurrentPage =
          _readIntFromMap(pagination, ['page', 'current_page', 'currentPage']) ??
          (page ?? 1);
      final resolvedPerPage =
          _readIntFromMap(pagination, ['per_page', 'perPage', 'page_size', 'limit']) ??
          (perPage ?? items.length);
      final resolvedTotalItems =
          _readIntFromMap(pagination, ['total', 'total_items', 'totalItems', 'count']) ??
          items.length;
      final resolvedTotalPages =
          _readIntFromMap(pagination, ['total_pages', 'totalPages', 'last_page', 'lastPage']) ??
          _deriveTotalPages(total: resolvedTotalItems, perPage: resolvedPerPage);

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

  Future<Map<String, dynamic>> createFollowUp({
    required String title,
    required String leadId,
    required String dueDate,
    required String priority,
    required String notes,
    String? token,
  }) async {
    final resolvedToken = token ?? _authToken;
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.createfollowups}');
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
    final endpoint = ApiConstants.editfollowups.replaceFirst('{id}', normalizedId);
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
    final endpoint = ApiConstants.followupsdetail.replaceFirst('{id}', normalizedId);
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final headers = _headers(accept: '*/*', token: resolvedToken);
    _logRequest(
      endpoint: 'followUpDetail',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response = await http.get(uri, headers: headers).timeout(_requestTimeout);
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
    final endpoint = ApiConstants.completestatusfollowups.replaceFirst('{id}', normalizedId);
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

  Future<void> deleteFollowUp({
    required String id,
    String? token,
  }) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) {
      throw Exception('Follow-up id is required.');
    }

    final resolvedToken = token ?? _authToken;
    final endpoint = ApiConstants.deletefollowups.replaceFirst('{id}', normalizedId);
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'deleteFollowUp',
      method: 'DELETE',
      uri: uri,
      headers: headers,
    );

    final response = await http.delete(uri, headers: headers).timeout(_requestTimeout);
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
    final endpoint = ApiConstants.leadsdetail.replaceFirst('{id}', normalizedId);
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'leadDetail',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response = await http.get(uri, headers: headers).timeout(_requestTimeout);
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

  Future<Map<String, dynamic>> createLead({
    required String name,
    required String phone,
    required String email,
    required String source,
    required String assignedTo,
    required String budget,
    required String locationPreference,
    required String notes,
    String? token,
  }) async {
    final resolvedToken = token ?? _authToken;
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.createsleads}');
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    final body = jsonEncode({
      'name': name.trim(),
      'phone': phone.trim(),
      'email': email.trim(),
      'source': source.trim(),
      'assigned_to': assignedTo.trim(),
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
      'email': email.trim(),
      'source': source.trim(),
      'assigned_to': assignedTo.trim(),
      'budget': budget.trim(),
      'location_preference': locationPreference.trim(),
      'notes': notes.trim(),
    };
  }

  Future<Map<String, dynamic>> editLead({
    required String id,
    required String name,
    required String phone,
    required String email,
    required String source,
    required String assignedTo,
    required String budget,
    required String locationPreference,
    required String notes,
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
      'name': name.trim(),
      'phone': phone.trim(),
      'email': email.trim(),
      'source': source.trim(),
      'assigned_to': assignedTo.trim(),
      'budget': budget.trim(),
      'location_preference': locationPreference.trim(),
      'notes': notes.trim(),
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
      'name': name.trim(),
      'phone': phone.trim(),
      'email': email.trim(),
      'source': source.trim(),
      'assigned_to': assignedTo.trim(),
      'budget': budget.trim(),
      'location_preference': locationPreference.trim(),
      'notes': notes.trim(),
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
    final endpoint = ApiConstants.updatestatusleads.replaceFirst('{id}', normalizedId);
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
    final endpoint = ApiConstants.reassignmemberleads.replaceFirst('{id}', normalizedId);
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
    final endpoint = ApiConstants.usersdetail.replaceFirst('{id}', normalizedId);
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'usersDetail',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response = await http.get(uri, headers: headers).timeout(_requestTimeout);
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

    final response = await http.delete(uri, headers: headers).timeout(_requestTimeout);
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
    final endpoint = ApiConstants.edituserrole.replaceFirst('{id}', normalizedId);
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
    String? search,
    int page = 1,
    int perPage = 20,
  }) async {
    final resolvedToken = token ?? _authToken;
    final query = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
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

    final response = await http.get(uri, headers: headers).timeout(_requestTimeout);
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

      final resolvedCurrentPage =
          _readIntFromMap(pagination, ['page', 'current_page', 'currentPage']) ??
          page;
      final resolvedPerPage =
          _readIntFromMap(pagination, ['per_page', 'perPage', 'page_size', 'limit']) ??
          perPage;
      final resolvedTotalItems =
          _readIntFromMap(pagination, ['total', 'total_items', 'totalItems', 'count']) ??
          items.length;
      final resolvedTotalPages =
          _readIntFromMap(pagination, ['total_pages', 'totalPages', 'last_page', 'lastPage']) ??
          _deriveTotalPages(total: resolvedTotalItems, perPage: resolvedPerPage);

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
    String? token,
  }) async {
    final resolvedToken = token ?? _authToken;
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.createprojects}');
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    final body = jsonEncode({
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
    });

    _logRequest(
      endpoint: 'createProject',
      method: 'POST',
      uri: uri,
      headers: headers,
      body: body,
    );

    final response = await http.post(uri, headers: headers, body: body).timeout(_requestTimeout);
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
    };
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
    final endpoint = ApiConstants.projectsdetail.replaceFirst('{id}', normalizedId);
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'projectDetail',
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    final response = await http.get(uri, headers: headers).timeout(_requestTimeout);
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
    String? token,
  }) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) {
      throw Exception('Project id is required.');
    }

    final resolvedToken = token ?? _authToken;
    final endpoint = ApiConstants.editprojects.replaceFirst('{id}', normalizedId);
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    final body = jsonEncode({
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
    });

    _logRequest(
      endpoint: 'editProject',
      method: 'PUT',
      uri: uri,
      headers: headers,
      body: body,
    );

    final response = await http.put(uri, headers: headers, body: body).timeout(_requestTimeout);
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
    final endpoint = ApiConstants.deleteprojects.replaceFirst('{id}', normalizedId);
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final headers = _headers(accept: 'application/json', token: resolvedToken);
    _logRequest(
      endpoint: 'deleteProject',
      method: 'DELETE',
      uri: uri,
      headers: headers,
    );

    final response = await http.delete(uri, headers: headers).timeout(_requestTimeout);
    _logResponse('deleteProject', response);

    final error = _handleResponse(
      response,
      fallbackMessage: 'Unable to delete project.',
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

  List<Map<String, dynamic>> _extractLeadsItems(dynamic source) {
    List<Map<String, dynamic>>? readList(dynamic candidate) {
      if (candidate is List) {
        return candidate
            .whereType<Map>()
            .map(_stringDynamicMap)
            .toList();
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

    for (final key in ['data', 'leads', 'projects', 'items', 'results', 'rows']) {
      final fromKey = readList(source[key]);
      if (fromKey != null) {
        return fromKey;
      }
    }

    final dynamic data = source['data'];
    if (data is Map<String, dynamic>) {
      for (final key in ['leads', 'projects', 'items', 'results', 'data', 'rows']) {
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

  int _deriveTotalPages({required int total, required int perPage}) {
    if (total <= 0) {
      return 1;
    }
    if (perPage <= 0) {
      return 1;
    }
    return (total / perPage).ceil();
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
