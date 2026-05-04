class ForgotPasswordResult {
  const ForgotPasswordResult({required this.message, this.resetToken});

  final String message;
  final String? resetToken;
}

class AuthProfileResult {
  const AuthProfileResult({required this.data, required this.message});

  final Map<String, dynamic> data;
  final String message;
}

class AuthTokenResult {
  const AuthTokenResult({
    required this.message,
    required this.data,
    this.accessToken,
    this.refreshToken,
  });

  final String message;
  final Map<String, dynamic> data;
  final String? accessToken;
  final String? refreshToken;
}

class LeadsListResult {
  const LeadsListResult({
    required this.items,
    required this.currentPage,
    required this.perPage,
    required this.totalItems,
    required this.totalPages,
  });

  final List<Map<String, dynamic>> items;
  final int currentPage;
  final int perPage;
  final int totalItems;
  final int totalPages;
}

class ExportFileResult {
  const ExportFileResult({
    required this.fileName,
    required this.bytes,
    required this.contentType,
  });

  final String fileName;
  final List<int> bytes;
  final String contentType;
}
