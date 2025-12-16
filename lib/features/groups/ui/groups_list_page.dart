import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/groups_repository.dart';
import '../data/group_model.dart';
import '../../../core/http/dio_client.dart';

class GroupsListPage extends StatefulWidget {
  const GroupsListPage({super.key});
  @override
  State<GroupsListPage> createState() => _GroupsListPageState();
}

class _GroupsListPageState extends State<GroupsListPage> {
  final _repo = GroupsRepository();
  final _qCtrl = TextEditingController();
  late Future<GroupsSearchResult> _fut;

  @override
  void initState() {
    super.initState();
    _fut = _repo.list();
  }

  @override
  void dispose() {
    _qCtrl.dispose();
    _repo.dispose();
    super.dispose();
  }

  void _buscar() {
    setState(() {
      _fut = _repo.list(q: _qCtrl.text.trim());
    });
  }

  Future<void> _openCreateDialog() async {
    final created = await showDialog<Group>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _CreateGroupDialog(),
    );

    if (created != null) {
      _buscar();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Grupo creado correctamente.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Grupos'),
        actions: [
          TextButton.icon(
            onPressed: _openCreateDialog,
            icon: const Icon(Icons.add),
            label: const Text('Crear grupo'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _qCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Buscar grupos',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _buscar(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _buscar,
                  icon: const Icon(Icons.search),
                  label: const Text('Buscar'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<GroupsSearchResult>(
                future: _fut,
                builder: (_, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(child: Text('Error: ${snap.error}'));
                  }
                  final items = snap.data!.items;
                  if (items.isEmpty) {
                    return const Center(child: Text('No hay grupos.'));
                  }
                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final g = items[i];
                      return ListTile(
                        leading: const Icon(Icons.groups_outlined),
                        title: Text(g.name),
                        subtitle: Text(
                          [
                            if (g.story != null) 'Historia: ${g.storyName ?? g.story}',
                            if (g.revision != null) 'Revisión: ${g.revisionName ?? g.revision}',
                          ].join(' · '),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/coordinator/groups/${g.id}'),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _CreateGroupDialog extends StatefulWidget {
  const _CreateGroupDialog();

  @override
  State<_CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<_CreateGroupDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();

  bool _loadingLists = true;
  bool _submitting = false;

  List<_SurveyOption> _stories = [];
  List<_SurveyOption> _revisions = [];

  _SurveyOption? _selectedStory;
  _SurveyOption? _selectedRevision;

  @override
  void initState() {
    super.initState();
    _loadDropdowns();
  }

  Future<void> _loadDropdowns() async {
    setState(() => _loadingLists = true);
    try {
      final stories = await _fetchSurveys(type: 0);
      final revisions = await _fetchSurveys(type: 1);
      setState(() {
        _stories = stories;
        _revisions = revisions;
        _selectedStory = stories.isNotEmpty ? stories.first : null;
        _selectedRevision = revisions.isNotEmpty ? revisions.first : null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cargando encuestas: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingLists = false);
    }
  }

  Future<List<_SurveyOption>> _fetchSurveys({required int type}) async {
    final dio = DioClient().dio;

    final res = await dio.get('/surveys/search', queryParameters: {
      'type': type,     
      'orderBy': 'name',
      'orderDir': 'ASC',
      'limit': 1000,
      'page': 1,
    });

    final payload = res.data;
    List list;

    if (payload is Map<String, dynamic> && payload['data'] is List) {
      list = payload['data'] as List;
    } else if (payload is List) {
      list = payload;
    } else {
      final res2 = await dio.get('/surveys');
      final data2 = res2.data;
      if (data2 is List) {
        list = data2.where((e) {
          final m = (e as Map).cast<String, dynamic>();
          return (m['type'] as num?)?.toInt() == type;
        }).toList();
      } else {
        list = const [];
      }
    }

    return list.map<_SurveyOption>((e) {
      final m = (e as Map).cast<String, dynamic>();
      final id = (m['id'] as num).toInt();
      final name = (m['name'] ?? '').toString();
      return _SurveyOption(id: id, name: name);
    }).toList();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStory == null || _selectedRevision == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona historia y revisión.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final repo = GroupsRepository();
      final created = await repo.create(
        name: _nameCtrl.text.trim(),
        storyId: _selectedStory!.id,
        revisionId: _selectedRevision!.id,
      );
      if (!mounted) return;
      Navigator.of(context).pop(created);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo crear el grupo: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Crear grupo'),
      content: _loadingLists
          ? const SizedBox(height: 120, width: 320, child: Center(child: CircularProgressIndicator()))
          : Form(
              key: _formKey,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del grupo',
                        hintText: 'Ej.: Grupo A',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      maxLength: 45,
                      validator: (v) {
                        final t = (v ?? '').trim();
                        if (t.isEmpty) return 'El nombre es obligatorio';
                        if (t.length > 45) return 'Máximo 45 caracteres';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<_SurveyOption>(
                      value: _selectedStory,
                      items: _stories
                          .map((s) => DropdownMenuItem<_SurveyOption>(
                                value: s,
                                child: Text(s.name),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedStory = v),
                      decoration: const InputDecoration(
                        labelText: 'Historia clínica',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<_SurveyOption>(
                      value: _selectedRevision,
                      items: _revisions
                          .map((s) => DropdownMenuItem<_SurveyOption>(
                                value: s,
                                child: Text(s.name),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedRevision = v),
                      decoration: const InputDecoration(
                        labelText: 'Revisión',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).maybePop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submitting || _loadingLists ? null : _submit,
          child: _submitting
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Crear'),
        ),
      ],
    );
  }
}

class _SurveyOption {
  final int id;
  final String name;
  const _SurveyOption({required this.id, required this.name});
}
