import 'package:flutter/material.dart';
import '../../data/users_repository.dart' as repo;
import '../../data/user_model.dart';

class UserRolesEditor extends StatefulWidget {
  final int userId;
  final UserRoles current;

  const UserRolesEditor({super.key, required this.userId, required this.current});

  @override
  State<UserRolesEditor> createState() => _UserRolesEditorState();
}

class _UserRolesEditorState extends State<UserRolesEditor> {
  final _usersRepo = repo.UsersRepository();
  late bool _patient;
  late bool _revisor;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _patient = widget.current.patient;
    _revisor = widget.current.revisor;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _usersRepo.updateRoles(
        userId: widget.userId,
        patient: _patient,
        revisor: _revisor,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar roles: $e')),
      );
    }
  }

  @override
  void dispose() {
    _usersRepo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar roles'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
            title: const Text('Paciente'),
            value: _patient,
            onChanged: _saving ? null : (v) => setState(() => _patient = v),
          ),
          SwitchListTile(
            title: const Text('Revisor/Tutor'),
            value: _revisor,
            onChanged: _saving ? null : (v) => setState(() => _revisor = v),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.save),
          label: const Text('Guardar'),
        ),
      ],
    );
  }
}
