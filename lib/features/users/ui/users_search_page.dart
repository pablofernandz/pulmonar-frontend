import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../users/data/users_repository.dart' as repo;
import '../../users/data/user_model.dart' as model;

class UsersSearchPage extends StatefulWidget {
  const UsersSearchPage({super.key});

  @override
  State<UsersSearchPage> createState() => _UsersSearchPageState();
}

class _UsersSearchPageState extends State<UsersSearchPage> {
  final _repo = repo.UsersRepository();

  final _qCtrl = TextEditingController();
  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();
  final _groupPatientCtrl = TextEditingController();
  final _groupRevisorCtrl = TextEditingController();
  final _limitCtrl = TextEditingController();

  String? _rol;
  String _ordenarPor = 'date_insert';
  String _sentido = 'desc';
  int _page = 1;
  int _limit = 20;

  Future<model.UsersSearchResult>? _fut;
  bool _firstLoad = true;

  @override
  void initState() {
    super.initState();
    _limitCtrl.text = '$_limit';
    _fut = Future.value(
      model.UsersSearchResult(
        items: const [],
        page: _page,
        limit: _limit,
        total: 0,
        pages: 0,
      ),
    );
  }

  @override
  void dispose() {
    _qCtrl.dispose();
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _groupPatientCtrl.dispose();
    _groupRevisorCtrl.dispose();
    _limitCtrl.dispose();
    super.dispose();
  }

  void _buscar({int? page}) {
    final gp = int.tryParse(_groupPatientCtrl.text.trim());
    final gr = int.tryParse(_groupRevisorCtrl.text.trim());
    final parsedLimit = int.tryParse(_limitCtrl.text.trim());
    if (parsedLimit != null && parsedLimit > 0) _limit = parsedLimit;

    setState(() {
      _firstLoad = false;
      if (page != null) _page = page;
      _fut = _repo.search(
        q: _qCtrl.text.trim().isEmpty ? null : _qCtrl.text.trim(),
        role: _rol,
        groupPatientId: gp,
        groupRevisorId: gr,
        from: _fromCtrl.text.trim().isEmpty ? null : _fromCtrl.text.trim(),
        to: _toCtrl.text.trim().isEmpty ? null : _toCtrl.text.trim(),
        sort: _ordenarPor,
        order: _sentido,
        page: _page,
        limit: _limit,
      );
    });
  }

  void _limpiar() {
    setState(() {
      _qCtrl.clear();
      _rol = null;
      _groupPatientCtrl.clear();
      _groupRevisorCtrl.clear();
      _fromCtrl.clear();
      _toCtrl.clear();
      _ordenarPor = 'date_insert';
      _sentido = 'desc';
      _page = 1;
      _limit = 20;
      _limitCtrl.text = '20';
      _fut = Future.value(
        model.UsersSearchResult(
          items: const [],
          page: _page,
          limit: _limit,
          total: 0,
          pages: 0,
        ),
      );
      _firstLoad = true;
    });
  }

  Future<void> _pickDate(TextEditingController ctrl) async {
    final now = DateTime.now();
    final initial = DateTime.tryParse('${ctrl.text}T00:00:00') ?? now;
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(now.year + 2, 12, 31),
      initialDate: initial,
      helpText: 'Selecciona fecha',
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

  int _colsFor(double w) {
    if (w >= 960) return 3;   
    if (w >= 640) return 2;  
    return 1;                 
  }

  double _cellWidth(double maxW, int cols, {double gap = 12}) {
    if (cols == 1) return maxW;
    final gaps = (cols - 1) * gap;
    return (maxW - gaps) / cols;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    Widget _filtersCard(BuildContext context, double _ignored) {
  final t = Theme.of(context);
  const gap = 12.0;

  return Card(
    elevation: 1.5,
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, c) {
          final contentW = c.maxWidth;
          final cols = _colsFor(contentW);               
          final fw = _cellWidth(contentW, cols, gap: gap);
          final fw2 = _cellWidth(contentW, 2, gap: gap);

          SizedBox cell(Widget child) {
            final w = (cols == 3) ? fw : (cols == 2) ? fw2 : contentW;
            return SizedBox(width: w, child: child);
          }

          Widget header() {
            final clearBtn = OutlinedButton.icon(
              onPressed: _limpiar,
              icon: const Icon(Icons.refresh),
              label: const Text('Limpiar'),
            );
            final searchBtn = FilledButton.icon(
              onPressed: () => _buscar(page: 1),
              icon: const Icon(Icons.search),
              label: const Text('Buscar'),
            );

            if (cols == 1) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Búsqueda de usuarios', style: t.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  SizedBox(width: contentW, child: clearBtn),
                  const SizedBox(height: 8),
                  SizedBox(width: contentW, child: searchBtn),
                ],
              );
            }
            return Row(
              children: [
                Text('Búsqueda de usuarios', style: t.textTheme.titleMedium),
                const Spacer(),
                clearBtn,
                const SizedBox(width: 8),
                searchBtn,
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header(),
              const SizedBox(height: 12),

              Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  cell(TextField(
                    controller: _qCtrl,
                    onSubmitted: (_) => _buscar(page: 1),
                    decoration: const InputDecoration(
                      labelText: 'Texto libre',
                      hintText: 'Nombre, apellidos o email · DNI exacto',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  )),
                  cell(DropdownButtonFormField<String>(
                    value: _rol,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Rol',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'patient', child: Text('Paciente')),
                      DropdownMenuItem(value: 'revisor', child: Text('Revisor/Tutor')),
                      DropdownMenuItem(value: 'coordinator', child: Text('Coordinador/Investigador')),
                    ],
                    onChanged: (v) => setState(() => _rol = v),
                  )),
                  cell(DropdownButtonFormField<String>(
                    value: _ordenarPor,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Ordenar por',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.sort_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'date_insert', child: Text('Fecha de alta')),
                      DropdownMenuItem(value: 'name', child: Text('Nombre')),
                      DropdownMenuItem(value: 'last_name_1', child: Text('1er apellido')),
                      DropdownMenuItem(value: 'dni', child: Text('DNI')),
                      DropdownMenuItem(value: 'mail', child: Text('Email')),
                    ],
                    onChanged: (v) => setState(() => _ordenarPor = v ?? 'date_insert'),
                  )),
                ],
              ),
              const SizedBox(height: 12),

              Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  cell(TextField(
                    controller: _groupRevisorCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Grupo como revisor (ID)',
                      prefixIcon: Icon(Icons.group_add_outlined),
                      border: OutlineInputBorder(),
                    ),
                  )),
                  cell(TextField(
                    controller: _groupPatientCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Grupo como paciente (ID)',
                      prefixIcon: Icon(Icons.groups_outlined),
                      border: OutlineInputBorder(),
                    ),
                  )),
                  cell(DropdownButtonFormField<String>(
                    value: _sentido,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Sentido',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.swap_vert_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'desc', child: Text('Descendente')),
                      DropdownMenuItem(value: 'asc', child: Text('Ascendente')),
                    ],
                    onChanged: (v) => setState(() => _sentido = v ?? 'desc'),
                  )),
                ],
              ),
              const SizedBox(height: 12),

              Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  cell(TextField(
                    controller: _fromCtrl,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Desde (YYYY-MM-DD)',
                      prefixIcon: Icon(Icons.event_outlined),
                      border: OutlineInputBorder(),
                    ),
                    onTap: () => _pickDate(_fromCtrl),
                  )),
                  cell(TextField(
                    controller: _toCtrl,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Hasta (YYYY-MM-DD)',
                      prefixIcon: Icon(Icons.event_available_outlined),
                      border: OutlineInputBorder(),
                    ),
                    onTap: () => _pickDate(_toCtrl),
                  )),
                  cell(TextField(
                    controller: _limitCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Límite',
                      prefixIcon: Icon(Icons.filter_list_outlined),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _buscar(page: 1),
                  )),
                ],
              ),
            ],
          );
        },
      ),
    ),
  );
}


    return Scaffold(
      appBar: AppBar(
        title: const Text('Usuarios'),
        actions: [
          IconButton(
            tooltip: 'Nuevo usuario',
            icon: const Icon(Icons.person_add_alt_1),
            onPressed: () => context.push('/coordinator/users/new'),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return CustomScrollView(
                    physics: const ClampingScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: _filtersCard(context, constraints.maxWidth),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 12)),
                      SliverFillRemaining(
                        hasScrollBody: true,
                        child: FutureBuilder<model.UsersSearchResult>(
                          future: _fut,
                          builder: (_, snap) {
                            if (snap.connectionState != ConnectionState.done) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            if (snap.hasError) {
                              return Center(child: Text('Error: ${snap.error}'));
                            }
                            final res = snap.data!;
                            final items = res.items;

                            final filtered = items.where((u) {
                              final r = u.roles;
                              return !(r.coordinator && !r.patient && !r.revisor);
                            }).toList();

                            if (filtered.isEmpty) {
                              return Center(
                                child: Text(
                                  _firstLoad
                                      ? 'Introduce filtros y pulsa “Buscar”.'
                                      : 'No se han encontrado usuarios con esos filtros.',
                                  style: t.textTheme.bodyLarge,
                                  textAlign: TextAlign.center,
                                ),
                              );
                            }

                            return Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                  child: Wrap(
                                    spacing: 16,
                                    runSpacing: 8,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Text('Total (API): ${res.total}'),
                                      Text('Mostrados: ${filtered.length}'),
                                      Text('Página: ${res.page}/${res.pages}'),
                                      Text('Límite: ${res.limit}'),
                                      IconButton.outlined(
                                        tooltip: 'Recargar',
                                        onPressed: () => _buscar(page: res.page),
                                        icon: const Icon(Icons.refresh),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Expanded(
                                  child: ListView.separated(
                                    primary: false,
                                    itemCount: filtered.length,
                                    separatorBuilder: (_, __) => const Divider(height: 1),
                                    itemBuilder: (_, i) {
                                      final u = filtered[i];
                                      final nombre = [
                                        u.name,
                                        u.lastName1,
                                        if (u.lastName2?.isNotEmpty == true) u.lastName2!,
                                      ].join(' ');
                                      final rolesText = [
                                        if (u.roles.patient) 'Paciente',
                                        if (u.roles.revisor) 'Revisor',
                                        if (u.roles.coordinator) 'Coordinador',
                                      ].join(' · ');
                                      return ListTile(
                                        leading: CircleAvatar(
                                          child: Text((u.name.isNotEmpty ? u.name[0] : '?').toUpperCase()),
                                        ),
                                        title: Text(nombre, maxLines: 1, overflow: TextOverflow.ellipsis),
                                        subtitle: Text(
                                          [
                                            'DNI: ${u.dni}',
                                            if (u.mail != null && u.mail!.isNotEmpty) u.mail!,
                                            if (rolesText.isNotEmpty) 'Roles: $rolesText',
                                          ].join(' · '),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        trailing: const Icon(Icons.chevron_right),
                                        onTap: () => context.push('/coordinator/users/${u.id}'),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        dense: MediaQuery.of(context).size.width < 420,
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 8,
                                  alignment: WrapAlignment.center,
                                  children: [
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.chevron_left),
                                      onPressed: res.page > 1 ? () => _buscar(page: res.page - 1) : null,
                                      label: const Text('Anterior'),
                                    ),
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.chevron_right),
                                      onPressed: (res.page < res.pages) ? () => _buscar(page: res.page + 1) : null,
                                      label: const Text('Siguiente'),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
