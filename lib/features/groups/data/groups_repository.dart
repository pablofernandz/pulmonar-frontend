import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../core/env.dart';
import '../../../core/auth/token_storage.dart';
import 'group_model.dart';

class GroupsRepository {
  final http.Client _client;
  GroupsRepository({http.Client? client}) : _client = client ?? http.Client();

  Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

  Future<GroupsSearchResult> list({String? q, int page = 1, int limit = 20}) async {
    final token = await TokenStorage.instance.getToken();
    final uri = Uri.parse('${Env.apiBaseUrl}/groups').replace(queryParameters: {
      if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
      'page': '$page',
      'limit': '$limit',
    });

    final res = await _client.get(uri, headers: _headers(token ?? ''));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('GET /groups => ${res.statusCode}: ${res.body}');
    }

    final decoded = jsonDecode(res.body);
    return GroupsSearchResult.fromJson(decoded);
  }

  Future<Group> create({
    required String name,
    required int storyId,
    required int revisionId,
  }) async {
    final token = await TokenStorage.instance.getToken();
    final uri = Uri.parse('${Env.apiBaseUrl}/groups');
    final body = jsonEncode({'name': name, 'story': storyId, 'revision': revisionId});

    final res = await _client.post(uri, headers: _headers(token ?? ''), body: body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('POST /groups => ${res.statusCode}: ${res.body}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return Group.fromJson(json);
  }

  Future<Group> update(int id, {String? name, int? storyId, int? revisionId}) async {
    final token = await TokenStorage.instance.getToken();
    final uri = Uri.parse('${Env.apiBaseUrl}/groups/$id');
    final body = jsonEncode({
      if (name != null) 'name': name,
      if (storyId != null) 'story': storyId,
      if (revisionId != null) 'revision': revisionId,
    });

    final res = await _client.patch(uri, headers: _headers(token ?? ''), body: body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('PATCH /groups/$id => ${res.statusCode}: ${res.body}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return Group.fromJson(json);
  }

  Future<GroupMembersResponse> getMembers(int groupId) async {
    final token = await TokenStorage.instance.getToken();
    final uri = Uri.parse('${Env.apiBaseUrl}/groups/$groupId/members');

    final res = await _client.get(uri, headers: _headers(token ?? ''));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('GET /groups/$groupId/members => ${res.statusCode}: ${res.body}');
    }

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return GroupMembersResponse.fromJson(json);
  }


  Future<void> addPatient({required int groupId, required int patientId}) async {
    final token = await TokenStorage.instance.getToken();
    final uri = Uri.parse('${Env.apiBaseUrl}/groups/add-patient');
    final res = await _client.post(
      uri,
      headers: _headers(token ?? ''),
      body: jsonEncode({'groupId': groupId, 'patientId': patientId}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('POST /groups/add-patient => ${res.statusCode}: ${res.body}');
    }
  }

  Future<void> addRevisor({required int groupId, required int revisorId}) async {
    final token = await TokenStorage.instance.getToken();
    final uri = Uri.parse('${Env.apiBaseUrl}/groups/add-revisor');
    final res = await _client.post(
      uri,
      headers: _headers(token ?? ''),
      body: jsonEncode({'groupId': groupId, 'revisorId': revisorId}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('POST /groups/add-revisor => ${res.statusCode}: ${res.body}');
    }
  }

  Future<void> removePatient({required int groupId, required int patientId}) async {
    final token = await TokenStorage.instance.getToken();
    final uri = Uri.parse('${Env.apiBaseUrl}/groups/$groupId/patient/$patientId');
    final res = await _client.delete(uri, headers: _headers(token ?? ''));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('DELETE /groups/$groupId/patient/$patientId => ${res.statusCode}: ${res.body}');
    }
  }

  Future<void> removeRevisor({required int groupId, required int revisorId}) async {
    final token = await TokenStorage.instance.getToken();
    final uri = Uri.parse('${Env.apiBaseUrl}/groups/$groupId/revisor/$revisorId');
    final res = await _client.delete(uri, headers: _headers(token ?? ''));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('DELETE /groups/$groupId/revisor/$revisorId => ${res.statusCode}: ${res.body}');
    }
  }

  void dispose() => _client.close();
}
