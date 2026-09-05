class Account {
  const Account({
    required this.id,
    required this.email,
    required this.name,
    required this.timezone,
  });
  final String id;
  final String email;
  final String name;
  final String timezone;

  factory Account.fromJson(Map<String, dynamic> json) => Account(
    id: json['id'] as String,
    email: json['email'] as String,
    name: json['display_name'] as String? ?? '',
    timezone: json['timezone'] as String? ?? 'Asia/Bangkok',
  );
}

class SessionTokens {
  const SessionTokens({required this.access, required this.refresh});
  final String access;
  final String refresh;
  factory SessionTokens.fromJson(Map<String, dynamic> json) {
    final access = json['access_token'] as String;
    final refresh = json['refresh_token'] as String;
    if (access.isEmpty || refresh.isEmpty) {
      throw const FormatException('Empty session token');
    }
    return SessionTokens(access: access, refresh: refresh);
  }
  Map<String, dynamic> toJson() => {
    'access_token': access,
    'refresh_token': refresh,
  };
}

class AuthResult {
  const AuthResult(this.account, this.tokens);
  final Account account;
  final SessionTokens tokens;
}

class AuthFailure implements Exception {
  const AuthFailure(this.message, {this.status, this.code});
  final String message;
  final int? status;
  final String? code;
  bool get sessionRejected => status == 401 || code == 'ACCOUNT_SUSPENDED';
}
