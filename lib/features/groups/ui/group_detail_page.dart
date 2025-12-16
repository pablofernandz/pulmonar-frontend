import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/groups_repository.dart';
import '../data/group_model.dart';

import 'widgets/group_surveys_editor.dart';

class GroupDetailPage extends StatefulWidget {
  final int id;
  const GroupDetailPage({super.key, required this.id});

  @override
  State<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends State<GroupDetailPage> {
  final _repo = GroupsRepository();
  late Future<GroupMembersResponse> _fut;

  @override
  void initState() {
    super.initState();
    _fut = _repo.getMembers(widget.id);
  }

  Future<void> _refresh() async {
    setState(() {
      _fut = _repo.getMembers(widget.id);
    });
  }

  Future<void> _editSurveys() async {
    try {
      final data = await _fut;

      final saved = await showDialog<bool>(
        context: context,
        builder: (_) => GroupSurveysEditor(
          groupId: data.group.id,
          currentStoryId: data.group.story,
          currentRevisionId: data.group.revision,
        ),
      );

      if (saved == true) {
        await _refresh();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Encuestas del grupo actualizadas')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron cargar los datos del grupo: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Miembros del grupo'),
        actions: [
          IconButton(
            tooltip: 'Editar encuestas',
            icon: const Icon(Icons.edit_note_outlined),
            onPressed: _editSurveys,
          ),
        ],
      ),
      body: FutureBuilder<GroupMembersResponse>(
        future: _fut,
        builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final data = snap.data!;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Grupo #${data.group.id} — ${data.group.name}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                if (data.group.storyName != null || data.group.revisionName != null) ...[
                  Text([
                    if (data.group.storyName != null) 'Historia: ${data.group.storyName}',
                    if (data.group.revisionName != null) 'Revisión: ${data.group.revisionName}',
                  ].join(' · ')),
                  const SizedBox(height: 12),
                ],
                _membersSection(
                  'Pacientes',
                  data.pacientes,
                  onRemove: (u) async {
                    await _repo.removePatient(groupId: data.group.id, patientId: u.id);
                    await _refresh();
                  },
                ),
                const SizedBox(height: 12),
                _membersSection(
                  'Revisores',
                  data.revisores,
                  onRemove: (u) async {
                    await _repo.removeRevisor(groupId: data.group.id, revisorId: u.id);
                    await _refresh();
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _membersSection(
    String title,
    List<GroupMember> items, {
    required Future<void> Function(GroupMember) onRemove,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$title (${items.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (items.isEmpty)
              const Text('— vacío —')
            else
              ...items.map(
                (u) => ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(u.displayName),
                  subtitle: Text([
                    if (u.dni != null) 'DNI: ${u.dni}',
                    if (u.email != null) u.email!,
                  ].join(' · ')),
                  trailing: IconButton(
                    tooltip: 'Quitar',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => onRemove(u),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
