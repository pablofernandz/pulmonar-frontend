import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../users/data/users_repository.dart';
import '../../users/data/user_model.dart';

class RevisorEvaluateSearchPage extends StatefulWidget {
  const RevisorEvaluateSearchPage({super.key});

  @override
  State<RevisorEvaluateSearchPage> createState() => _RevisorEvaluateSearchPageState();
}

class _RevisorEvaluateSearchPageState extends State<RevisorEvaluateSearchPage> {
  final _repo = UsersRepository();
  final _controller = TextEditingController();

  bool _loading = false;
  String _q = '';
  int _page = 1;
  static const int _limit = 20;

  List<AppUser> _items = [];
  int _pages = 1;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _fetch(); 
  }

  @override
  void dispose() {
    _controller.dispose();
    _repo.dispose();
    super.dispose();
  }

  Future<void> _fetch({int? page}) async {
    setState(() => _loading = true);
    try {
      final res = await _repo.search(
        q: _q.isEmpty ? null : _q,
        role: 'patient', 
        page: page ?? _page,
        limit: _limit,
        sort: 'date_insert',
        order: 'desc',
      );
      if (!mounted) return;
      setState(() {
        _items = res.items;
        _page = res.page;
        _pages = res.pages;
        _total = res.total;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al buscar pacientes: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearch() {
    setState(() {
      _q = _controller.text.trim();
      _page = 1;
    });
    _fetch(page: 1);
  }

  void _openStart(AppUser u) {
    context.push('/revisor/evaluar/${u.id}');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Evaluar pacientes'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        onSubmitted: (_) => _onSearch(),
                        decoration: const InputDecoration(
                          labelText: 'Buscar por nombre, DNI, email…',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _loading ? null : _onSearch,
                      child: const Text('Buscar'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _loading
                        ? 'Buscando…'
                        : 'Resultados: $_total  •  Página $_page de $_pages',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 8),

                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _items.isEmpty
                          ? const Center(
                              child: Text('No se encontraron pacientes.'),
                            )
                          : Material(
                              child: ListView.separated(
                                itemCount: _items.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final u = _items[index];
                                  final fullName = '${u.name} ${u.lastName1} ${u.lastName2 ?? ''}'.trim();
                                  final subtitle = <String>[
                                    if ((u.mail ?? '').isNotEmpty) u.mail!,
                                    if ((u.dni).isNotEmpty) 'DNI: ${u.dni}',
                                  ].join(' • ');

                                  return ListTile(
                                    leading: const Icon(Icons.person_outline),
                                    title: Text(fullName.isEmpty ? 'Usuario ${u.id}' : fullName),
                                    subtitle: subtitle.isEmpty ? null : Text(subtitle),
                                    trailing: const Icon(Icons.chevron_right_rounded),
                                    onTap: () => _openStart(u),
                                  );
                                },
                              ),
                            ),
                ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('Página $_page de $_pages'),
                    const SizedBox(width: 12),
                    IconButton(
                      tooltip: 'Anterior',
                      onPressed:
                          (!_loading && _page > 1) ? () => _fetch(page: _page - 1) : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    IconButton(
                      tooltip: 'Siguiente',
                      onPressed: (!_loading && _page < _pages)
                          ? () => _fetch(page: _page + 1)
                          : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
