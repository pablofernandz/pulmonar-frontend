import 'package:dio/dio.dart';
import '../http/dio_client.dart';
import 'token_storage.dart';

class AuthRepository {
  final Dio _dio = DioClient().dio;

  Future<void> login({required String dni, required String password}) async {
    final r = await _dio.post('/auth/login', data: {
      'dni': dni,
      'password': password,
    });
    final token = r.data['access_token'] ?? r.data['token'] ?? r.data;
    if (token is! String) {
      throw Exception('Token inválido en /auth/login');
    }
    await TokenStorage.instance.setToken(token);
  }

  Future<({int userId, String dni, String? role, Map<String, dynamic> roles})> me() async {
    final r = await _dio.get('/auth/me');
    final m = Map<String, dynamic>.from(r.data as Map);
    return (
      userId: m['userId'] as int,
      dni: m['dni'] as String,
      role: m['role'] as String?,
      roles: Map<String, dynamic>.from(m['roles'] ?? const {}),
    );
  }

  Future<List<String>> availableRoles() async {
    final meData = await me();
    final rolesMap = meData.roles;
    final enabled = <String>[];

    rolesMap.forEach((k, v) {
      final on = v == true || v == 1 || v == 'true';
      if (on) enabled.add(k);
    });

    const order = ['coordinator', 'revisor', 'patient'];
    enabled.sort((a, b) => order.indexOf(a).compareTo(order.indexOf(b)));
    return enabled;
  }

  Future<void> selectRole(String role) async {
    final r = await _dio.post('/auth/select-role', data: {'role': role});
    final newToken = r.data['access_token'] as String?;
    if (newToken != null && newToken.isNotEmpty) {
      await TokenStorage.instance.setToken(newToken);
    }
    await TokenStorage.instance.setRole(role);
  }

  Future<void> logout() async {
    await TokenStorage.instance.clearToken();
    await TokenStorage.instance.clearRole();
  }


  Future<void> changePasswordWithCurrent({
    required String currentPassword,
    required String newPassword,
  }) async {
    final r = await _dio.post('/auth/change-password', data: {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
    if (r.statusCode == null || r.statusCode! < 200 || r.statusCode! >= 300) {
      throw Exception('POST /auth/change-password => ${r.statusCode}: ${r.data}');
    }
  }


  Future<void> changePasswordForUser({
    required int userId,
    required String newPassword,
  }) async {
    final r = await _dio.put('/users/$userId/password', data: {
      'newPassword': newPassword,
    });
    if (r.statusCode == null || r.statusCode! < 200 || r.statusCode! >= 300) {
      throw Exception('PUT /users/$userId/password => ${r.statusCode}: ${r.data}');
    }
  }

  Future<void> changeMyPasswordNoCurrent(String newPassword) async {
    final my = await me();
    await changePasswordForUser(userId: my.userId, newPassword: newPassword);
  }
}
