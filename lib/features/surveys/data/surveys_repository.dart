import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../core/auth/token_storage.dart';
import '../../../core/env.dart';

import 'survey_models.dart';

class Conflict409Exception implements Exception {
  final String message;
  Conflict409Exception([this.message = '409 CONFLICT']);
  @override
  String toString() => 'Conflict409Exception: $message';
}

class SurveysRepository {
  final http.Client _client;
  SurveysRepository({http.Client? client}) : _client = client ?? http.Client();

  Future<Map<String, String>> _headers() async {
    final token = await TokenStorage.instance.getToken();
    return {
      'Authorization': 'Bearer ${token ?? ''}',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
  }


  void dispose() => _client.close();

  int _asInt(dynamic v, {required int fallback}) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    final s = v?.toString();
    final n = int.tryParse(s ?? '');
    return n ?? fallback;
  }

  bool _asBool(dynamic v, {required bool fallback}) {
    if (v is bool) return v;
    final s = (v ?? '').toString().toLowerCase();
    if (s == 'true' || s == '1') return true;
    if (s == 'false' || s == '0') return false;
    return fallback;
  }

  bool _isIntString(String s) => RegExp(r'^[+-]?\d+$').hasMatch(s);


  Future<SurveysSearchResult> search({
    String? q,
    String? name,
    int? id,
    int? type,
    String orderBy = 'date_insert',
    String orderDir = 'DESC',
    int page = 1,
    int limit = 20,
  }) async {
    final params = <String, String>{
      'orderDir': orderDir,
      'orderBy': orderBy,
      'limit': '$limit',
      'page': '$page',
    };
    if (q != null && q.trim().isNotEmpty) params['q'] = q.trim();
    if (name != null && name.trim().isNotEmpty) params['name'] = name.trim();
    if (id != null) params['id'] = '$id';
    if (type != null) params['type'] = '$type';

    final uri = Uri.parse('${Env.apiBaseUrl}/surveys/search')
        .replace(queryParameters: params);

    final res = await _client.get(uri, headers: await _headers());
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('GET /surveys/search => ${res.statusCode}: ${res.body}');
    }

    final decoded = jsonDecode(res.body);

    if (decoded is List) {
      final items = decoded
          .whereType<Map>()
          .map((m) => SurveyListItem.fromJson(
              Map<String, dynamic>.from(m as Map)))
          .toList();

      final meta = SurveysSearchMeta(
        page: page,
        limit: limit,
        totalItems: items.length,
        totalPages: 1,
        hasNext: false,
        orderBy: orderBy,
        orderDir: orderDir,
      );
      return SurveysSearchResult(items: items, meta: meta);
    }

    if (decoded is Map) {
      final dataRaw = decoded['data'];
      final metaRaw = decoded['meta'];

      final items = (dataRaw is List ? dataRaw : const [])
          .whereType<Map>()
          .map((m) => SurveyListItem.fromJson(
              Map<String, dynamic>.from(m as Map)))
          .toList();

      final meta = (metaRaw is Map)
          ? SurveysSearchMeta(
              page: _asInt(metaRaw['page'], fallback: page),
              limit: _asInt(metaRaw['limit'], fallback: limit),
              totalItems: _asInt(metaRaw['totalItems'], fallback: items.length),
              totalPages: _asInt(metaRaw['totalPages'], fallback: 1),
              hasNext: _asBool(metaRaw['hasNext'], fallback: false),
              orderBy: (metaRaw['orderBy'] ?? orderBy).toString(),
              orderDir: (metaRaw['orderDir'] ?? orderDir).toString(),
            )
          : SurveysSearchMeta(
              page: page,
              limit: limit,
              totalItems: items.length,
              totalPages: 1,
              hasNext: false,
              orderBy: orderBy,
              orderDir: orderDir,
            );

      return SurveysSearchResult(items: items, meta: meta);
    }

    throw Exception('Formato inesperado en /surveys/search');
  }

  Future<SurveyTree> getTree(int id) async {
    final uri = Uri.parse('${Env.apiBaseUrl}/surveys/$id');
    final res = await _client.get(uri, headers: await _headers());
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('GET /surveys/$id => ${res.statusCode}: ${res.body}');
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! Map) {
      throw Exception('Formato inesperado en /surveys/$id');
    }
    return SurveyTree.fromJson(Map<String, dynamic>.from(decoded as Map));
  }


  Future<int> createSurvey({
    required String name,
    required int type,          
    required int idCoordinator, 
  }) async {
    final uri = Uri.parse('${Env.apiBaseUrl}/surveys');
    final body = jsonEncode({
      'name': name,
      'type': type,
      'idCoordinator': idCoordinator,
    });
    final res = await _client.post(uri, headers: await _headers(), body: body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('POST /surveys => ${res.statusCode}: ${res.body}');
    }
    final decoded = jsonDecode(res.body);
    if (decoded is Map && decoded['id'] != null) {
      return _asInt(decoded['id'], fallback: -1);
    }
    if (decoded is int) return decoded;
    throw Exception('Respuesta inesperada creando survey: ${res.body}');
  }

  Future<void> duplicateInto({
    required int targetId,
    required int sourceId,
  }) async {
    final uri = Uri.parse(
      '${Env.apiBaseUrl}/surveys/$targetId/duplicate-into/$sourceId',
    );
    final res = await _client.post(uri, headers: await _headers());
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('POST duplicate-into => ${res.statusCode}: ${res.body}');
    }
  }

  Future<void> finalizeSurvey(int id) async {
    final uri = Uri.parse('${Env.apiBaseUrl}/surveys/$id/finalize');
    final res = await _client.post(uri, headers: await _headers());
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('POST /surveys/$id/finalize => ${res.statusCode}: ${res.body}');
    }
  }

  Future<List<Map<String, dynamic>>> searchSections({
    String? name,
    int? idCoordinator,
    int page = 1,
    int limit = 50,
    String orderBy = 'name',
    String orderDir = 'ASC',
  }) async {
    final params = <String, String>{
      'page': '$page',
      'limit': '$limit',
      'orderBy': orderBy,
      'orderDir': orderDir,
    };
    if (name != null && name.trim().isNotEmpty) params['name'] = name.trim();
    if (idCoordinator != null) params['idCoordinator'] = '$idCoordinator';

    final uri = Uri.parse('${Env.apiBaseUrl}/surveys/sections/search')
        .replace(queryParameters: params);

    final res = await _client.get(uri, headers: await _headers());
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('GET /surveys/sections/search => ${res.statusCode}: ${res.body}');
    }

    final decoded = jsonDecode(res.body);
    if (decoded is Map && decoded['data'] is List) {
      return (decoded['data'] as List)
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m as Map))
          .toList();
    }
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m as Map))
          .toList();
    }
    throw Exception('Formato inesperado en /surveys/sections/search');
  }

  Future<void> attachSections({
    required int surveyId,
    required List<int> sectionIds,
    int? insertAfterOrder, 
  }) async {
    final uri = Uri.parse('${Env.apiBaseUrl}/surveys/$surveyId/sections/attach');
    final body = jsonEncode({
      'sectionIds': sectionIds,
      if (insertAfterOrder != null) 'insertAfterOrder': insertAfterOrder,
    });
    final res = await _client.post(uri, headers: await _headers(), body: body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('POST /surveys/$surveyId/sections/attach => ${res.statusCode}: ${res.body}');
    }
  }

  Future<void> createSection({
    required int surveyId,
    required String name,
    int? targetOrder,
  }) async {
    final uri = Uri.parse('${Env.apiBaseUrl}/surveys/$surveyId/sections');
    final body = jsonEncode({
      'name': name,
      if (targetOrder != null) 'targetOrder': targetOrder,
    });
    final res = await _client.post(uri, headers: await _headers(), body: body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('POST /surveys/$surveyId/sections => ${res.statusCode}: ${res.body}');
    }
  }

  Future<void> moveSection({
    required int sectionId,
    required int targetOrder,
  }) async {
    final uri = Uri.parse('${Env.apiBaseUrl}/surveys/section/$sectionId');
    final body = jsonEncode({'targetOrder': targetOrder});
    final res = await _client.patch(uri, headers: await _headers(), body: body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('PATCH /surveys/section/$sectionId => ${res.statusCode}: ${res.body}');
    }
  }

  Future<void> deleteSection(int sectionId) async {
    final uri = Uri.parse('${Env.apiBaseUrl}/surveys/section/$sectionId');
    final res = await _client.delete(uri, headers: await _headers());
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('DELETE /surveys/section/$sectionId => ${res.statusCode}: ${res.body}');
    }
  }

  Future<void> deleteSurvey(int id) async {
    final uri = Uri.parse('${Env.apiBaseUrl}/surveys/$id');
    final res = await _client.delete(uri, headers: await _headers());
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('DELETE /surveys/$id => ${res.statusCode}: ${res.body}');
    }
  }

  Future<List<Map<String, dynamic>>> searchQuestions({
    String? name,
    int? idCoordinator,
    int page = 1,
    int limit = 200, 
    String orderBy = 'date_insert',
    String orderDir = 'DESC',
  }) async {
    final params = <String, String>{
      'page': '$page',
      'limit': '$limit',
      'orderBy': orderBy,
      'orderDir': orderDir,
    };
    if (name != null && name.trim().isNotEmpty) params['name'] = name.trim();
    if (idCoordinator != null) params['idCoordinator'] = '$idCoordinator';

    final uri = Uri.parse('${Env.apiBaseUrl}/surveys/questions/search')
        .replace(queryParameters: params);
    final res = await _client.get(uri, headers: await _headers());
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('GET /surveys/questions/search => ${res.statusCode}: ${res.body}');
    }
    final decoded = jsonDecode(res.body);
    final List data =
        (decoded is Map && decoded['data'] is List) ? decoded['data'] as List : (decoded as List);
    return data.whereType<Map>().map((m) => Map<String, dynamic>.from(m as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> searchQuestionsAll({
    String? name,
    int? idCoordinator,
    int pageSize = 200,
    String orderBy = 'date_insert',
    String orderDir = 'DESC',
  }) async {
    final acc = <Map<String, dynamic>>[];
    var page = 1;

    while (true) {
      final params = <String, String>{
        'page': '$page',
        'limit': '$pageSize',
        'orderBy': orderBy,
        'orderDir': orderDir,
      };
      if (name != null && name.trim().isNotEmpty) params['name'] = name.trim();
      if (idCoordinator != null) params['idCoordinator'] = '$idCoordinator';

      final uri = Uri.parse('${Env.apiBaseUrl}/surveys/questions/search')
          .replace(queryParameters: params);

      final res = await _client.get(uri, headers: await _headers());
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('GET /surveys/questions/search => ${res.statusCode}: ${res.body}');
      }

      final decoded = jsonDecode(res.body);

      final List data = (decoded is Map && decoded['data'] is List)
          ? decoded['data'] as List
          : (decoded as List);
      final pageItems = data
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m as Map))
          .toList();

      acc.addAll(pageItems);

      bool hasNext;
      if (decoded is Map && decoded['meta'] is Map) {
        hasNext = _asBool(decoded['meta']['hasNext'], fallback: false);
      } else {
        hasNext = pageItems.length == pageSize;
      }

      if (!hasNext || pageItems.isEmpty) break;
      page++;
    }

    return acc;
  }

  Future<void> attachQuestions({
    required int sectionId,
    required List<int> questionIds,
    int? insertAfterOrder,
  }) async {
    final uri = Uri.parse('${Env.apiBaseUrl}/surveys/section/$sectionId/questions/attach');
    final body = <String, dynamic>{'questionIds': questionIds};
    if (insertAfterOrder != null) body['insertAfterOrder'] = insertAfterOrder;
    final res = await _client.post(uri, headers: await _headers(), body: jsonEncode(body));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('POST /surveys/section/$sectionId/questions/attach => ${res.statusCode}: ${res.body}');
    }
  }

  Future<void> createQuestion({
    required int sectionId,
    required String name,
    int? targetOrder,
  }) async {
    final uri = Uri.parse('${Env.apiBaseUrl}/surveys/section/$sectionId/questions');
    final body = <String, dynamic>{'name': name};
    if (targetOrder != null) body['targetOrder'] = targetOrder;
    final res = await _client.post(uri, headers: await _headers(), body: jsonEncode(body));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('POST /surveys/section/$sectionId/questions => ${res.statusCode}: ${res.body}');
    }
  }

Future<int> createSectionReturnId({
  required int surveyId,
  required String name,
  int? targetOrder,
}) async {
  final uri = Uri.parse('${Env.apiBaseUrl}/surveys/$surveyId/sections');
  final body = jsonEncode({
    'name': name,
    if (targetOrder != null) 'targetOrder': targetOrder,
  });
  final res = await _client.post(uri, headers: await _headers(), body: body);

  if (res.statusCode < 200 || res.statusCode >= 300) {
    throw Exception('POST /surveys/$surveyId/sections => ${res.statusCode}: ${res.body}');
  }

  if (res.body.isNotEmpty) {
    final decoded = jsonDecode(res.body);
    if (decoded is Map && decoded['id'] != null) {
      return _asInt(decoded['id'], fallback: -1);
    }
    if (decoded is Map && decoded['data'] is Map && decoded['data']['id'] != null) {
      return _asInt(decoded['data']['id'], fallback: -1);
    }
  }

  final tree = await getTree(surveyId);
  final target = name.trim().toLowerCase();
  final found = tree.sections.where((s) {
    final sameName = s.name.trim().toLowerCase() == target;
    final sameOrder = (targetOrder == null) ? true : s.order == targetOrder;
    return sameName && sameOrder;
  }).toList();
  if (found.isNotEmpty) return found.last.id;

  throw Exception('No pude resolver el ID de la sección recién creada (surveyId=$surveyId, name="$name").');
}


Future<int> createQuestionReturnId({
  required int sectionId,
  required String name,
  int? targetOrder,
}) async {
  final uri = Uri.parse('${Env.apiBaseUrl}/surveys/section/$sectionId/questions');
  final body = jsonEncode({
    'name': name,
    if (targetOrder != null) 'targetOrder': targetOrder,
  });
  final res = await _client.post(uri, headers: await _headers(), body: body);

  if (res.statusCode < 200 || res.statusCode >= 300) {
    throw Exception('POST /surveys/section/$sectionId/questions => ${res.statusCode}: ${res.body}');
  }

  if (res.body.isNotEmpty) {
    final decoded = jsonDecode(res.body);
    if (decoded is Map && decoded['id'] != null) {
      return _asInt(decoded['id'], fallback: -1);
    }
    if (decoded is Map && decoded['data'] is Map && decoded['data']['id'] != null) {
      return _asInt(decoded['data']['id'], fallback: -1);
    }
  }

  throw Exception('El backend no devolvió el id de la pregunta creada (sectionId=$sectionId).');
}


Future<List<Map<String, dynamic>>> tryGetSurveySectionQuestions({
  required int surveyId,
  required int sectionId,
}) async {
  try {
    final tree = await getTree(surveyId);
    final sec = tree.sections.firstWhere(
      (s) => s.id == sectionId,
      orElse: () => SurveySectionNode(id: -1, name: '', order: 0, questions: const []),
    );
    if (sec.id <= 0) return const [];
    return sec.questions
        .map((q) => {
              'id': q.id,
              'name': q.name,
              'order': q.order,
            })
        .toList();
  } catch (_) {
    return const [];
  }
}

  Future<List<Map<String, dynamic>>> tryGetSectionQuestions(int sectionId) async {
    final uri = Uri.parse('${Env.apiBaseUrl}/surveys/sections/$sectionId/tree');
    try {
      final res = await _client.get(uri, headers: await _headers());
      if (res.statusCode == 404) {
        return const [];
      }
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('GET /surveys/sections/$sectionId/tree => ${res.statusCode}: ${res.body}');
      }
      final decoded = jsonDecode(res.body);
      if (decoded is! Map) return const [];
      final qs = (decoded['questions'] is List) ? (decoded['questions'] as List) : const [];
      return qs.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<Map<String, dynamic>> getQuestionExtended(int questionId) async {
    final uri = Uri.parse('${Env.apiBaseUrl}/catalog/questions/$questionId/extended');
    final res = await _client.get(uri, headers: await _headers());
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('GET /catalog/questions/$questionId/extended => ${res.statusCode}: ${res.body}');
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! Map) {
      throw Exception('Formato inesperado en /catalog/questions/{id}/extended');
    }
    return Map<String, dynamic>.from(decoded as Map);
  }

  Future<List<Map<String, dynamic>>> searchResponses({
    String? name,
    int? type,
    int page = 1,
    int limit = 200,
    String orderBy = 'date_insert',
    String orderDir = 'DESC',
  }) async {
    final params = <String, String>{
      'page': '$page',
      'limit': '$limit',
      'orderBy': orderBy,
      'orderDir': orderDir,
    };
    if (name != null && name.trim().isNotEmpty) params['name'] = name.trim();
    if (type != null) params['type'] = '$type';

    final uri = Uri.parse('${Env.apiBaseUrl}/surveys/responses/search')
        .replace(queryParameters: params);
    final res = await _client.get(uri, headers: await _headers());
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('GET /surveys/responses/search => ${res.statusCode}: ${res.body}');
    }
    final decoded = jsonDecode(res.body);
    final List data =
        (decoded is Map && decoded['data'] is List) ? decoded['data'] as List : (decoded as List);
    return data.whereType<Map>().map((m) => Map<String, dynamic>.from(m as Map)).toList();
  }

  Future<void> attachResponses({
    required int questionId,
    required List<int> responseIds,
    int? insertAfterOrder,
  }) async {
    final uri = Uri.parse('${Env.apiBaseUrl}/surveys/question/$questionId/responses/attach');
    final body = <String, dynamic>{
      'responseIds': responseIds,
      if (insertAfterOrder != null) 'insertAfterOrder': insertAfterOrder,
    };
    final res = await _client.post(uri, headers: await _headers(), body: jsonEncode(body));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('POST /surveys/question/$questionId/responses/attach => ${res.statusCode}: ${res.body}');
    }
  }

  Future<void> createResponseAndAttach({
    required int questionId,
    required String name,
    int? type,                 
    String? unity,             
    String? min,              
    String? max,              
    int? insertAfterOrder,    
    int? idCoordinator,       
  }) async {
    if (type != null && (type < 0 || type > 2)) {
      throw ArgumentError('type debe ser 0, 1 o 2');
    }
    if (type == 2) {
      if (min == null || min.isEmpty || max == null || max.isEmpty || !_isIntString(min) || !_isIntString(max)) {
        throw ArgumentError('Para type=2, min y max deben ser enteros (sin decimales)');
      }
    }

    final uri = Uri.parse('${Env.apiBaseUrl}/surveys/question/$questionId/responses/new');
    final body = <String, dynamic>{
      'name': name,
      if (type != null) 'type': type,
      if (unity != null && unity.isNotEmpty) 'unity': unity,
      if (min != null && min.isNotEmpty) 'min': min,
      if (max != null && max.isNotEmpty) 'max': max,
      if (insertAfterOrder != null) 'targetOrder': insertAfterOrder,
      if (idCoordinator != null) 'idCoordinator': idCoordinator,
    };

    final res = await _client.post(uri, headers: await _headers(), body: jsonEncode(body));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('POST /surveys/question/$questionId/responses/new => ${res.statusCode}: ${res.body}');
    }
  }

  Future<List<Map<String, dynamic>>> getListQuestions(int listId) async {
    final uri = Uri.parse('${Env.apiBaseUrl}/catalog/items/$listId/questions');
    final res = await _client.get(uri, headers: await _headers());

    if (res.statusCode == 404) {
      return <Map<String, dynamic>>[]; 
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('GET /catalog/items/$listId/questions => ${res.statusCode}: ${res.body}');
    }

    final decoded = jsonDecode(res.body);

    final List raw = (decoded is Map && decoded['data'] is List)
        ? decoded['data'] as List
        : (decoded is Map && decoded['questions'] is List)
            ? decoded['questions'] as List
            : (decoded is List ? decoded : const []);

    return raw.whereType<Map>().map((m) {
      final mm = Map<String, dynamic>.from(m);
      final id = (mm['id'] as num?)?.toInt();
      final name = (mm['name'] ?? '').toString();
      return {'id': id, 'name': name, ...mm};
    }).toList();
  }

Future<void> addQuestionToList({
  required int listId,
  required int dtoQuestionId,
  int? order,
  bool forceDetach = false,          
}) async {
  final uri = Uri.parse('${Env.apiBaseUrl}/surveys/items/$listId/questions');
  final body = jsonEncode({
    'idQuestion': dtoQuestionId,
    if (order != null) 'order': order,
    if (forceDetach) 'forceDetach': true,  
  });
  final res = await _client.post(uri, headers: await _headers(), body: body);
  if (res.statusCode == 409) {
    throw Conflict409Exception(res.body);
  }
  if (res.statusCode < 200 || res.statusCode >= 300) {
    throw Exception('POST /surveys/items/$listId/questions => ${res.statusCode}: ${res.body}');
  }
}

Future<void> addQuestionToListSafe({
  required int listId,
  required int dtoQuestionId,
  int? order,
}) async {
  try {
    await addQuestionToList(listId: listId, dtoQuestionId: dtoQuestionId, order: order, forceDetach: false);
  } on Conflict409Exception {
    await addQuestionToList(listId: listId, dtoQuestionId: dtoQuestionId, order: order, forceDetach: true);
  }
}


  Future<int> createQuestionList({
    required int questionId,
    String? listname, 
  }) async {
    final uri = Uri.parse('${Env.apiBaseUrl}/surveys/questions/$questionId/list');
    final body = <String, dynamic>{};
    if (listname != null && listname.trim().isNotEmpty) {
      body['listname'] = listname.trim();
    }

    final res = await _client.post(uri, headers: await _headers(), body: jsonEncode(body));

    if (res.statusCode == 409) {
      throw Conflict409Exception(res.body);
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('POST /surveys/questions/$questionId/list => ${res.statusCode}: ${res.body}');
    }

    if (res.body.isEmpty) {
      final location = res.headers['location'] ?? res.headers['Location'];
      if (location != null) {
        final match = RegExp(r'(\d+)$').firstMatch(location);
        if (match != null) return int.parse(match.group(1)!);
      }
      throw Exception('Respuesta vacía al crear lista (no se pudo extraer id)');
    }

    final decoded = jsonDecode(res.body);

    if (decoded is Map && decoded['id'] != null) {
      return _asInt(decoded['id'], fallback: -1);
    }
    if (decoded is Map && decoded['data'] is Map && decoded['data']['id'] != null) {
      return _asInt(decoded['data']['id'], fallback: -1);
    }
    if (decoded is Map && decoded['listId'] != null) {
      return _asInt(decoded['listId'], fallback: -1);
    }

    throw Exception('No se pudo resolver el listId tras crear la lista. Respuesta: ${res.body}');
  }

  Future<int> createQuestionListSafe({
    required int questionId,
    String? listname,
  }) async {
    try {
      return await createQuestionList(
        questionId: questionId,
        listname: listname,
      );
    } on Conflict409Exception {
      final id = await tryGetQuestionListId(questionId);
      if (id != null && id > 0) return id;
      throw Exception('409: la pregunta ya tiene lista pero no se pudo resolver su id');
    } catch (e) {
      final id = await tryGetQuestionListId(questionId);
      if (id != null && id > 0) return id;
      rethrow;
    }
  }

  Future<int> ensureQuestionList({
    required int questionId,
    String? listname,
  }) {
    return createQuestionListSafe(questionId: questionId, listname: listname);
  }

  Future<int?> tryGetQuestionListId(int questionId) async {
    try {
      final ext = await getQuestionExtended(questionId);
      final ql = ext['questionList'];
      if (ql is Map && ql['id'] != null) {
        return _asInt(ql['id'], fallback: -1);
      }
      if (ql != null) {
        final asInt = int.tryParse(ql.toString());
        if (asInt != null) return asInt;
      }
      if (ext['listId'] != null) {
        return _asInt(ext['listId'], fallback: -1);
      }
      if (ext['list'] is Map && (ext['list']['id'] != null)) {
        return _asInt(ext['list']['id'], fallback: -1);
      }
      return null;
    } catch (_) {
      return null;
    }
  }


  Future<List<Map<String, dynamic>>> searchLists({
    String? name,
    int page = 1,
    int limit = 100,
    String orderBy = 'name',
    String orderDir = 'ASC',
  }) async {
    final params = <String, String>{
      'page': '$page',
      'limit': '$limit',
      'orderBy': '$orderBy',
      'orderDir': '$orderDir',
    };
    if (name != null && name.trim().isNotEmpty) params['name'] = name.trim();

    final uri = Uri.parse('${Env.apiBaseUrl}/catalog/items')
        .replace(queryParameters: params);

    final res = await _client.get(uri, headers: await _headers());
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('GET /catalog/items => ${res.statusCode}: ${res.body}');
    }

    final decoded = jsonDecode(res.body);

    final List raw = (decoded is Map && decoded['data'] is List)
        ? decoded['data'] as List
        : (decoded is List ? decoded : const []);

    return raw.whereType<Map>().map((m) {
      final mm = Map<String, dynamic>.from(m);
      final id = (mm['id'] as num?)?.toInt();
      final name = (mm['name'] ?? mm['listname'] ?? mm['listName'] ?? '').toString();
      return {
        'id': id,
        'name': name,
        ...mm,
      };
    }).toList();
  }

  Future<SurveysSearchResult> searchByType({
    required int type,
    int page = 1,
    int limit = 50,
    String orderBy = 'id',
    String orderDir = 'DESC',
  }) {
    return search(page: page, limit: limit, orderBy: orderBy, orderDir: orderDir, type: type);
  }


Future<Map<String, dynamic>> attachQuestionsCow({
  required int surveyId,
  required int sectionId,
  required List<int> questionIds,
  int? insertAfterOrder,
}) async {
  final uri = Uri.parse('${Env.apiBaseUrl}/surveys/$surveyId/section/$sectionId/questions/attach');
  final res = await _client.post(
    uri,
    headers: await _headers(),
    body: jsonEncode({
      'questionIds': questionIds,
      if (insertAfterOrder != null) 'insertAfterOrder': insertAfterOrder,
    }),
  );
  if (res.statusCode >= 200 && res.statusCode < 300) {
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
  throw Exception('attachQuestionsCow failed: ${res.statusCode} ${res.body}');
}


Future<Map<String, dynamic>> createQuestionCow({
  required int surveyId,
  required int sectionId,
  required String name,
  int? targetOrder,
}) async {
  final uri = Uri.parse('${Env.apiBaseUrl}/surveys/$surveyId/section/$sectionId/questions');
  final res = await _client.post(
    uri,
    headers: await _headers(),
    body: jsonEncode({
      'name': name,
      if (targetOrder != null) 'targetOrder': targetOrder,
    }),
  );
  if (res.statusCode >= 200 && res.statusCode < 300) {
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
  throw Exception('createQuestionCow failed: ${res.statusCode} ${res.body}');
}


Future<Map<String, dynamic>> detachQuestionCow({
  required int surveyId,
  required int sectionId,
  required int questionId,
}) async {
  final uri = Uri.parse('${Env.apiBaseUrl}/surveys/$surveyId/section/$sectionId/questions/$questionId');
  final res = await _client.delete(uri, headers: await _headers());
  if (res.statusCode >= 200 && res.statusCode < 300) {
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
  throw Exception('detachQuestionCow failed: ${res.statusCode} ${res.body}');
}


Future<Map<String, dynamic>> detachSection({
  required int surveyId,
  required int sectionId,
}) async {
  final uri = Uri.parse('${Env.apiBaseUrl}/surveys/$surveyId/sections/$sectionId');
  final res = await _client.delete(uri, headers: await _headers());
  if (res.statusCode >= 200 && res.statusCode < 300) {
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
  throw Exception('detachSection failed: ${res.statusCode} ${res.body}');
}


}
