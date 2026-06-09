import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';

class AppErrorHandler {
  static const String noInternetMessage =
      'No internet connection. Please check your network.';
  static const String timeoutMessage =
      'Request timed out. Please try again.';
  static const String sessionExpiredMessage =
      'Your session has expired. Please login again.';
  static const String permissionMessage =
      "You don't have permission to perform this action.";
  static const String notFoundMessage = 'Requested data not found.';
  static const String validationFallbackMessage =
      'Please check the entered details.';
  static const String serverErrorMessage =
      'Something went wrong on our side. Please try again later.';
  static const String unknownMessage =
      'Something went wrong. Please try again.';

  static String friendlyMessage(
    Object? error, {
    String? fallbackMessage,
  }) {
    if (error == null) {
      return fallbackMessage ?? unknownMessage;
    }

    if (error is TimeoutException) {
      return timeoutMessage;
    }
    if (error is SocketException) {
      return noInternetMessage;
    }
    if (error is HandshakeException || error is HttpException) {
      return fallbackMessage ?? unknownMessage;
    }

    final raw = _normalize(error.toString());
    if (raw.isEmpty) {
      return fallbackMessage ?? unknownMessage;
    }

    final lower = raw.toLowerCase();
    if (_containsAny(lower, const <String>[
      'timeout',
      'timed out',
      'deadline exceeded',
    ])) {
      return timeoutMessage;
    }
    if (_containsAny(lower, const <String>[
      'socketexception',
      'no internet',
      'network is unreachable',
      'network error',
      'failed host lookup',
      'connection refused',
      'connection reset',
      'host lookup failed',
      'unable to connect',
    ])) {
      return noInternetMessage;
    }
    if (_containsAny(lower, const <String>[
      '401',
      'unauthorized',
      'authentication token is required',
      'refresh token is required',
      'session expired',
    ])) {
      return sessionExpiredMessage;
    }
    if (_containsAny(lower, const <String>[
      '403',
      'forbidden',
      'permission denied',
    ])) {
      return permissionMessage;
    }
    if (_containsAny(lower, const <String>[
      '404',
      'not found',
    ])) {
      return notFoundMessage;
    }
    if (_containsAny(lower, const <String>[
      '422',
      'unprocessable',
      'validation',
    ])) {
      final validationMessage = _extractValidationMessage(error);
      return validationMessage?.trim().isNotEmpty == true
          ? validationMessage!.trim()
          : validationFallbackMessage;
    }
    if (_containsAny(lower, const <String>[
      '500',
      'internal server error',
      'server error',
    ])) {
      return serverErrorMessage;
    }
    if (_looksTechnical(lower)) {
      return fallbackMessage ?? unknownMessage;
    }

    return raw;
  }

  static String friendlyMessageFromResponse(
    int statusCode,
    String responseBody, {
    String? fallbackMessage,
  }) {
    if (statusCode == 401) {
      return sessionExpiredMessage;
    }
    if (statusCode == 403) {
      return permissionMessage;
    }
    if (statusCode == 404) {
      return notFoundMessage;
    }
    if (statusCode == 500) {
      return serverErrorMessage;
    }
    if (statusCode == 422) {
      final validationMessage = _extractValidationMessage(responseBody);
      return validationMessage?.trim().isNotEmpty == true
          ? validationMessage!.trim()
          : validationFallbackMessage;
    }

    final parsedMessage = _extractMessage(responseBody);
    if (parsedMessage != null && parsedMessage.trim().isNotEmpty) {
      return friendlyMessage(
        parsedMessage,
        fallbackMessage: fallbackMessage,
      );
    }

    return fallbackMessage ?? unknownMessage;
  }

  static void logDebug(
    String message, {
    String name = 'App',
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!kDebugMode) {
      return;
    }

    developer.log(
      message,
      name: name,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static String _normalize(String value) {
    var result = value.trim();
    result = result.replaceFirst(RegExp(r'^Exception:\s*'), '');
    result = result.replaceFirst(RegExp(r'^FormatException:\s*'), '');
    result = result.replaceFirst(RegExp(r'^SocketException:\s*'), '');
    result = result.replaceFirst(RegExp(r'^HandshakeException:\s*'), '');
    result = result.replaceFirst(RegExp(r'^HttpException:\s*'), '');
    result = result.replaceFirst(RegExp(r'^ClientException:\s*'), '');
    result = result.replaceFirst(RegExp(r'^DioException(?:\s*\[[^\]]+\])?:\s*'),
        '');
    return result.trim();
  }

  static bool _containsAny(String value, List<String> needles) {
    for (final needle in needles) {
      if (value.contains(needle)) {
        return true;
      }
    }
    return false;
  }

  static bool _looksTechnical(String lowerValue) {
    return _containsAny(lowerValue, const <String>[
      'dioexception',
      'socketexception',
      'timeoutexception',
      'handshakeexception',
      'clientexception',
      'requestoptions.validatestatus',
      'stack trace',
      'invalid response format',
      'response format is not valid',
      'response is not valid json',
      'not valid json',
      'jsondecode',
      'formatexception',
      'unexpected character',
      'type \'null\' is not a subtype',
      'null check operator used on a null value',
      'request failed without a specific error',
      'http status',
      'status code',
      'raw backend error',
      'backend error',
      'exception:',
    ]);
  }

  static String? _extractValidationMessage(Object? source) {
    final dynamic decoded = _decodeBody(source);
    final messages = <String>[];
    _collectMessages(decoded, messages, includeKeys: true);
    if (messages.isEmpty && source is String) {
      final stripped = _normalize(source);
      if (stripped.isNotEmpty) {
        return stripped;
      }
    }
    if (messages.isEmpty) {
      return null;
    }
    return messages
        .map((message) => message.trim())
        .where((message) => message.isNotEmpty)
        .join('\n');
  }

  static String? _extractMessage(String responseBody) {
    final dynamic decoded = _decodeBody(responseBody);
    if (decoded == null) {
      return responseBody.trim().isEmpty ? null : responseBody.trim();
    }

    if (decoded is Map<String, dynamic>) {
      for (final key in <String>['message', 'error', 'detail', 'title']) {
        final dynamic value = decoded[key];
        final message = _stringFrom(value);
        if (message != null && message.trim().isNotEmpty) {
          return message.trim();
        }
      }
      final messages = <String>[];
      _collectMessages(decoded['errors'], messages, includeKeys: true);
      if (messages.isNotEmpty) {
        return messages.join('\n');
      }
    }

    if (decoded is List) {
      final messages = <String>[];
      _collectMessages(decoded, messages, includeKeys: true);
      if (messages.isNotEmpty) {
        return messages.join('\n');
      }
    }

    return _stringFrom(decoded);
  }

  static dynamic _decodeBody(Object? source) {
    if (source is! String || source.trim().isEmpty) {
      return source;
    }

    try {
      return jsonDecode(source);
    } catch (_) {
      return source;
    }
  }

  static void _collectMessages(
    dynamic source,
    List<String> messages, {
    required bool includeKeys,
  }) {
    if (source == null) {
      return;
    }

    if (source is String) {
      final message = source.trim();
      if (message.isNotEmpty) {
        messages.add(message);
      }
      return;
    }

    if (source is List) {
      for (final item in source) {
        _collectMessages(item, messages, includeKeys: includeKeys);
      }
      return;
    }

    if (source is Map) {
      source.forEach((dynamic key, dynamic value) {
        final keyText = key?.toString().trim() ?? '';
        if (value is List || value is Map) {
          final nestedMessages = <String>[];
          _collectMessages(value, nestedMessages, includeKeys: includeKeys);
          if (nestedMessages.isNotEmpty) {
            if (includeKeys && keyText.isNotEmpty) {
              messages.add('$keyText: ${nestedMessages.join(', ')}');
            } else {
              messages.addAll(nestedMessages);
            }
          }
          return;
        }

        final valueText = _stringFrom(value)?.trim() ?? '';
        if (valueText.isNotEmpty) {
          if (includeKeys && keyText.isNotEmpty) {
            messages.add('$keyText: $valueText');
          } else {
            messages.add(valueText);
          }
        }
      });
    }
  }

  static String? _stringFrom(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is String) {
      return value;
    }
    return value.toString();
  }
}
