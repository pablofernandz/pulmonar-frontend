import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../users/data/users_repository.dart';
import '../../users/data/user_model.dart';
import '../../groups/data/groups_repository.dart';
import '../../groups/data/group_model.dart';

import '../../surveys/data/surveys_repository.dart';
import '../../surveys/data/survey_models.dart';
import '../../evaluations/data/evaluations_repository.dart';


class RevisorEvaluationStartPage extends StatefulWidget {
  final int patientId;
  const RevisorEvaluationStartPage({super.key, required this.patientId});

  @override
  State<RevisorEvaluationStartPage> createState() => _RevisorEvaluationStartPageState();
}

class _RevisorEvaluationStartPageState extends State<RevisorEvaluationStartPage> {
  final _users = UsersRepository();
  final _groups = GroupsRepository();
  final _surveys = SurveysRepository();
  final _evals = EvaluationsRepository();

  bool _loading = true;
  String? _error;

  AppUser? _patient;
  AppUser? _me; 
  Group? _sharedGroup; 

  bool _firstTime = true; 
  List<SurveyListItem> _options = [];
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _users.dispose();
    _groups.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final patient = await _users.getUser(widget.patientId);
      final me = await _users.getMe();

      Group? shared;
      var page = 1;
      const limit = 50;

      while (shared == null) {
        final list = await _groups.list(page: page, limit: limit);
        if (list.items.isEmpty) break;

        for (final g in list.items) {
          final m = await _groups.getMembers(g.id);
          final hasPatient = m.pacientes.any((p) => p.id == patient.id);
          final hasMe = m.revisores.any((r) => r.id == me.id);
          if (hasPatient && hasMe) {
            shared = g;
            break;
          }
        }

        page++;
        if (page > list.pages) break;
      }

      if (shared == null) {
        if (!mounted) return;
        setState(() {
          _patient = patient;
          _me = me;
          _sharedGroup = null;
          _options = const [];
          _firstTime = true;
          _loading = false;
        });
        return;
      }

      final evals = await _evals.listByPatient(patient.id);
      final firstTime = evals.isEmpty;

      final type = firstTime ? 0 : 1;
      final searchRes = await _surveys.search(page: 1, limit: 200, orderBy: 'name', orderDir: 'ASC', type: type);

      if (!mounted) return;
      setState(() {
        _patient = patient;
        _me = me;
        _sharedGroup = shared;
        _firstTime = firstTime;
        _options = searchRes.items;
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

  void _startRun({required int surveyId}) {
    context.push('/revisor/run/${_patient!.id}/$surveyId');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    List<SurveyListItem> _filteredOptions() {
      final q = _searchCtrl.text.trim().toLowerCase();
      if (q.isEmpty) return _options;
      return _options.where((s) {
        final n = s.name.toLowerCase();
        return n.contains(q) || s.id.toString() == q;
      }).toList();
    }

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
      final p = _patient!;
      final fullName = '${p.name} ${p.lastName1} ${p.lastName2 ?? ''}'.trim();

      if (_sharedGroup == null) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(fullName.isEmpty ? 'Usuario ${p.id}' : fullName,
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(p.mail ?? '', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 16),
              const Card(
                elevation: 0,
                color: Color(0xFFFFF3E0),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Este paciente no tiene un grupo compartido contigo. '
                    'Asigna el paciente a uno de tus grupos para poder evaluarlo.',
                  ),
                ),
              ),
            ],
          ),
        );
      }

      final g = _sharedGroup!;
      final title = _firstTime ? 'Seleccionar Historia clínica' : 'Seleccionar Revisión';
      final subtitle =
          _firstTime ? 'Elige una historia clínica disponible' : 'Elige una revisión disponible';
      final list = _filteredOptions();

      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(child: Icon(Icons.person_outline)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(fullName.isEmpty ? 'Usuario ${p.id}' : fullName,
                              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 12,
                            runSpacing: 4,
                            children: [
                              if ((p.mail ?? '').isNotEmpty) Text(p.mail!),
                              Text('DNI: ${p.dni}'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                Divider(color: theme.colorScheme.outlineVariant),

                Text('Grupo', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Card(
                  elevation: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.group_outlined),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(g.name, style: theme.textTheme.titleMedium),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 16,
                                runSpacing: 4,
                                children: [
                                  Text('Historia del grupo: ${g.storyName ?? (g.story != null ? g.story.toString() : '—')}'),
                                  Text('Revisión del grupo: ${g.revisionName ?? (g.revision != null ? g.revision.toString() : '—')}'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                Divider(color: theme.colorScheme.outlineVariant),

                Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(subtitle, style: theme.textTheme.bodyMedium),

                const SizedBox(height: 12),
                TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Buscar por nombre o ID…',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 12),
                if (_options.isEmpty)
                  const Card(
                    color: Color(0xFFFFEBEE),
                    elevation: 0,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No hay encuestas disponibles para este tipo. '
                        'El coordinador debe crearlas previamente.',
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final s = list[i];
                      return _FormOptionCard(
                        icon: _firstTime ? Icons.history_edu_outlined : Icons.assignment_turned_in_outlined,
                        title: s.name,
                        subtitle: 'ID ${s.id}${s.type != null ? ' · ${s.type!.label}' : ''}',
                        action: TextButton.icon(
                          onPressed: () => _startRun(surveyId: s.id),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Iniciar'),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Iniciar evaluación'),
      ),
      body: body(),
    );
  }
}

class _FormOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget action;

  const _FormOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary.withOpacity(0.1),
              ),
              padding: const EdgeInsets.all(12),
              child: Icon(icon, size: 28, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      )),
                  const SizedBox(height: 4),
                  Text(subtitle, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
            const SizedBox(width: 8),
            action,
          ],
        ),
      ),
    );
  }
}
