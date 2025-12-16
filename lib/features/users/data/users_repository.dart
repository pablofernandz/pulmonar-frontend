import 'dart:convert';
import 'package:http/http.dart' as http;

import 'user_model.dart';
import 'user_payloads.dart';
import '../../../core/auth/token_storage.dart';
import '../../../core/env.dart';

class UsersRepository {
  final http.Client _client;
  UsersRepository({http.Client? client}) : _client = client ?? http.Client();


  Future<UsersSearchResult> search({
    String? q,
    String? role, 
    int? groupPatientId,
    int? groupRevisorId,
    String? from, 
    String? to,   
    String sort = 'date_insert',
    String order = 'asc', 
    int page = 1,
    int limit = 20,
  }) async {
    final baseUrl = Env.apiBaseUrl;
    final qp = <String, String>{
      if (q != null && q.isNotEmpty) 'q': q,
      if (role != null && role.isNotEmpty) 'role': role,
      if (groupPatientId != null) 'groupPatientId': '$groupPatientId',
      if (groupRevisorId != null) 'groupRevisorId': '$groupRevisorId',
      if (from != null && from.isNotEmpty) 'from': from,
      if (to != null && to.isNotEmpty) 'to': to,
      'sort': sort,
      'order': order,
      'page': '$page',
      'limit': '$limit',
    };
    final uri = Uri.parse('$baseUrl/users').replace(queryParameters: qp);

    final token = await TokenStorage.instance.getToken();
    final res = await _client.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Error ${res.statusCode}: ${res.body}');
    }

    final Map<String, dynamic> json = jsonDecode(res.body);

    final List<dynamic> data = (json['data'] as List<dynamic>? ?? const []);
    final meta = (json['meta'] as Map<String, dynamic>? ?? const {});

    final items = data.map((e) => AppUser.fromJson(e as Map<String, dynamic>)).toList();

    return UsersSearchResult(
      items: items,
      page: (meta['page'] as int?) ?? page,
      limit: (meta['limit'] as int?) ?? limit,
      total: (meta['total'] as int?) ?? items.length,
      pages: (meta['pages'] as int?) ??
          (((meta['total'] as int?) ?? items.length) / ((meta['limit'] as int?) ?? limit)).ceil(),
    );
  }

  Future<UsersSearchResult> searchPatients({
    String? q,
    String sort = 'date_insert',
    String order = 'asc',
    int page = 1,
    int limit = 20,
  }) {
    return search(
      q: q,
      role: 'patient',
      sort: sort,
      order: order,
      page: page,
      limit: limit,
    );
  }

  Future<UsersSearchResult> searchPatientsInMyGroups({
    String? q,
    String sort = 'date_insert',
    String order = 'asc',
    int page = 1,
    int limit = 20,
  }) async {
    final meId = await _getMyUserId();
    return search(
      q: q,
      role: 'patient',
      groupRevisorId: meId,
      sort: sort,
      order: order,
      page: page,
      limit: limit,
    );
  }

  Future<AppUser> createUser(CreateUserPayload payload) async {
    final baseUrl = Env.apiBaseUrl;
    final uri = Uri.parse('$baseUrl/users');

    final token = await TokenStorage.instance.getToken();
    final res = await _client.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload.toJson()),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Error ${res.statusCode}: ${res.body}');
    }

    final Map<String, dynamic> json = jsonDecode(res.body);
    return AppUser.fromJson(json);
  }

  void dispose() {
    _client.close();
  }

  Future<AppUser> getUser(int id) async {
    final baseUrl = Env.apiBaseUrl;
    final uri = Uri.parse('$baseUrl/users/$id');

    final token = await TokenStorage.instance.getToken();
    final res = await _client.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Error ${res.statusCode}: ${res.body}');
    }

    final Map<String, dynamic> json = jsonDecode(res.body) as Map<String, dynamic>;
    return AppUser.fromJson(json);
  }

  Future<void> updateRoles({
    required int userId,
    required bool patient,
    required bool revisor,
  }) async {
    final baseUrl = Env.apiBaseUrl;
    final uri = Uri.parse('$baseUrl/users/$userId/roles');

    final token = await TokenStorage.instance.getToken();
    final res = await _client.put(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'patient': patient,
        'revisor': revisor,
      }),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('PUT /users/$userId/roles => ${res.statusCode}: ${res.body}');
    }
  }

  Future<void> updateGroups({
    required int userId,
    int? groupPatientId,
    List<int>? groupsRevisor,
  }) async {
    final baseUrl = Env.apiBaseUrl;
    final uri = Uri.parse('$baseUrl/users/$userId/groups');

    final token = await TokenStorage.instance.getToken();

    final body = <String, dynamic>{};
    if (groupPatientId != null) body['groupPatientId'] = groupPatientId;
    if (groupsRevisor != null) body['groupsRevisor'] = groupsRevisor;

    final res = await _client.put(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('PUT /users/$userId/groups => ${res.statusCode}: ${res.body}');
    }
  }

  Future<int> _getMyUserId() async {
    final baseUrl = Env.apiBaseUrl;
    final token = await TokenStorage.instance.getToken();
    final uri = Uri.parse('$baseUrl/auth/me');

    final res = await _client.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('GET /auth/me => ${res.statusCode}: ${res.body}');
    }

    final Map<String, dynamic> json = jsonDecode(res.body) as Map<String, dynamic>;
    final id = json['userId'];
    if (id is num) return id.toInt();
    if (id is String) {
      final parsed = int.tryParse(id);
      if (parsed != null) return parsed;
    }
    throw Exception('Formato inesperado en /auth/me (userId no válido)');
  }

  Future<AppUser> getMe() async {
    final id = await _getMyUserId();
    return getUser(id);
  }

  Future<void> changeMyPassword(String newPassword) async {
    if (newPassword.trim().length < 8) {
      throw Exception('La nueva contraseña debe tener al menos 8 caracteres.');
    }

    final id = await _getMyUserId();
    final baseUrl = Env.apiBaseUrl;
    final token = await TokenStorage.instance.getToken();
    final uri = Uri.parse('$baseUrl/users/$id/password');

    final res = await _client.put(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'newPassword': newPassword}),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('PUT /users/$id/password => ${res.statusCode}: ${res.body}');
    }
  }

  void close() => _client.close();
}
