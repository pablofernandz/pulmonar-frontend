class Group {
  final int id;
  final String name;
  final int? story;
  final int? revision;
  final String? storyName;
  final String? revisionName;

  Group({
    required this.id,
    required this.name,
    this.story,
    this.revision,
    this.storyName,
    this.revisionName,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    int? asInt(dynamic v) => (v is num) ? v.toInt() : int.tryParse('${v ?? ''}');
    String? asStr(dynamic v) {
      final s = v?.toString().trim();
      return (s == null || s.isEmpty) ? null : s;
    }

    return Group(
      id: asInt(json['id']) ?? 0,
      name: (json['name'] ?? '').toString(),
      story: asInt(json['story']),
      revision: asInt(json['revision']),
      storyName: asStr(json['storyName']),
      revisionName: asStr(json['revisionName']),
    );
  }
}

class GroupsSearchResult {
  final List<Group> items;
  final int page;
  final int limit;
  final int total;
  final int pages;

  const GroupsSearchResult({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
    required this.pages,
  });

  factory GroupsSearchResult.fromJson(dynamic root) {
    List<dynamic> raw = const [];
    int page = 1, limit = 0, total = 0, pages = 1;

    if (root is List) {
      raw = root;
      limit = raw.length;
      total = raw.length;
      pages = 1;
    } else if (root is Map<String, dynamic>) {
      if (root.containsKey('data')) {
        raw = (root['data'] as List?) ?? const [];
        final meta = (root['meta'] as Map<String, dynamic>?) ?? const {};
        page = (meta['page'] as num?)?.toInt() ?? 1;
        limit = (meta['limit'] as num?)?.toInt() ?? raw.length;
        total = (meta['total'] as num?)?.toInt() ?? raw.length;
        pages = (meta['pages'] as num?)?.toInt() ??
            ((limit > 0) ? ((total + limit - 1) ~/ limit) : 1);
      } else {
        raw = (root['items'] as List?) ?? const [];
        page = (root['page'] as num?)?.toInt() ?? 1;
        limit = (root['limit'] as num?)?.toInt() ?? raw.length;
        total = (root['total'] as num?)?.toInt() ?? raw.length;
        pages = (root['pages'] as num?)?.toInt() ??
            ((limit > 0) ? ((total + limit - 1) ~/ limit) : 1);
      }
    }

    final items = raw
        .whereType<Map<String, dynamic>>()
        .map(Group.fromJson)
        .toList(growable: false);

    return GroupsSearchResult(
      items: items,
      page: page,
      limit: limit,
      total: total,
      pages: pages,
    );
  }
}

class GroupMember {
  final int id;
  final String? dni;      
  final String? nombre;
  final String? apellidos;
  final String? email;

  GroupMember({
    required this.id,
    this.dni,
    this.nombre,
    this.apellidos,
    this.email,
  });

  String get displayName {
    final n = (nombre ?? '').trim();
    final a = (apellidos ?? '').trim();
    final s = [n, a].where((x) => x.isNotEmpty).join(' ');
    return s.isEmpty ? 'Usuario ${id}' : s;
    }

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    int id = (json['id'] is num)
        ? (json['id'] as num).toInt()
        : int.tryParse('${json['id'] ?? 0}') ?? 0;

    return GroupMember(
      id: id,
      dni: (json['nif'] ?? json['dni'])?.toString(),
      nombre: (json['nombre'] ?? json['name'])?.toString(),
      apellidos: (json['apellidos'] ?? json['last_name_1'])?.toString(),
      email: (json['mail'] ?? json['email'])?.toString(),
    );
  }
}

class GroupMembersResponse {
  final Group group;
  final List<GroupMember> pacientes;
  final List<GroupMember> revisores;

  GroupMembersResponse({
    required this.group,
    required this.pacientes,
    required this.revisores,
  });

  factory GroupMembersResponse.fromJson(Map<String, dynamic> json) {
    final group = Group.fromJson(json['group'] as Map<String, dynamic>);

    final pList = (json['pacientes'] ?? json['patients']) as List? ?? const [];
    final rList = (json['revisores'] ?? json['revisors']) as List? ?? const [];

    return GroupMembersResponse(
      group: group,
      pacientes: pList.whereType<Map<String, dynamic>>().map(GroupMember.fromJson).toList(),
      revisores: rList.whereType<Map<String, dynamic>>().map(GroupMember.fromJson).toList(),
    );
  }
}
