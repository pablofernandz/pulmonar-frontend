import 'dart:convert';

enum SurveyType { history, revision;

  static SurveyType? fromNum(dynamic v) {
    final n = (v is num) ? v.toInt() : int.tryParse('$v');
    if (n == 0) return SurveyType.history;
    if (n == 1) return SurveyType.revision;
    return null;
  }

  int get asInt => this == SurveyType.history ? 0 : 1;

  String get label => this == SurveyType.history ? 'Historia' : 'Revisión';
}

class SurveyListItem {
  final int id;
  final String name;
  final SurveyType? type;
  final DateTime? dateInsert;
  final DateTime? dateUpdate;

  const SurveyListItem({
    required this.id,
    required this.name,
    required this.type,
    required this.dateInsert,
    required this.dateUpdate,
  });

  factory SurveyListItem.fromJson(Map<String, dynamic> json) {
    DateTime? dt(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      final s = v.toString().replaceFirst(' ', 'T');
      return DateTime.tryParse(s);
    }

    return SurveyListItem(
      id: (json['id'] as num).toInt(),
      name: (json['name'] ?? '').toString(),
      type: SurveyType.fromNum(json['type']),
      dateInsert: dt(json['date_insert']),
      dateUpdate: dt(json['date_update']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type?.asInt,
        'date_insert': dateInsert?.toIso8601String(),
        'date_update': dateUpdate?.toIso8601String(),
      };
}

class SurveysSearchMeta {
  final int page;
  final int limit;
  final int totalItems;
  final int totalPages;
  final bool hasNext;
  final String? orderBy;
  final String? orderDir;

  const SurveysSearchMeta({
    required this.page,
    required this.limit,
    required this.totalItems,
    required this.totalPages,
    required this.hasNext,
    this.orderBy,
    this.orderDir,
  });

  factory SurveysSearchMeta.fromJson(Map<String, dynamic> json) => SurveysSearchMeta(
        page: (json['page'] as num?)?.toInt() ?? 1,
        limit: (json['limit'] as num?)?.toInt() ?? 20,
        totalItems: (json['totalItems'] as num?)?.toInt() ?? (json['total'] as num?)?.toInt() ?? 0,
        totalPages: (json['totalPages'] as num?)?.toInt() ?? (json['pages'] as num?)?.toInt() ?? 1,
        hasNext: json['hasNext'] == true,
        orderBy: (json['orderBy'] ?? json['sort'])?.toString(),
        orderDir: (json['orderDir'] ?? json['order'])?.toString(),
      );
}

class SurveysSearchResult {
  final List<SurveyListItem> items;
  final SurveysSearchMeta meta;

  const SurveysSearchResult({required this.items, required this.meta});

  factory SurveysSearchResult.fromJson(Map<String, dynamic> json) {
    final raw = (json['data'] as List?) ?? const [];
    final items = raw.whereType<Map>().map((m) => SurveyListItem.fromJson(m.cast<String, dynamic>())).toList();
    final metaMap = (json['meta'] as Map?)?.cast<String, dynamic>() ?? const {};
    return SurveysSearchResult(
      items: items,
      meta: SurveysSearchMeta.fromJson(metaMap),
    );
  }
}

class SurveySectionNode {
  final int id;
  final String name;
  final int order;
  final List<SurveyQuestionNode> questions;

  final String? questionOptional;

  SurveySectionNode({
    required this.id,
    required this.name,
    required this.order,
    required this.questions,
    this.questionOptional,
  });

  factory SurveySectionNode.fromJson(Map<String, dynamic> json) => SurveySectionNode(
        id: (json['id'] as num).toInt(),
        name: (json['name'] ?? '').toString(),
        order: (json['order'] as num?)?.toInt() ?? 0,
        questions: ((json['questions'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => SurveyQuestionNode.fromJson(m.cast<String, dynamic>()))
            .toList(),
        questionOptional: (() {
          final raw = json['question_optional'];
          final s = raw?.toString().trim();
          return (s == null || s.isEmpty) ? null : s;
        })(),
      );
}


class SurveyQuestionNode {
  final int id;
  final String name;
  final int order;

  SurveyQuestionNode({required this.id, required this.name, required this.order});

  factory SurveyQuestionNode.fromJson(Map<String, dynamic> json) => SurveyQuestionNode(
        id: (json['id'] as num).toInt(),
        name: (json['name'] ?? '').toString(),
        order: (json['order'] as num?)?.toInt() ?? 0,
      );
}

class SurveyTree {
  final int id;
  final String name;
  final List<SurveySectionNode> sections;

  SurveyTree({required this.id, required this.name, required this.sections});

  factory SurveyTree.fromJson(Map<String, dynamic> json) => SurveyTree(
        id: (json['id'] as num).toInt(),
        name: (json['name'] ?? '').toString(),
        sections: ((json['sections'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => SurveySectionNode.fromJson(m.cast<String, dynamic>()))
            .toList(),
      );
}
