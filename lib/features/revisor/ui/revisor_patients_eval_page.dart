import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../users/data/users_repository.dart';
import '../../users/data/user_model.dart';
import '../../groups/data/groups_repository.dart';
import '../../groups/data/group_model.dart';
import '../../evaluations/data/evaluations_repository.dart';

class RevisorPatientsEvalPage extends StatefulWidget {
  const RevisorPatientsEvalPage({super.key});

  @override
  State<RevisorPatientsEvalPage> createState() =>
      _RevisorPatientsEvalPageState();
}

class _RevisorPatientsEvalPageState extends State<RevisorPatientsEvalPage> {
  final _users = UsersRepository();
  final _groups = GroupsRepository();
  final _evals = EvaluationsRepository();

  bool _loading = true;
  String? _error;

  AppUser? _me;

  final Map<int, GroupMember> _patientsById = {};
  final Map<int, Group> _groupByPatientId = {};

  final TextEditingController _q = TextEditingController();

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _users.dispose();
    _groups.dispose();
    _q.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final me = await _users.getMe();

      final patients = <int, GroupMember>{};
      final groupByPid = <int, Group>{};

      var page = 1;
      const limit = 50;

      while (true) {
        final list = await _groups.list(page: page, limit: limit);
        if (list.items.isEmpty) break;

        for (final g in list.items) {
          final members = await _groups.getMembers(g.id);
          final isMyGroup = members.revisores.any((r) => r.id == me.id);
          if (!isMyGroup) continue;

          for (final p in members.pacientes) {
            patients[p.id] = p;
            groupByPid.putIfAbsent(p.id, () => g);
          }
        }

        if (page >= list.pages) break;
        page++;
      }

      if (!mounted) return;
      setState(() {
        _me = me;
        _patientsById
          ..clear()
          ..addAll(patients);
        _groupByPatientId
          ..clear()
          ..addAll(groupByPid);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  List<GroupMember> _filtered() {
    final all = _patientsById.values.toList();

    all.sort((a, b) {
      final aLast = (a.apellidos ?? '').toLowerCase();
      final bLast = (b.apellidos ?? '').toLowerCase();
      final c = aLast.compareTo(bLast);
      if (c != 0) return c;
      return (a.nombre ?? '')
          .toLowerCase()
          .compareTo((b.nombre ?? '').toLowerCase());
    });

    final qq = _q.text.trim().toLowerCase();
    if (qq.isEmpty) return all;

    bool contains(GroupMember u, String q) {
      final full = [
        u.nombre ?? '',
        u.apellidos ?? '',
        u.dni ?? '',
        u.email ?? '',
      ].join(' ').toLowerCase();
      return full.contains(q);
    }

    return all.where((u) => contains(u, qq)).toList();
  }

  Future<void> _openEvaluate(int patientId) async {
    final group = _groupByPatientId[patientId];
    if (group == null) {
      _showSnack('Este paciente no comparte grupo contigo.');
      return;
    }

    try {
      final history = await _evals.listByPatient(patientId);
      final bool firstTime = history.isEmpty;

      final surveyId = firstTime ? group.story : group.revision;
      if (surveyId == null) {
        _showSnack(firstTime
            ? 'El grupo no tiene Historia asignada.'
            : 'El grupo no tiene Revisión asignada.');
        return;
      }

      if (!mounted) return;
      context.push('/revisor/run/$patientId/$surveyId');
    } catch (e) {
      _showSnack('No se pudieron consultar evaluaciones del paciente: $e');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    Widget body() {
      if (_loading) {
        return const Center(child: CircularProgressIndicator());
      }
      if (_error != null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Error: $_error'),
          ),
        );
      }
      if (_patientsById.isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('No hay pacientes en tus grupos.'),
          ),
        );
      }

      var items = _filtered();

      final me = _me;
      if (me != null) {
        items = items.where((u) {
          final sameEmail = (u.email != null &&
              me.mail != null &&
              u.email == me.mail);
          final sameDni = (u.dni != null &&
              me.dni != null &&
              u.dni == me.dni);
          return !sameEmail && !sameDni;
        }).toList();
      }

      return ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final u = items[i];
          final full = u.displayName;
          final g = _groupByPatientId[u.id];

          return ListTile(
            leading:
                const CircleAvatar(child: Icon(Icons.person_outline)),
            title: Text(full),
            subtitle: Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                if ((u.email ?? '').isNotEmpty) Text(u.email!),
                if ((u.dni ?? '').isNotEmpty) Text('DNI: ${u.dni}'),
                if (g != null &&
                    (g.storyName ?? g.story?.toString()) != null)
                  Text('Historia: ${g.storyName ?? g.story}'),
                if (g != null &&
                    (g.revisionName ?? g.revision?.toString()) != null)
                  Text('Revisión: ${g.revisionName ?? g.revision}'),
              ],
            ),
            trailing: FilledButton.icon(
              onPressed: () => _openEvaluate(u.id),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Evaluar'),
            ),
            onTap: () => _openEvaluate(u.id),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Evaluar pacientes'),
        actions: [
          IconButton(
            onPressed: _bootstrap,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _q,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText:
                    'Buscar por nombre, apellidos, DNI o email…',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(child: body()),
        ],
      ),
    );
  }
}
