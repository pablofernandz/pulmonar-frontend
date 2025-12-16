import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

import '../../../core/env.dart';
import '../../../core/auth/token_storage.dart';

class EvaluationItem {
  final int id;
  final DateTime date;
  final int idPatient;
  final int idSurvey;
  final String? surveyName;

  final String? tutorName;   
  final int? surveyType;     

  EvaluationItem({
    required this.id,
    required this.date,
    required this.idPatient,
    required this.idSurvey,
    this.surveyName,
    this.tutorName,
    this.surveyType,
  });

  String get typeLabel {
    if (surveyType == 0) return 'Historia';
    if (surveyType == 1) return 'Revisión';
    return '—';
  }

  factory EvaluationItem.fromJson(Map<String, dynamic> j) {
    int asInt(dynamic v, {int fallback = 0}) {
      if (v is num) return v.toInt();
      final s = v?.toString();
      return int.tryParse(s ?? '') ?? fallback;
    }

    DateTime asDate(dynamic v1, dynamic v2) {
      final s = (v1 ?? v2)?.toString();
      final parsed = (s == null) ? null : DateTime.tryParse(s.replaceFirst(' ', 'T'));
      return parsed ?? DateTime.now();
    }

    String? asStr(dynamic v) => v?.toString();

    return EvaluationItem(
      id: asInt(j['id']),
      date: asDate(j['date'], j['date_insert']),
      idPatient: asInt(j['idPatient'], fallback: asInt(j['patientId'])),
      idSurvey: asInt(j['idSurvey'], fallback: asInt(j['surveyId'])),
      surveyName: asStr(j['surveyName'] ?? j['formName'] ?? j['survey'] ?? j['name']),
      tutorName: asStr(j['tutorName'] ?? j['revisorName'] ?? j['reviewerName'] ?? j['userName']),
      surveyType: ((){
        final v = j['surveyType'] ?? j['type'] ?? j['formType'];
        if (v is num) return v.toInt();
        return int.tryParse(v?.toString() ?? '');
      })(),
    );
  }
}

class AnswerInput {
  final int idSection;
  final int idQuestion;       
  final int? idResponse;
  final int? idQuestionList;  
  final String? value;

  const AnswerInput({
    required this.idSection,
    required this.idQuestion,
    this.idResponse,
    this.idQuestionList,
    this.value,
  });

  Map<String, dynamic> toJson() => {
        'idSection': idSection,
        'idQuestion': idQuestion,
        if (idResponse != null) 'idResponse': idResponse,
        if (idQuestionList != null) 'idQuestionList': idQuestionList,
        if (value != null) 'value': value,
      };
}

class EvaluationsRepository {
  final http.Client _client;
  EvaluationsRepository({http.Client? client}) : _client = client ?? http.Client();

  Future<int> create({
    required int patientId,
    required int surveyId,
    int? idRevisor,
  }) async {
    final baseUrl = Env.apiBaseUrl;
    final token = await TokenStorage.instance.getToken();
    final uri = Uri.parse('$baseUrl/evaluations');

    final body = <String, dynamic>{
      'idPatient': patientId,
      'idSurvey':  surveyId,
      if (idRevisor != null) 'idRevisor': idRevisor,
    };

    final res = await _client.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (res.statusCode != 201 && res.statusCode != 200) {
      throw Exception('POST /evaluations => ${res.statusCode}: ${res.body}');
    }

    final j = jsonDecode(res.body) as Map<String, dynamic>;
    final id = (j['id'] as num?)?.toInt();
    if (id == null) throw Exception('POST /evaluations => respuesta sin id');
    return id;
  }

  Future<void> saveAnswers({
    required int evaluationId,
    required List<AnswerInput> answers,
  }) async {
    final baseUrl = Env.apiBaseUrl;
    final token = await TokenStorage.instance.getToken();
    final uri = Uri.parse('$baseUrl/evaluations/$evaluationId/answers');
    final res = await _client.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'answers': answers.map((a) => a.toJson()).toList(),
      }),
    );
    if (res.statusCode != 201 && res.statusCode != 200) {
      throw Exception('POST /evaluations/$evaluationId/answers => ${res.statusCode}: ${res.body}');
    }
  }

  Future<void> submit(int evaluationId) async {
    final baseUrl = Env.apiBaseUrl;
    final token = await TokenStorage.instance.getToken();
    final uri = Uri.parse('$baseUrl/evaluations/$evaluationId/submit');
    final res = await _client.post(uri, headers: {
      'Authorization': 'Bearer $token',
    });
    if (res.statusCode != 201 && res.statusCode != 200) {
      throw Exception('POST /evaluations/$evaluationId/submit => ${res.statusCode}: ${res.body}');
    }
  }

  Future<List<EvaluationItem>> listByPatient(int patientId) async {
    final baseUrl = Env.apiBaseUrl;
    final token = await TokenStorage.instance.getToken();
    final uri = Uri.parse('$baseUrl/evaluations/patient/$patientId');

    final res = await _client.get(uri, headers: {'Authorization': 'Bearer $token'});
    if (res.statusCode != 200) {
      throw Exception('GET /evaluations/patient/$patientId => ${res.statusCode}: ${res.body}');
    }

    final decoded = jsonDecode(res.body);

    List itemsRaw = const [];
    if (decoded is List) {
      itemsRaw = decoded;
    } else if (decoded is Map) {
      itemsRaw = (decoded['items'] as List?) ??
                 (decoded['data'] as List?) ??
                 const [];
    }

    return itemsRaw
        .whereType<Map>()
        .map((m) => EvaluationItem.fromJson(m.cast<String, dynamic>()))
        .toList();
  }

  Future<Map<String, dynamic>> view(int evaluationId) async {
    final baseUrl = Env.apiBaseUrl;
    final token = await TokenStorage.instance.getToken();
    final uri = Uri.parse('$baseUrl/evaluations/$evaluationId/view');
    final res = await _client.get(uri, headers: {'Authorization': 'Bearer $token'});
    if (res.statusCode != 200) {
      throw Exception('GET /evaluations/$evaluationId/view => ${res.statusCode}: ${res.body}');
    }
    return (jsonDecode(res.body) as Map).cast<String, dynamic>();
  }

  Future<Uint8List> exportCsvBytes(int evaluationId) async {
    final baseUrl = Env.apiBaseUrl;
    final token = await TokenStorage.instance.getToken();
    final uri = Uri.parse('$baseUrl/evaluations/$evaluationId/export.csv');
    final res = await _client.get(uri, headers: {
      'Authorization': 'Bearer $token',
      'Accept': 'text/csv, */*',
    });
    if (res.statusCode != 200) {
      throw Exception('GET /evaluations/$evaluationId/export.csv => ${res.statusCode}');
    }
    return res.bodyBytes;
  }

  void dispose() => _client.close();
}
