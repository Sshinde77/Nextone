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
