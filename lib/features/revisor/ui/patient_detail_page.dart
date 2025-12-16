import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:tfg_app2/features/users/data/users_repository.dart' as repo;
import 'package:tfg_app2/features/users/data/user_model.dart';

import 'package:tfg_app2/core/http/dio_client.dart';
import 'package:dio/dio.dart' show Options, ResponseType;


class RevisorPatientDetailPage extends StatefulWidget {
  final int userId; 
  const RevisorPatientDetailPage({super.key, required this.userId});

  @override
  State<RevisorPatientDetailPage> createState() => _RevisorPatientDetailPageState();
}

class _RevisorPatientDetailPageState extends State<RevisorPatientDetailPage> {
  final _repo = repo.UsersRepository();
  late Future<AppUser> _fut;

  @override
  void initState() {
    super.initState();
    _fut = _repo.getUser(widget.userId);
  }

  @override
  void dispose() {
    _repo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Paciente #${widget.userId}'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: FutureBuilder<AppUser>(
            future: _fut,
            builder: (_, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                );
              }
              if (snap.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Error: ${snap.error}'),
                );
              }
              final u = snap.data!;
              final nombre = [
                u.name,
                u.lastName1,
                if ((u.lastName2 ?? '').isNotEmpty) u.lastName2!,
              ].join(' ');
              final roles = <String>[
                if (u.roles.patient) 'Paciente',
                if (u.roles.revisor) 'Revisor/Tutor',
                if (u.roles.coordinator) 'Coordinador/Investigador',
              ].join(' · ');

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 28,
                              child: Text((u.name.isNotEmpty ? u.name[0] : '?').toUpperCase()),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(nombre, style: t.textTheme.headlineSmall),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 4,
                                    children: [
                                      Text('DNI: ${u.dni}'),
                                      if ((u.mail ?? '').isNotEmpty) Text('Email: ${u.mail}'),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    _section(
                      title: 'Datos personales',
                      children: [
                        _kv('Nombre', u.name),
                        _kv('1º apellido', u.lastName1),
                        _kv('2º apellido', u.lastName2 ?? '—'),
                        _kv('DNI', u.dni),
                        _kv('Email', u.mail ?? '—'),
                        _kv('Teléfono', u.phone ?? '—'),
                        _kv('Nacimiento', u.birthday ?? '—'),
                        _kv('Validado', u.isValidate ? 'Sí' : 'No'),
                        _kv('Alta', u.dateInsert?.toLocal().toString() ?? '—'),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _section(
                      title: 'Roles',
                      children: [
                        _kv('Asignados', roles.isNotEmpty ? roles : '—'),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _section(
                      title: 'Grupos',
                      children: [
                        _ReadOnlyUserGroupsCard(userId: u.id),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _section(
                      title: 'Evaluaciones',
                      children: [
                        _EvaluationsCard(patientId: u.id),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _section({required String title, required List<Widget> children}) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 220, child: Text(k, style: const TextStyle(fontWeight: FontWeight.w500))),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }
}

class _ReadOnlyUserGroupsCard extends StatefulWidget {
  final int userId;
  const _ReadOnlyUserGroupsCard({required this.userId});

  @override
  State<_ReadOnlyUserGroupsCard> createState() => _ReadOnlyUserGroupsCardState();
}

class _ReadOnlyUserGroupsCardState extends State<_ReadOnlyUserGroupsCard> {
  late Future<_UserGroups> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  Future<_UserGroups> _fetch() async {
    final dio = DioClient().dio;
    final res = await dio.get('/users/${widget.userId}');
    final data = (res.data as Map).cast<String, dynamic>();

    final groups = (data['groups'] as Map?)?.cast<String, dynamic>() ?? const {};
    final asPatientList = (groups['asPatient'] as List?) ?? const [];
    final asRevisorList = (groups['asRevisor'] as List?) ?? const [];

    List<_MiniGroup> parseList(List raw) => raw.map<_MiniGroup>((e) {
          final m = (e as Map).cast<String, dynamic>();
          final id = (m['id'] is num) ? (m['id'] as num).toInt() : int.tryParse('${m['id']}') ?? 0;
          final name = (m['name'] ?? 'Grupo $id').toString();
          return _MiniGroup(id: id, name: name);
        }).toList(growable: false);

    return _UserGroups(
      patientGroups: parseList(asPatientList),
      revisorGroups: parseList(asRevisorList),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_UserGroups>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (snap.hasError) {
          return Text('Error cargando grupos: ${snap.error}');
        }
        final g = snap.data!;
        final hasPatient = g.patientGroups.isNotEmpty;
        final hasRevisor = g.revisorGroups.isNotEmpty;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Como paciente', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            if (!hasPatient)
              Text('—', style: Theme.of(context).textTheme.bodyMedium)
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _GroupChipReadOnly(group: g.patientGroups.first),
                  if (g.patientGroups.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Aviso: hay ${g.patientGroups.length} grupos; debería existir solo uno activo.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.orange[800]),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 16),
            Text('Como tutor', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            if (!hasRevisor)
              Text('—', style: Theme.of(context).textTheme.bodyMedium)
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: g.revisorGroups.map((gr) => _GroupChipReadOnly(group: gr)).toList(),
              ),
          ],
        );
      },
    );
  }
}

class _GroupChipReadOnly extends StatelessWidget {
  final _MiniGroup group;
  const _GroupChipReadOnly({required this.group});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.group_outlined, size: 18),
        const SizedBox(width: 8),
        Text(group.name),
      ]),
    );
  }
}

class _UserGroups {
  final List<_MiniGroup> patientGroups;
  final List<_MiniGroup> revisorGroups;
  const _UserGroups({required this.patientGroups, required this.revisorGroups});
}

class _MiniGroup {
  final int id;
  final String name;
  const _MiniGroup({required this.id, required this.name});
}

class _EvaluationsCard extends StatefulWidget {
  final int patientId;
  const _EvaluationsCard({required this.patientId});

  @override
  State<_EvaluationsCard> createState() => _EvaluationsCardState();
}

class _EvaluationsCardState extends State<_EvaluationsCard> {
  late Future<List<_EvalRow>> _future;
  final _detailsCache = <int, _EvalDetails>{};

  @override
  void initState() {
    super.initState();
    _future = _fetchList();
  }

  int _asInt(dynamic v) {
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  DateTime _asDate(dynamic v1, dynamic v2) {
    final s = (v1 ?? v2)?.toString();
    final parsed = (s == null) ? null : DateTime.tryParse(s.replaceFirst(' ', 'T'));
    return parsed ?? DateTime.now();
  }

  Future<List<_EvalRow>> _fetchList() async {
    final dio = DioClient().dio;
    final res = await dio.get('/evaluations/patient/${widget.patientId}');
    final data = (res.data as Map).cast<String, dynamic>();

    final items = (data['items'] as List?) ?? const [];

    final rows = items.whereType<Map>().map((m) {
      final mm = m.cast<String, dynamic>();
      final id = _asInt(mm['id']);
      final date = _asDate(mm['date'], mm['date_insert']);
      return _EvalRow(
        id: id,
        date: date,
        surveyName: null,
        tutorName: null,
        typeLabel: null,
      );
    }).toList();

    return rows;
  }

Future<_EvalDetails> _loadDetails(int evaluationId) async {
  if (_detailsCache.containsKey(evaluationId)) return _detailsCache[evaluationId]!;

  final dio = DioClient().dio;

  String? s(dynamic v) => v?.toString();
  int? n(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  Future<_EvalDetails> _fromView() async {
    final res = await dio.get('/evaluations/$evaluationId/view');
    final root = res.data;

    final surveyName = s(root['surveyName'] ?? root['formName'] ?? root['survey'] ?? root['name']);
    final surveyType = n(root['surveyType'] ?? root['type'] ?? root['formType']);
    final typeLabel = (surveyType == 0)
        ? 'Historia'
        : (surveyType == 1)
            ? 'Revisión'
            : '—';
    final tutorName = s(root['tutorName'] ?? root['revisorName'] ?? root['reviewerName'] ?? root['userName']);

    return _EvalDetails(
      surveyName: surveyName,
      typeLabel: typeLabel,
      tutorName: tutorName,
    );
  }

  Future<_EvalDetails> _fromBasic() async {
    final res = await dio.get('/evaluations/$evaluationId');
    final root = (res.data as Map).cast<String, dynamic>();

    final surveyName = s(root['surveyName'] ?? root['formName'] ?? root['survey'] ?? root['name']);
    final surveyType = n(root['surveyType'] ?? root['type'] ?? root['formType']);
    final typeLabel = (surveyType == 0)
        ? 'Historia'
        : (surveyType == 1)
            ? 'Revisión'
            : '—';
    final tutorName = s(root['tutorName'] ?? root['revisorName'] ?? root['reviewerName'] ?? root['userName']);

    return _EvalDetails(
      surveyName: surveyName,
      typeLabel: typeLabel,
      tutorName: tutorName,
    );
  }

  _EvalDetails details;
  try {
    details = await _fromView();
  } catch (e) {
    try {
      details = await _fromBasic();
    } catch (_) {
      details = _EvalDetails(surveyName: null, typeLabel: null, tutorName: null);
    }
  }

  _detailsCache[evaluationId] = details;
  return details;
}


  Future<void> _exportCsv(int evaluationId) async {
    final dio = DioClient().dio;
    final res = await dio.get(
      '/evaluations/$evaluationId/export.csv',
      options: Options(responseType: ResponseType.bytes),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Exportación solicitada. Revisa las descargas del navegador.')),
    );
  }

  void _openViewer(int evaluationId) {
    context.push('/revisor/evaluations/$evaluationId');
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return FutureBuilder<List<_EvalRow>>(
      future: _future,
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: LinearProgressIndicator(),
          );
        }
        if (snap.hasError) {
          return Text('Error cargando evaluaciones: ${snap.error}');
        }
        final rows = snap.data ?? const [];

        if (rows.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Este paciente no tiene evaluaciones.'),
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Fecha')),
              DataColumn(label: Text('Formulario')),
              DataColumn(label: Text('Tipo')),
              DataColumn(label: Text('Tutor')),
              DataColumn(label: Text('Acciones')),
            ],
            rows: rows.map((r) {
              final dateText = r.date.toLocal().toString().replaceFirst('T', ' ');
              return DataRow(
                cells: [
                  DataCell(Text(dateText)),
                  DataCell(_CellDetails(
                    evaluationId: r.id,
                    load: () => _loadDetails(r.id),
                    selector: (d) => d.surveyName ?? '—',
                    onTap: () => _openViewer(r.id),
                  )),
                  DataCell(_CellDetails(
                    evaluationId: r.id,
                    load: () => _loadDetails(r.id),
                    selector: (d) => d.typeLabel ?? '—',
                    onTap: () => _openViewer(r.id),
                  )),
                  DataCell(_CellDetails(
                    evaluationId: r.id,
                    load: () => _loadDetails(r.id),
                    selector: (d) => d.tutorName ?? '—',
                    onTap: () => _openViewer(r.id),
                  )),
                  DataCell(
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Ver',
                          icon: const Icon(Icons.visibility_outlined),
                          onPressed: () => _openViewer(r.id),
                        ),
                        IconButton(
                          tooltip: 'Exportar CSV',
                          icon: const Icon(Icons.download_outlined),
                          onPressed: () => _exportCsv(r.id),
                        ),
                      ],
                    ),
                  ),
                ],
                onSelectChanged: (_) => _openViewer(r.id),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class _CellDetails extends StatelessWidget {
  final int evaluationId;
  final Future<_EvalDetails> Function() load;
  final String? Function(_EvalDetails) selector;
  final VoidCallback onTap;
  const _CellDetails({
    required this.evaluationId,
    required this.load,
    required this.selector,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_EvalDetails>(
      future: load(),
      builder: (_, s) {
        if (s.connectionState != ConnectionState.done) {
          return const SizedBox(
            width: 120,
            child: LinearProgressIndicator(minHeight: 2),
          );
        }
        if (s.hasError) return Text('—');
        final d = s.data!;
        final text = selector(d) ?? '—';
        return InkWell(
          onTap: onTap,
          child: Text(text),
        );
      },
    );
  }
}

class _EvalRow {
  final int id;
  final DateTime date;
  final String? surveyName;
  final String? tutorName;
  final String? typeLabel;
  _EvalRow({
    required this.id,
    required this.date,
    this.surveyName,
    this.tutorName,
    this.typeLabel,
  });
}

class _EvalDetails {
  final String? surveyName;
  final String? tutorName;
  final String? typeLabel;
  _EvalDetails({
    required this.surveyName,
    required this.tutorName,
    required this.typeLabel,
  });
}
