import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tfg_app2/features/users/data/users_repository.dart'
    as users_repo;
import 'package:tfg_app2/features/users/data/user_model.dart';
import 'package:tfg_app2/core/http/dio_client.dart';
import 'package:dio/dio.dart' show Options, ResponseType;
import 'package:tfg_app2/core/auth/auth_repository.dart';

class MyProfilePage extends StatefulWidget {
  const MyProfilePage({
    super.key,
    this.showPatientEvaluations = false,
    this.showLogoutInAppBar = false,
  });

  final bool showPatientEvaluations;

  final bool showLogoutInAppBar;

  @override
  State<MyProfilePage> createState() => _MyProfilePageState();
}

class _MyProfilePageState extends State<MyProfilePage> {
  final _usersRepo = users_repo.UsersRepository();
  late Future<AppUser> _fut;

  final _pwdCtrl = TextEditingController();
  bool _savingPwd = false;

  final _authRepo = AuthRepository();
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    _fut = _usersRepo.getMe();
  }

  @override
  void dispose() {
    _pwdCtrl.dispose();
    _usersRepo.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _fut = _usersRepo.getMe());
  }

  Future<void> _changePassword() async {
    final newPwd = _pwdCtrl.text.trim();
    if (newPwd.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La contraseña debe tener al menos 8 caracteres'),
        ),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _savingPwd = true);
    try {
      await _usersRepo.changeMyPassword(newPwd);
      if (!mounted) return;
      _pwdCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraseña actualizada')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cambiar contraseña: $e')),
      );
    } finally {
      if (mounted) setState(() => _savingPwd = false);
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Cerrar sesión'),
            content: const Text(
              '¿Seguro que quieres cerrar sesión en esta aplicación?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Cerrar sesión'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    setState(() => _loggingOut = true);
    try {
      await _authRepo.logout();
      if (!mounted) return;
      context.go('/login');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cerrar sesión: $e')),
      );
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi perfil'),
        automaticallyImplyLeading: !widget.showLogoutInAppBar,
        leading: widget.showLogoutInAppBar
            ? null
            : IconButton(
                tooltip: 'Atrás',
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).maybePop();
                  } else {
                    context.go('/role');
                  }
                },
              ),
        actions: [
          if (widget.showLogoutInAppBar)
            IconButton(
              tooltip: 'Cerrar sesión',
              icon: _loggingOut
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.logout),
              onPressed: _loggingOut ? null : _logout,
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
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

              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          child: Text(
                            (u.name.isNotEmpty ? u.name[0] : '?')
                                .toUpperCase(),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nombre,
                                style: t.textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 6),
                              Text('DNI: ${u.dni}'),
                              if ((u.mail ?? '').isNotEmpty)
                                Text('Email: ${u.mail}'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _sectionCard(
                      title: 'Datos personales',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _kv('Nombre', u.name),
                          _kv('1º apellido', u.lastName1),
                          _kv('2º apellido', u.lastName2 ?? '—'),
                          _kv('DNI', u.dni),
                          _kv('Email', u.mail ?? '—'),
                          _kv('Teléfono', u.phone ?? '—'),
                          _kv('Nacimiento', u.birthday ?? '—'),
                          _kv('Validado', u.isValidate ? 'Sí' : 'No'),
                          _kv(
                            'Alta',
                            u.dateInsert?.toLocal().toString() ?? '—',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    _sectionCard(
                      title: 'Roles',
                      child: _kv(
                        'Asignados',
                        roles.isNotEmpty ? roles : '—',
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (widget.showPatientEvaluations && u.roles.patient) ...[
                      _sectionCard(
                        title: 'Mis evaluaciones',
                        child: _MyEvaluationsCard(patientId: u.id),
                      ),
                      const SizedBox(height: 16),
                    ],

                    _sectionCard(
                      title: 'Cambiar contraseña',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Introduce tu nueva contraseña (mínimo 8 caracteres).',
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: 360,
                            child: TextField(
                              controller: _pwdCtrl,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Nueva contraseña',
                                border: OutlineInputBorder(),
                              ),
                              onSubmitted: (_) => _changePassword(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed:
                                _savingPwd ? null : _changePassword,
                            icon: _savingPwd
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.lock_reset_outlined,
                                  ),
                            label: const Text(
                              'Actualizar contraseña',
                            ),
                          ),
                        ],
                      ),
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

  Widget _sectionCard({
    required String title,
    required Widget child,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            child,
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
          SizedBox(
            width: 220,
            child: Text(
              k,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }
}

class _MyEvaluationsCard extends StatefulWidget {
  final int patientId;
  const _MyEvaluationsCard({required this.patientId});

  @override
  State<_MyEvaluationsCard> createState() => _MyEvaluationsCardState();
}

class _MyEvaluationsCardState extends State<_MyEvaluationsCard> {
  late Future<List<_EvalRow>> _future;
  final _detailsCache = <int, _EvalDetails>{};

  @override
  void initState() {
    super.initState();
    _future = _fetchList();
  }

  Future<List<_EvalRow>> _fetchList() async {
    final dio = DioClient().dio;
    final res =
        await dio.get('/evaluations/patient/${widget.patientId}');
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

  int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  DateTime _asDate(dynamic v1, dynamic v2) {
    final s = (v1 ?? v2)?.toString();
    final parsed =
        (s == null) ? null : DateTime.tryParse(s.replaceFirst(' ', 'T'));
    return parsed ?? DateTime.now();
  }

  Future<_EvalDetails> _loadDetails(int evaluationId) async {
    if (_detailsCache.containsKey(evaluationId)) {
      return _detailsCache[evaluationId]!;
    }

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

      final surveyName = s(root['surveyName'] ??
          root['formName'] ??
          root['survey'] ??
          root['name']);
      final surveyType =
          n(root['surveyType'] ?? root['type'] ?? root['formType']);
      final typeLabel = (surveyType == 0)
          ? 'Historia'
          : (surveyType == 1)
              ? 'Revisión'
              : '—';
      final tutorName = s(root['tutorName'] ??
          root['revisorName'] ??
          root['reviewerName'] ??
          root['userName']);

      return _EvalDetails(
        surveyName: surveyName,
        tutorName: tutorName,
        typeLabel: typeLabel,
      );
    }

    final details = await _fromView();
    _detailsCache[evaluationId] = details;
    return details;
  }

  Future<void> _exportCsv(int evaluationId) async {
    final dio = DioClient().dio;
    await dio.get(
      '/evaluations/$evaluationId/export.csv',
      options: Options(responseType: ResponseType.bytes),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Exportación solicitada. Revisa las descargas del navegador.',
        ),
      ),
    );
  }

  void _openViewer(int evaluationId) {
    context.push('/patient/evaluations/$evaluationId');
  }

  @override
  Widget build(BuildContext context) {
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
          return Text(
            'Error cargando evaluaciones: ${snap.error}',
          );
        }
        final rows = snap.data ?? const [];

        if (rows.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Todavía no tienes evaluaciones registradas.',
            ),
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
              final dateText =
                  r.date.toLocal().toString().replaceFirst('T', ' ');
              return DataRow(
                cells: [
                  DataCell(Text(dateText)),
                  DataCell(
                    _CellDetails(
                      evaluationId: r.id,
                      load: () => _loadDetails(r.id),
                      selector: (d) => d.surveyName ?? '—',
                      onTap: () => _openViewer(r.id),
                    ),
                  ),
                  DataCell(
                    _CellDetails(
                      evaluationId: r.id,
                      load: () => _loadDetails(r.id),
                      selector: (d) => d.typeLabel ?? '—',
                      onTap: () => _openViewer(r.id),
                    ),
                  ),
                  DataCell(
                    _CellDetails(
                      evaluationId: r.id,
                      load: () => _loadDetails(r.id),
                      selector: (d) => d.tutorName ?? '—',
                      onTap: () => _openViewer(r.id),
                    ),
                  ),
                  DataCell(
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Ver',
                          icon: const Icon(
                            Icons.visibility_outlined,
                          ),
                          onPressed: () => _openViewer(r.id),
                        ),
                        IconButton(
                          tooltip: 'Exportar CSV',
                          icon: const Icon(
                            Icons.download_outlined,
                          ),
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
        if (s.hasError) return const Text('—');
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
