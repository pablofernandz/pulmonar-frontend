import 'package:flutter/material.dart';
import '../../surveys/data/surveys_repository.dart';
import '../../surveys/data/survey_models.dart';

class SurveysSearchPage extends StatefulWidget {
  const SurveysSearchPage({super.key});

  @override
  State<SurveysSearchPage> createState() => _SurveysSearchPageState();
}

class _SurveysSearchPageState extends State<SurveysSearchPage> {
  final _repo = SurveysRepository();

  final _qCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _idCtrl = TextEditingController();
  SurveyType? _type;

  String _orderBy = 'date_insert';
  String _orderDir = 'DESC';
  int _page = 1;
  int _limit = 20;

  Future<SurveysSearchResult>? _fut;
  bool _firstLoad = true;

  @override
  void initState() {
    super.initState();
    _fut = Future.value(
      SurveysSearchResult(
        items: const [],
        meta: SurveysSearchMeta(
          page: 1,
          limit: 20,
          totalItems: 0,
          totalPages: 0,
          hasNext: false,
          orderBy: _orderBy,
          orderDir: _orderDir,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _repo.dispose();
    _qCtrl.dispose();
    _nameCtrl.dispose();
    _idCtrl.dispose();
    super.dispose();
  }

  int? _typeToInt(SurveyType? t) {
    if (t == null) return null;
    return t == SurveyType.history ? 0 : 1;
  }

  void _search({int? page}) {
    final id = int.tryParse(_idCtrl.text.trim());
    final typeInt = _typeToInt(_type);

    setState(() {
      _firstLoad = false;
      if (page != null) _page = page;
      _fut = _repo.search(
        q: _qCtrl.text.trim().isEmpty ? null : _qCtrl.text.trim(),
        name: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
        id: id,
        type: typeInt,
        orderBy: _orderBy,
        orderDir: _orderDir,
        page: _page,
        limit: _limit,
      );
    });
  }

  void _clear() {
    setState(() {
      _qCtrl.clear();
      _nameCtrl.clear();
      _idCtrl.clear();
      _type = null;
      _orderBy = 'date_insert';
      _orderDir = 'DESC';
      _page = 1;
      _limit = 20;
      _firstLoad = true;
      _fut = Future.value(
        SurveysSearchResult(
          items: const [],
          meta: SurveysSearchMeta(
            page: 1,
            limit: 20,
            totalItems: 0,
            totalPages: 0,
            hasNext: false,
            orderBy: _orderBy,
            orderDir: _orderDir,
          ),
        ),
      );
    });
  }

  int _colsFor(double maxW) {
    if (maxW >= 1100) return 3;
    if (maxW >= 800) return 2;
    return 1;
  }

  double _fieldWidth({required double maxW, required int cols, double hSpacing = 12}) {
    if (cols == 1) return maxW;
    final gaps = (cols - 1) * hSpacing;
    return (maxW - gaps) / cols;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Buscar formularios')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Card(
                  elevation: 1.5,
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: LayoutBuilder(
                      builder: (_, c) {
                        final maxW = c.maxWidth;
                        final cols = _colsFor(maxW);
                        final fw = _fieldWidth(maxW: maxW, cols: cols);
                        const hGap = 12.0;

                        Widget header() {
                          final clearBtn = OutlinedButton.icon(
                            onPressed: _clear,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Limpiar'),
                          );
                          final searchBtn = FilledButton.icon(
                            onPressed: () => _search(page: 1),
                            icon: const Icon(Icons.search),
                            label: const Text('Buscar'),
                          );

                          if (cols == 1) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Filtros', style: t.textTheme.titleMedium),
                                const SizedBox(height: 8),
                                SizedBox(width: maxW, child: clearBtn),
                                const SizedBox(height: 8),
                                SizedBox(width: maxW, child: searchBtn),
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Text('Filtros', style: t.textTheme.titleMedium),
                              const Spacer(),
                              clearBtn,
                              const SizedBox(width: 8),
                              searchBtn,
                            ],
                          );
                        }

                        return Column(
                          children: [
                            header(),
                            const SizedBox(height: 12),

                            Wrap(
                              spacing: hGap,
                              runSpacing: hGap,
                              children: [
                                SizedBox(
                                  width: fw,
                                  child: TextField(
                                    controller: _qCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Texto libre',
                                      hintText: 'nombre (LIKE) · id (si numérico)',
                                      prefixIcon: Icon(Icons.search),
                                      border: OutlineInputBorder(),
                                    ),
                                    onSubmitted: (_) => _search(page: 1),
                                  ),
                                ),
                                SizedBox(
                                  width: fw,
                                  child: TextField(
                                    controller: _nameCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Nombre',
                                      border: OutlineInputBorder(),
                                    ),
                                    onSubmitted: (_) => _search(page: 1),
                                  ),
                                ),
                                SizedBox(
                                  width: fw,
                                  child: TextField(
                                    controller: _idCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'ID',
                                      border: OutlineInputBorder(),
                                    ),
                                    onSubmitted: (_) => _search(page: 1),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            Wrap(
                              spacing: hGap,
                              runSpacing: hGap,
                              children: [
                                SizedBox(
                                  width: fw,
                                  child: DropdownButtonFormField<SurveyType?>(
                                    value: _type,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Tipo',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.category_outlined),
                                    ),
                                    items: const [
                                      DropdownMenuItem(value: null, child: Text('Todos')),
                                      DropdownMenuItem(value: SurveyType.history, child: Text('Historia')),
                                      DropdownMenuItem(value: SurveyType.revision, child: Text('Revisión')),
                                    ],
                                    onChanged: (v) => setState(() => _type = v),
                                  ),
                                ),
                                SizedBox(
                                  width: fw,
                                  child: DropdownButtonFormField<String>(
                                    value: _orderBy,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Ordenar por',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.sort_outlined),
                                    ),
                                    items: const [
                                      DropdownMenuItem(value: 'date_insert', child: Text('Fecha de alta')),
                                      DropdownMenuItem(value: 'name', child: Text('Nombre')),
                                      DropdownMenuItem(value: 'id', child: Text('ID')),
                                      DropdownMenuItem(value: 'type', child: Text('Tipo')),
                                    ],
                                    onChanged: (v) => setState(() => _orderBy = v ?? 'date_insert'),
                                  ),
                                ),
                                SizedBox(
                                  width: fw,
                                  child: DropdownButtonFormField<String>(
                                    value: _orderDir,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Sentido',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.swap_vert_outlined),
                                    ),
                                    items: const [
                                      DropdownMenuItem(value: 'DESC', child: Text('Descendente')),
                                      DropdownMenuItem(value: 'ASC', child: Text('Ascendente')),
                                    ],
                                    onChanged: (v) => setState(() => _orderDir = v ?? 'DESC'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                Expanded(
                  child: FutureBuilder<SurveysSearchResult>(
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

                      if (items.isEmpty) {
                        return Center(
                          child: Text(
                            _firstLoad
                                ? 'Introduce filtros y pulsa “Buscar”.'
                                : 'No se han encontrado formularios.',
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
                                Text('Total: ${res.meta.totalItems}'),
                                Text('Página: ${res.meta.page}/${res.meta.totalPages}'),
                                Text('Límite: ${res.meta.limit}'),
                                IconButton.outlined(
                                  tooltip: 'Recargar',
                                  onPressed: () => _search(page: res.meta.page),
                                  icon: const Icon(Icons.refresh),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),

                          Expanded(
                            child: ListView.separated(
                              itemCount: items.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final s = items[i];
                                final typeText = s.type?.label ?? '—';
                                final subtitleBits = <String>[
                                  'Tipo: $typeText',
                                  if (s.dateInsert != null) 'Alta: ${s.dateInsert!.toLocal()}',
                                ];
                                return ListTile(
                                  leading: CircleAvatar(
                                    child: Text(s.name.isNotEmpty ? s.name[0].toUpperCase() : '?'),
                                  ),
                                  title: Text(
                                    '${s.name}  (#${s.id})',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    subtitleBits.join(' · '),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => _openPreviewDialog(s.id),
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
                                onPressed: res.meta.page > 1
                                    ? () => _search(page: res.meta.page - 1)
                                    : null,
                                label: const Text('Anterior'),
                              ),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.chevron_right),
                                onPressed: (res.meta.page < res.meta.totalPages)
                                    ? () => _search(page: res.meta.page + 1)
                                    : null,
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
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openPreviewDialog(int surveyId) async {
    try {
      final tree = await _repo.getTree(surveyId);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        useRootNavigator: true,
        builder: (_) => AlertDialog(
          title: Text('Formulario #${tree.id} — ${tree.name}'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SizedBox(
              width: 600,
              height: 420,
              child: Scrollbar(
                child: ListView(
                  children: [
                    for (final sec in tree.sections) ...[
                      Text(
                        '${sec.order}. ${sec.name}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      if (sec.questions.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(left: 12, bottom: 8),
                          child: Text('— (sin preguntas)'),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.only(left: 12, bottom: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: sec.questions
                                .map((q) => Text('• ${q.order}. ${q.name}'))
                                .toList(),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(context, rootNavigator: true).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cargar el formulario: $e')),
      );
    }
  }
}
