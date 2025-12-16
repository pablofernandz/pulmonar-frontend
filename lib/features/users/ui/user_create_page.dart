import 'package:flutter/material.dart';
import 'package:tfg_app2/features/users/data/users_repository.dart' as repo;
import 'package:tfg_app2/features/users/data/user_model.dart' as model;
import '../data/user_payloads.dart' as payloads;

class UserCreatePage extends StatefulWidget {
  const UserCreatePage({super.key});

  @override
  State<UserCreatePage> createState() => _UserCreatePageState();
}

class _UserCreatePageState extends State<UserCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _repo = repo.UsersRepository();

  final _nameCtrl = TextEditingController();
  final _last1Ctrl = TextEditingController();
  final _last2Ctrl = TextEditingController();
  final _dniCtrl = TextEditingController();
  final _mailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _birthCtrl = TextEditingController(); 
  final _passCtrl = TextEditingController();

  final _groupPatientCtrl = TextEditingController();   
  final _groupsRevisorCtrl = TextEditingController();  

  String? _sex;
  bool _asPatient = true;
  bool _asRevisor = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _last1Ctrl.dispose();
    _last2Ctrl.dispose();
    _dniCtrl.dispose();
    _mailCtrl.dispose();
    _phoneCtrl.dispose();
    _birthCtrl.dispose();
    _passCtrl.dispose();
    _groupPatientCtrl.dispose();
    _groupsRevisorCtrl.dispose();
    _repo.dispose();
    super.dispose();
  }

  Future<void> _pickDate(TextEditingController ctrl) async {
    final now = DateTime.now();
    final initial = DateTime.tryParse('${ctrl.text}T00:00:00') ?? DateTime(now.year - 30, 1, 1);
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(1900, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDate: initial.isAfter(DateTime(1900)) ? initial : DateTime(now.year - 30, 1, 1),
      helpText: 'Fecha de nacimiento',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
    if (picked != null) {
      final y = picked.year.toString().padLeft(4, '0');
      final m = picked.month.toString().padLeft(2, '0');
      final d = picked.day.toString().padLeft(2, '0');
      ctrl.text = '$y-$m-$d';
      setState(() {});
    }
  }

  List<int>? _parseCsvInts(String s) {
    final txt = s.trim();
    if (txt.isEmpty) return null;
    final parts = txt.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);
    final ints = <int>[];
    for (final p in parts) {
      final n = int.tryParse(p);
      if (n != null) ints.add(n);
    }
    return ints.isEmpty ? null : ints;
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_asPatient && !_asRevisor) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos un rol (Paciente o Revisor).')),
      );
      return;
    }

    final groupPatientId = _asPatient
        ? int.tryParse(_groupPatientCtrl.text.trim())
        : null;

    final groupsRevisor = _asRevisor
        ? _parseCsvInts(_groupsRevisorCtrl.text)
        : null;

    final payload = payloads.CreateUserPayload(
      name: _nameCtrl.text.trim(),
      last_name_1: _last1Ctrl.text.trim(),
      last_name_2: _last2Ctrl.text.trim().isEmpty ? null : _last2Ctrl.text.trim(),
      dni: _dniCtrl.text.trim(),
      mail: _mailCtrl.text.trim().isEmpty ? null : _mailCtrl.text.trim(),
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      birthday: _birthCtrl.text.trim().isEmpty ? null : _birthCtrl.text.trim(), 
      sex: _sex, 
      password: _passCtrl.text.trim(),
      isValidate: true,       
      patient: _asPatient,
      revisor: _asRevisor,
      coordinator: false,    
      groupPatientId: groupPatientId,
      groupsRevisor: groupsRevisor,
    );

    try {
      final created = await _repo.createUser(payload);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Usuario #${created.id} creado correctamente')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al crear usuario: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo usuario'),
        actions: [
          FilledButton.icon(
            onPressed: _onSubmit,
            icon: const Icon(Icons.save),
            label: const Text('Crear'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _sectionCard(
                    title: 'Datos personales',
                    child: LayoutBuilder(
                      builder: (_, c) {
                        final compact = c.maxWidth < 900;
                        double w(double target) => compact ? (c.maxWidth) : target;

                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            SizedBox(
                              width: w(280),
                              child: TextFormField(
                                controller: _nameCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Nombre *',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
                              ),
                            ),
                            SizedBox(
                              width: w(280),
                              child: TextFormField(
                                controller: _last1Ctrl,
                                decoration: const InputDecoration(
                                  labelText: '1º apellido *',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
                              ),
                            ),
                            SizedBox(
                              width: w(280),
                              child: TextFormField(
                                controller: _last2Ctrl,
                                decoration: const InputDecoration(
                                  labelText: '2º apellido',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: w(280),
                              child: TextFormField(
                                controller: _dniCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'DNI *',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
                              ),
                            ),
                            SizedBox(
                              width: w(280),
                              child: TextFormField(
                                controller: _mailCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.emailAddress,
                              ),
                            ),
                            SizedBox(
                              width: w(280),
                              child: TextFormField(
                                controller: _phoneCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Teléfono',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.phone,
                              ),
                            ),
                            SizedBox(
                              width: w(200),
                              child: TextFormField(
                                controller: _birthCtrl,
                                readOnly: true,
                                decoration: const InputDecoration(
                                  labelText: 'Fecha nacimiento (YYYY-MM-DD)',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.event_outlined),
                                ),
                                onTap: () => _pickDate(_birthCtrl),
                              ),
                            ),
                            SizedBox(
                              width: w(160),
                              child: DropdownButtonFormField<String>(
                                value: _sex,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Sexo',
                                  border: OutlineInputBorder(),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'H', child: Text('Hombre')),
                                  DropdownMenuItem(value: 'M', child: Text('Mujer')),
                                ],
                                onChanged: (v) => setState(() => _sex = v),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  _sectionCard(
                    title: 'Seguridad',
                    child: LayoutBuilder(
                      builder: (_, c) {
                        final compact = c.maxWidth < 900;
                        double w(double target) => compact ? (c.maxWidth) : target;

                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            SizedBox(
                              width: w(320),
                              child: TextFormField(
                                controller: _passCtrl,
                                obscureText: true,
                                decoration: const InputDecoration(
                                  labelText: 'Contraseña * (mín. 8)',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (v) {
                                  final s = v?.trim() ?? '';
                                  if (s.isEmpty) return 'Obligatorio';
                                  if (s.length < 8) return 'Mínimo 8 caracteres';
                                  return null;
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  _sectionCard(
                    title: 'Roles',
                    child: Wrap(
                      spacing: 24,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Paciente'),
                            Switch(
                              value: _asPatient,
                              onChanged: (v) => setState(() => _asPatient = v),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Revisor/Tutor'),
                            Switch(
                              value: _asRevisor,
                              onChanged: (v) => setState(() => _asRevisor = v),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  _sectionCard(
                    title: 'Grupos (opcional)',
                    child: LayoutBuilder(
                      builder: (_, c) {
                        final compact = c.maxWidth < 900;
                        double w(double target) => compact ? (c.maxWidth) : target;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 150),
                              child: !_asPatient
                                  ? const SizedBox.shrink()
                                  : Padding(
                                      key: const ValueKey('patientGroup'),
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: SizedBox(
                                        width: w(280),
                                        child: TextFormField(
                                          controller: _groupPatientCtrl,
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(
                                            labelText: 'Grupo como paciente (ID)',
                                            border: OutlineInputBorder(),
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 150),
                              child: !_asRevisor
                                  ? const SizedBox.shrink()
                                  : SizedBox(
                                      key: const ValueKey('revisorGroups'),
                                      width: w(320),
                                      child: TextFormField(
                                        controller: _groupsRevisorCtrl,
                                        decoration: const InputDecoration(
                                          labelText: 'Grupos revisor (IDs separados por coma)',
                                          hintText: 'Ej: 1,2,3',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _onSubmit,
                      icon: const Icon(Icons.save),
                      label: const Text('Crear usuario'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
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
            child,
          ],
        ),
      ),
    );
  }
}
