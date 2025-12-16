import 'package:flutter/material.dart';
import '../../groups/data/groups_repository.dart';

class GroupCreatePage extends StatefulWidget {
  const GroupCreatePage({super.key});
  @override
  State<GroupCreatePage> createState() => _GroupCreatePageState();
}

class _GroupCreatePageState extends State<GroupCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _repo = GroupsRepository();

  final _nameCtrl = TextEditingController();
  final _storyCtrl = TextEditingController();
  final _revisionCtrl = TextEditingController();

  @override
  void dispose() {
    _repo.dispose();
    _nameCtrl.dispose();
    _storyCtrl.dispose();
    _revisionCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final story = int.tryParse(_storyCtrl.text.trim());
    final rev   = int.tryParse(_revisionCtrl.text.trim());
    if (story == null || rev == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Historia y Revisión son obligatorios (números).')));
      return;
    }
    try {
      final created = await _repo.create(
        name: _nameCtrl.text.trim(),
        storyId: story,
        revisionId: rev,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Grupo "${created.name}" creado (#${created.id})')));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al crear grupo: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo grupo'),
        actions: [
          FilledButton.icon(onPressed: _submit, icon: const Icon(Icons.save), label: const Text('Crear')),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'Nombre *', border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _storyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Historia (ID) *', border: OutlineInputBorder()),
                    validator: (v) => (v == null || int.tryParse(v.trim()) == null) ? 'Obligatorio (número)' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _revisionCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Revisión (ID) *', border: OutlineInputBorder()),
                    validator: (v) => (v == null || int.tryParse(v.trim()) == null) ? 'Obligatorio (número)' : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
