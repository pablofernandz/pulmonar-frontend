import 'package:flutter/material.dart';
import 'package:tfg_app2/features/users/data/users_repository.dart' as repo;
import 'package:tfg_app2/features/users/data/user_model.dart';
import 'package:tfg_app2/main.dart';

import 'widgets/users_groups_card.dart';

import 'widgets/user_roles_editor.dart';
import 'widgets/user_groups_editor.dart';

import 'package:tfg_app2/core/http/dio_client.dart';

class UserDetailPage extends StatefulWidget {
  final int userId;
  const UserDetailPage({super.key, required this.userId});

  @override
  State<UserDetailPage> createState() => _UserDetailPageState();
}

class _UserDetailPageState extends State<UserDetailPage> {
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

  Future<void> _refetch() async {
    setState(() {
      _fut = _repo.getUser(widget.userId);
    });
  }

  Future<void> _openEditMenu() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: const Text('Editar roles'),
              onTap: () => Navigator.of(ctx).pop('roles'),
            ),
            ListTile(
              leading: const Icon(Icons.groups_outlined),
              title: const Text('Editar grupos'),
              onTap: () => Navigator.of(ctx).pop('groups'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (choice == null) return;

    if (choice == 'roles') {
      final u = await _repo.getUser(widget.userId);
      final didSave = await showDialog<bool>(
        context: context,
        builder: (_) => UserRolesEditor(
          userId: u.id,
          current: u.roles,
        ),
      );
      if (didSave == true) {
        await _refetch();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Roles actualizados')),
        );
      }
      return;
    }

    if (choice == 'groups') {
      int? patientId;
      List<int> revisorIds = const [];
      bool showPatient = false;
      bool showRevisor = false;

      try {
        final dio = DioClient().dio;
        final res = await dio.get('/users/${widget.userId}');
        final data = (res.data as Map).cast<String, dynamic>();

        final roles = (data['roles'] as Map?)?.cast<String, dynamic>() ?? const {};
        bool asBool(dynamic v) =>
            v is bool ? v : v is num ? v != 0 : (v?.toString().toLowerCase() == 'true' || v?.toString() == '1');
        showPatient = asBool(roles['patient']);
        showRevisor = asBool(roles['revisor']);

        final groups = (data['groups'] as Map?)?.cast<String, dynamic>() ?? const {};
        final asPatient = (groups['asPatient'] as List?) ?? const [];
        if (asPatient.isNotEmpty) {
          final first = (asPatient.first as Map).cast<String, dynamic>();
          final pid = first['id'];
          if (pid is num) patientId = pid.toInt();
        }
        final asRevisor = (groups['asRevisor'] as List?) ?? const [];
        revisorIds = asRevisor
            .whereType<Map>()
            .map((m) => (m as Map).cast<String, dynamic>()['id'])
            .whereType<num>()
            .map((n) => n.toInt())
            .toList(growable: false);
      } catch (_) {
      }

      final didSave = await showDialog<bool>(
        context: context,
        builder: (_) => UserGroupsEditor(
          userId: widget.userId,
          showPatientSection: showPatient,
          showRevisorSection: showRevisor,
          patientGroupId: patientId,
          revisorGroupIds: revisorIds,
        ),
      );

      if (didSave == true) {
        await _refetch();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Grupos actualizados')),
        );
      }
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Usuario #${widget.userId}'),
        actions: [
          IconButton(
            tooltip: 'Editar',
            onPressed: _openEditMenu,
            icon: const Icon(Icons.edit_outlined),
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

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
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
                              Text('DNI: ${u.dni}'),
                              if ((u.mail ?? '').isNotEmpty) Text('Email: ${u.mail}'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
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
                        UserGroupsCard(userId: u.id),
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