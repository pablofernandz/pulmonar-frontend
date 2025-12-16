import 'package:flutter/material.dart';
import '../../data/users_repository.dart' as repo;

class UserGroupsEditor extends StatefulWidget {
  final int userId;

  final bool showPatientSection;
  final bool showRevisorSection;

  final int? patientGroupId;
  final List<int> revisorGroupIds;

  const UserGroupsEditor({
    super.key,
    required this.userId,
    required this.showPatientSection,
    required this.showRevisorSection,
    this.patientGroupId,
    this.revisorGroupIds = const [],
  });

  @override
  State<UserGroupsEditor> createState() => _UserGroupsEditorState();
}

class _UserGroupsEditorState extends State<UserGroupsEditor> {
  final _usersRepo = repo.UsersRepository();

  final _patientCtrl = TextEditingController();
  final _revisorCsvCtrl = TextEditingController();
  bool _saving = false;
  bool _clearRevisor = false; 

  @override
  void initState() {
    super.initState();
    if (widget.patientGroupId != null) {
      _patientCtrl.text = widget.patientGroupId.toString();
    }
    if (widget.revisorGroupIds.isNotEmpty) {
      _revisorCsvCtrl.text = widget.revisorGroupIds.join(',');
    }
  }

  List<int> _parseCsvInts(String s) {
    final txt = s.trim();
    if (txt.isEmpty) return <int>[];
    return txt
        .split(',')
        .map((e) => int.tryParse(e.trim()))
        .whereType<int>()
        .toList();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      int? groupPatientId;
      List<int>? groupsRevisor;

      if (widget.showPatientSection) {
        final txt = _patientCtrl.text.trim();
        if (txt.isNotEmpty) {
          groupPatientId = int.tryParse(txt);
        }
      }

      if (widget.showRevisorSection) {
        if (_clearRevisor) {
          groupsRevisor = <int>[]; 
        } else {
          final parsed = _parseCsvInts(_revisorCsvCtrl.text);
          if (parsed.isNotEmpty) {
            groupsRevisor = parsed;
          }
        }
      }

      await _usersRepo.updateGroups(
        userId: widget.userId,
        groupPatientId: groupPatientId,
        groupsRevisor: groupsRevisor,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar grupos: $e')),
      );
    }
  }

  @override
  void dispose() {
    _patientCtrl.dispose();
    _revisorCsvCtrl.dispose();
    _usersRepo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSave = widget.showPatientSection || widget.showRevisorSection;

    return AlertDialog(
      title: const Text('Editar grupos'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.showPatientSection) ...[
              TextFormField(
                controller: _patientCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Grupo como paciente (ID)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (widget.showRevisorSection) ...[
              TextFormField(
                controller: _revisorCsvCtrl,
                decoration: const InputDecoration(
                  labelText: 'Grupos revisor (IDs separados por coma)',
                  hintText: 'Ej: 1,2,3',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Checkbox(
                    value: _clearRevisor,
                    onChanged: _saving ? null : (v) => setState(() => _clearRevisor = v ?? false),
                  ),
                  const Flexible(child: Text('Vaciar grupos de revisor')),
                ],
              ),
            ],
            if (!widget.showPatientSection && !widget.showRevisorSection)
              const Text('Este usuario no tiene roles que permitan editar grupos.'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: (!canSave || _saving) ? null : _save,
          icon: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.save),
          label: const Text('Guardar'),
        ),
      ],
    );
  }
}
