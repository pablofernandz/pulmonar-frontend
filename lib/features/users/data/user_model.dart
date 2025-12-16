import 'dart:convert';

class UserRoles {
  final bool patient;
  final bool revisor;
  final bool coordinator;

  const UserRoles({
    required this.patient,
    required this.revisor,
    required this.coordinator,
  });

  factory UserRoles.fromJson(Map<String, dynamic>? json) {
    final j = json ?? const {};
    bool asBool(dynamic v) {
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) return v == '1' || v.toLowerCase() == 'true';
      return false;
    }

    return UserRoles(
      patient: asBool(j['patient']),
      revisor: asBool(j['revisor']),
      coordinator: asBool(j['coordinator']),
    );
  }

  Map<String, dynamic> toJson() => {
        'patient': patient,
        'revisor': revisor,
        'coordinator': coordinator,
      };
}

class AppUser {
  final int id;
  final String name;
  final String lastName1;
  final String? lastName2;
  final String dni;
  final String? mail;
  final String? phone;
  final String? birthday;
  final bool isValidate;
  final DateTime? dateInsert;
  final UserRoles roles;

  const AppUser({
    required this.id,
    required this.name,
    required this.lastName1,
    this.lastName2,
    required this.dni,
    this.mail,
    this.phone,
    this.birthday,
    required this.isValidate,
    this.dateInsert,
    required this.roles,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    DateTime? parseDt(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      if (v is String && v.isNotEmpty) {
        final s = v.replaceFirst(' ', 'T');
        return DateTime.tryParse(s);
      }
      return null;
    }

    String str(dynamic v) => (v ?? '').toString();

    return AppUser(
      id: (json['id'] as num).toInt(),
      name: str(json['name']),
      lastName1: str(json['last_name_1']),
      lastName2: (json['last_name_2'] as String?)?.trim().isEmpty == true
          ? null
          : json['last_name_2'] as String?,
      dni: str(json['dni']),
      mail: (json['mail'] as String?)?.trim().isEmpty == true ? null : json['mail'] as String?,
      phone: (json['phone'] as String?)?.trim().isEmpty == true ? null : json['phone'] as String?,
      birthday: (json['birthday'] as String?)?.trim().isNotEmpty == true
          ? json['birthday'] as String
          : null,
      isValidate: (json['isValidate'] is bool)
          ? (json['isValidate'] as bool)
          : (json['isValidate'] is num)
              ? (json['isValidate'] as num) != 0
              : (json['isValidate']?.toString().toLowerCase() == 'true' ||
                  json['isValidate']?.toString() == '1'),
      dateInsert: parseDt(json['date_insert']),
      roles: UserRoles.fromJson(json['roles'] as Map<String, dynamic>?),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'last_name_1': lastName1,
        'last_name_2': lastName2,
        'dni': dni,
        'mail': mail,
        'phone': phone,
        'birthday': birthday,
        'isValidate': isValidate,
        'date_insert': dateInsert?.toIso8601String(),
        'roles': roles.toJson(),
      };
}

class UsersSearchResult {
  final List<AppUser> items;
  final int page;
  final int limit;
  final int total;
  final int pages;

  const UsersSearchResult({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
    required this.pages,
  });

  factory UsersSearchResult.fromJson(Map<String, dynamic> json) {
    List<dynamic> rawItems;
    int page, limit, total, pages;

    if (json.containsKey('data') && json.containsKey('meta')) {
      rawItems = (json['data'] as List?) ?? const [];
      final meta = json['meta'] as Map<String, dynamic>? ?? const {};
      page = (meta['page'] as num?)?.toInt() ?? 1;
      limit = (meta['limit'] as num?)?.toInt() ?? rawItems.length;
      total = (meta['total'] as num?)?.toInt() ?? rawItems.length;
      pages = (meta['pages'] as num?)?.toInt() ??
          ((limit > 0) ? ((total + limit - 1) ~/ limit) : 1);
    } else {
      rawItems = (json['items'] as List?) ?? const [];
      page = (json['page'] as num?)?.toInt() ?? 1;
      limit = (json['limit'] as num?)?.toInt() ?? rawItems.length;
      total = (json['total'] as num?)?.toInt() ?? rawItems.length;
      pages = (json['pages'] as num?)?.toInt() ??
          ((limit > 0) ? ((total + limit - 1) ~/ limit) : 1);
    }

    final users = rawItems
        .whereType<Map<String, dynamic>>()
        .map(AppUser.fromJson)
        .toList(growable: false);

    return UsersSearchResult(
      items: users,
      page: page,
      limit: limit,
      total: total,
      pages: pages,
    );
  }

  Map<String, dynamic> toJson() => {
        'items': items.map((e) => e.toJson()).toList(),
        'page': page,
        'limit': limit,
        'total': total,
        'pages': pages,
      };
}
