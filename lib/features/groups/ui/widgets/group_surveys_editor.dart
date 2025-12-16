import 'package:flutter/material.dart';
import '../../data/groups_repository.dart';
import '../../../../core/http/dio_client.dart';

class GroupSurveysEditor extends StatefulWidget {
  final int groupId;
  final int? currentStoryId;
  final int? currentRevisionId;

  const GroupSurveysEditor({
    super.key,
    required this.groupId,
    this.currentStoryId,
    this.currentRevisionId,
  });

  @override
  State<GroupSurveysEditor> createState() => _GroupSurveysEditorState();
}

class _GroupSurveysEditorState extends State<GroupSurveysEditor> {
  final _groupsRepo = GroupsRepository();
  bool _loading = true;
  bool _saving = false;

  int? _storyId;
  int? _revisionId;

  List<_Survey> _stories = const [];
  List<_Survey> _revisions = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final dio = DioClient().dio;
      final resStories = await dio.get('/surveys/search', queryParameters: {
        'type': '0',
        'orderBy': 'name',
        'orderDir': 'ASC',
        'limit': 100,
        'page': 1,
      });
      final resRevisions = await dio.get('/surveys/search', queryParameters: {
        'type': '1',
        'orderBy': 'name',
        'orderDir': 'ASC',
        'limit': 100,
        'page': 1,
      });

      List<_Survey> parse(dynamic data) {
        final list = (data is Map ? data['data'] : null) as List? ?? const [];
        return list
            .whereType<Map>()
            .map((m) => _Survey(
                  id: (m['id'] as num).toInt(),
                  name: (m['name'] ?? '').toString(),
                ))
            .toList(growable: false);
      }

      final stories = parse(resStories.data);
      final revisions = parse(resRevisions.data);

      setState(() {
        _stories = stories;
        _revisions = revisions;
        _storyId = widget.currentStoryId;
        _revisionId = widget.currentRevisionId;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cargando encuestas: $e')),
      );
    }
  }

  Future<void> _save() async {
    if (_storyId == null || _revisionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona Historia y Revisión (ambas son obligatorias).')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await _groupsRepo.update(
        widget.groupId,
        storyId: _storyId,
        revisionId: _revisionId,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error guardando encuestas del grupo: $e')),
      );
    }
  }

  @override
  void dispose() {
    _groupsRepo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar encuestas del grupo'),
      content: _loading
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(height: 40, child: Center(child: CircularProgressIndicator())),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  value: _storyId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Historia (obligatoria)',
                    border: OutlineInputBorder(),
                  ),
                  items: _stories
                      .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
                      .toList(),
                  onChanged: _saving ? null : (v) => setState(() => _storyId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: _revisionId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Revisión (obligatoria)',
                    border: OutlineInputBorder(),
                  ),
                  items: _revisions
                      .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
                      .toList(),
                  onChanged: _saving ? null : (v) => setState(() => _revisionId = v),
                ),
              ],
            ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _loading || _saving ? null : _save,
          icon: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.save),
          label: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _Survey {
  final int id;
  final String name;
  const _Survey({required this.id, required this.name});
}
