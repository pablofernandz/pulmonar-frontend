import 'package:flutter/material.dart';
import '../../../../core/http/dio_client.dart';
import 'package:go_router/go_router.dart';

class UserGroupsCard extends StatefulWidget {
  final int userId;
  const UserGroupsCard({super.key, required this.userId});

  @override
  State<UserGroupsCard> createState() => _UserGroupsCardState();
}

class _UserGroupsCardState extends State<UserGroupsCard> {
  late Future<_UserGroups> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  Future<_UserGroups> _fetch() async {
    final dio = DioClient().dio;
    final res = await dio.get('/users/${widget.userId}');
    final data = (res.data as Map).cast<String, dynamic>();

    final groups = (data['groups'] as Map?)?.cast<String, dynamic>() ?? const {};
    final asPatientList = (groups['asPatient'] as List?) ?? const [];
    final asRevisorList = (groups['asRevisor'] as List?) ?? const [];

    List<_MiniGroup> parseList(List raw) => raw.map<_MiniGroup>((e) {
          final m = (e as Map).cast<String, dynamic>();
          final id = (m['id'] as num).toInt();
          final name = (m['name'] ?? 'Grupo $id').toString();
          return _MiniGroup(id: id, name: name);
        }).toList(growable: false);

    return _UserGroups(
      patientGroups: parseList(asPatientList),
      revisorGroups: parseList(asRevisorList),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_UserGroups>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (snap.hasError) {
          return Text('Error cargando grupos: ${snap.error}');
        }
        final g = snap.data!;
        final hasPatient = g.patientGroups.isNotEmpty;
        final hasRevisor = g.revisorGroups.isNotEmpty;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Como paciente', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            if (!hasPatient)
              Text('—', style: Theme.of(context).textTheme.bodyMedium)
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _GroupChip(
                    group: g.patientGroups.first,
                    onTap: (id) => context.push('/coordinator/groups/$id'),
                  ),
                  if (g.patientGroups.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Aviso: hay ${g.patientGroups.length} grupos; debería existir solo uno activo.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.orange[800]),
                      ),
                    ),
                ],
              ),

            const SizedBox(height: 16),
            Text('Como tutor', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            if (!hasRevisor)
              Text('—', style: Theme.of(context).textTheme.bodyMedium)
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: g.revisorGroups
                    .map((gr) => _GroupChip(
                          group: gr,
                          onTap: (id) => context.push('/coordinator/groups/$id'),
                        ))
                    .toList(),
              ),
          ],
        );
      },
    );
  }
}

class _GroupChip extends StatelessWidget {
  final _MiniGroup group;
  final void Function(int id) onTap;
  const _GroupChip({required this.group, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => onTap(group.id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.group_outlined, size: 18),
          const SizedBox(width: 8),
          Text(group.name),
        ]),
      ),
    );
  }
}

class _UserGroups {
  final List<_MiniGroup> patientGroups;
  final List<_MiniGroup> revisorGroups;
  const _UserGroups({required this.patientGroups, required this.revisorGroups});
}

class _MiniGroup {
  final int id;
  final String name;
  const _MiniGroup({required this.id, required this.name});
}
