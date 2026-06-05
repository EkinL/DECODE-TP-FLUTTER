import '../../services/api_service.dart';
import '../models/user_model.dart';

class AuthResponse {
  final String token;
  final UserModel user;

  AuthResponse({
    required this.token,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['token'],
      user: UserModel.fromJson(json['user']),
    );
  }

  @override
  String toString() {
    return token;
  }
}

class AuthRepository {
  Future authenticate(Map<String, dynamic> data) {
    return ApiService().request(
      httpMethod: .post,
      uri: 'auth',
      data: data,
      parser: (res) => AuthResponse.fromJson(res),
    );
  }

  Future refreshUser(String token) {
    return ApiService().request(
      httpMethod: .post,
      uri: 'refresh',
      parser: (res) => AuthResponse.fromJson(res),
    );
  }
}
