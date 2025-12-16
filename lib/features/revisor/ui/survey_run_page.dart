import 'package:flutter/material.dart';

import '../../surveys/data/surveys_repository.dart';
import '../../surveys/data/survey_models.dart';
import '../../evaluations/data/evaluations_repository.dart';

import '../../../core/auth/auth_repository.dart';
import 'package:go_router/go_router.dart';

class SurveyRunPage extends StatefulWidget {
  final int patientId;
  final int surveyId;

  const SurveyRunPage({
    super.key,
    required this.patientId,
    required this.surveyId,
  });

  @override
  State<SurveyRunPage> createState() => _SurveyRunPageState();
}

class _SurveyRunPageState extends State<SurveyRunPage> {
  final _repo = SurveysRepository();
  final _evals = EvaluationsRepository();

  bool _loading = true;
  String? _error;

  SurveyTree? _tree;
  int _secIndex = 0;

  final Map<String, dynamic> _answers = {};

  final Map<int, List<_ResponseExt>> _responsesCache = {};
  final Map<int, List<_ItemExt>> _itemsCache = {};

  final Map<int, int> _listIdByQuestion = {};

  final Map<int, bool> _sectionActive = {};

  final Map<int, int> _sectionByQuestionId = {};

  final Map<int, Future<void>> _questionLoadFutures = {};

  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _repo.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tree = await _repo.getTree(widget.surveyId);

      final secByQ = <int, int>{};
      for (final s in tree.sections) {
        for (final q in s.questions) {
          secByQ[q.id] = s.id;
        }
      }

      if (!mounted) return;

      final secMap = <int, bool>{};
      for (final sec in tree.sections) {
        secMap[sec.id] = true;
      }

      setState(() {
        _tree = tree;
        _secIndex = 0;
        _sectionActive
          ..clear()
          ..addAll(secMap);
        _sectionByQuestionId
          ..clear()
          ..addAll(secByQ);
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

  String _keyFor(int qId, int rId) => 'q${qId}_r${rId}';

  T? _getAnswer<T>(int qId, int rId) {
    final v = _answers[_keyFor(qId, rId)];
    return (v is T) ? v : null;
  }

  void _setAnswer(int qId, int rId, dynamic value) {
    setState(() => _answers[_keyFor(qId, rId)] = value);
  }

  String _keyForItemRadio(int qId, int itemQuestionId) =>
      'q${qId}_item${itemQuestionId}_radio';
  String _keyForItemVal(int qId, int rId, int itemQuestionId) =>
      'q${qId}_r${rId}_item${itemQuestionId}';

  int? _getItemRadio(int qId, int itemQuestionId) {
    final v = _answers[_keyForItemRadio(qId, itemQuestionId)];
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '');
  }

  void _setItemRadio(int qId, int itemQuestionId, int responseId) {
    setState(() => _answers[_keyForItemRadio(qId, itemQuestionId)] = responseId);
  }

  String _getItemValStr(int qId, int rId, int itemQuestionId) {
    final v = _answers[_keyForItemVal(qId, rId, itemQuestionId)];
    return (v == null) ? '' : v.toString();
  }

  void _setItemVal(int qId, int rId, int itemQuestionId, String value) {
    setState(() => _answers[_keyForItemVal(qId, rId, itemQuestionId)] = value);
  }

  Future<int?> _ensureListId(int questionId) async {
    final v = _listIdByQuestion[questionId];
    if (v != null) return v;
    await _loadQuestionExtended(questionId);
    return _listIdByQuestion[questionId];
  }

  Future<void> _loadQuestionExtended(int questionId) async {
    final hasResp = _responsesCache.containsKey(questionId);
    final hasItems = _itemsCache.containsKey(questionId);
    if (hasResp && hasItems && _listIdByQuestion.containsKey(questionId)) return;

    final ext = await _repo.getQuestionExtended(questionId) as Map;

    final rawResp = (ext['responses'] is List)
        ? (ext['responses'] as List)
        : (ext['data'] is List)
            ? (ext['data'] as List)
            : const [];

    final responses = rawResp
        .whereType<Map>()
        .map((m) =>
            _ResponseExt.fromJson(Map<String, dynamic>.from(m as Map)))
        .toList()
      ..sort((a, b) => (a.order ?? 0).compareTo(b.order ?? 0));
    _responsesCache[questionId] = responses;

    final rawItems = (ext['items'] is List) ? (ext['items'] as List) : const [];
    final items = rawItems
        .whereType<Map>()
        .map((m) => _ItemExt.fromJson(Map<String, dynamic>.from(m as Map)))
        .toList()
      ..sort((a, b) => (a.order ?? 0).compareTo(b.order ?? 0));
    _itemsCache[questionId] = items;

    final parentSecId = _sectionByQuestionId[questionId];
    if (parentSecId != null) {
      for (final it in items) {
        _sectionByQuestionId[it.id] = parentSecId;
      }
    }

    final dynamic rawListId =
        (ext['idQuestionList'] ??
            ext['questionListId'] ??
            ext['listId'] ??
            (ext['questionList'] is Map
                ? (ext['questionList'] as Map)['id']
                : null));

    final int? listId = (rawListId is num)
        ? rawListId.toInt()
        : int.tryParse('${rawListId ?? ''}');
    if (listId != null) {
      _listIdByQuestion[questionId] = listId;
    }
  }

  Future<void> _loadQuestionExtendedOnce(int questionId) {
    return _questionLoadFutures[questionId] ??=
        _loadQuestionExtended(questionId);
  }

  bool _hasOptional(SurveySectionNode sec) =>
      (sec.questionOptional != null &&
          sec.questionOptional!.trim().isNotEmpty);

  bool _isActive(SurveySectionNode sec) => _sectionActive[sec.id] ?? true;

  bool _isSectionComplete(SurveySectionNode sec) {
    if (!_isActive(sec)) return false;
    for (final q in sec.questions) {
      final items = _itemsCache[q.id];
      if (items != null && items.isNotEmpty) {
        final resps = _responsesCache[q.id];
        if (resps == null || resps.isEmpty) return false;

        if (!_listIdByQuestion.containsKey(q.id)) return false;

        final hasRadio = resps.any((r) => (r.type ?? 0) == 0);
        final hasFill =
            resps.any((r) => (r.type ?? 0) == 1 || (r.type ?? 0) == 2);

        for (final it in items) {
          if (hasRadio && _getItemRadio(q.id, it.id) == null) return false;
          if (hasFill) {
            for (final r in resps) {
              final t = r.type ?? 0;
              if (t == 1 || t == 2) {
                if (_getItemValStr(q.id, r.id, it.id).trim().isEmpty) {
                  return false;
                }
              }
            }
          }
        }
        continue;
      }

      final rs = _responsesCache[q.id];
      if (rs == null || rs.isEmpty) return false;

      bool answered = false;
      for (final r in rs) {
        final k = _keyFor(q.id, r.id);
        final v = _answers[k];
        if ((r.type ?? 0) == 0) {
          if (v is bool && v == true) {
            answered = true;
            break;
          }
        } else {
          if (v is String && v.trim().isNotEmpty) {
            answered = true;
            break;
          }
        }
      }
      if (!answered) return false;
    }
    return true;
  }

  Future<bool> _validateAll() async {
    if (_tree == null) return false;

    for (final sec in _tree!.sections) {
      if (!_isActive(sec)) continue;

      for (final q in sec.questions) {
        await _loadQuestionExtended(q.id);
        final items = _itemsCache[q.id] ?? const <_ItemExt>[];

        if (items.isNotEmpty) {
          final resps = _responsesCache[q.id] ?? const <_ResponseExt>[];
          final hasRadio = resps.any((r) => (r.type ?? 0) == 0);
          final hasFill =
              resps.any((r) => (r.type ?? 0) == 1 || (r.type ?? 0) == 2);

          if (!_listIdByQuestion.containsKey(q.id)) {
            final got = await _ensureListId(q.id);
            if (got == null) return false;
          }

          for (final it in items) {
            if (hasRadio && _getItemRadio(q.id, it.id) == null) return false;
            if (hasFill) {
              for (final r in resps) {
                final t = r.type ?? 0;
                if (t == 1 || t == 2) {
                  if (_getItemValStr(q.id, r.id, it.id)
                      .trim()
                      .isEmpty) return false;
                }
              }
            }
          }
          continue;
        }

        final rs = _responsesCache[q.id] ?? const <_ResponseExt>[];
        bool answered = false;
        for (final r in rs) {
          final k = _keyFor(q.id, r.id);
          final v = _answers[k];
          final t = r.type ?? 0;
          if (t == 0 && v is bool && v == true) {
            answered = true;
            break;
          }
          if (t != 0 && v is String && v.trim().isNotEmpty) {
            answered = true;
            break;
          }
        }
        if (!answered) return false;
      }
    }
    return true;
  }

  Future<List<AnswerInput>> _buildAnswersPayload() async {
    final List<AnswerInput> result = [];
    if (_tree == null) return result;

    for (final sec in _tree!.sections) {
      if (!_isActive(sec)) continue;

      for (final q in sec.questions) {
        await _loadQuestionExtended(q.id);
        final items = _itemsCache[q.id] ?? const <_ItemExt>[];

        if (items.isNotEmpty) {
          final resps = _responsesCache[q.id] ?? const <_ResponseExt>[];
          int? listId = _listIdByQuestion[q.id] ?? await _ensureListId(q.id);
          if (listId == null) {
            continue;
          }

          for (final it in items) {
            final secIdIt = _sectionByQuestionId[it.id] ?? sec.id;
            for (final r in resps) {
              final t = r.type ?? 0;
              if (t == 0) {
                final respId = _getItemRadio(q.id, it.id);
                if (respId != null) {
                  result.add(AnswerInput(
                    idSection: secIdIt,
                    idQuestion: it.id,
                    idResponse: respId,
                    idQuestionList: listId,
                  ));
                }
              } else {
                final s =
                    _getItemValStr(q.id, r.id, it.id).trim();
                if (s.isNotEmpty) {
                  result.add(AnswerInput(
                    idSection: secIdIt,
                    idQuestion: it.id,
                    idResponse: r.id,
                    idQuestionList: listId,
                    value: s,
                  ));
                }
              }
            }
          }
          continue;
        }

        final rs = _responsesCache[q.id] ?? const <_ResponseExt>[];
        final secIdQ = _sectionByQuestionId[q.id] ?? sec.id;

        for (final r in rs) {
          final k = _keyFor(q.id, r.id);
          final v = _answers[k];
          final t = r.type ?? 0;

          if (t == 0) {
            if (v is bool && v == true) {
              result.add(AnswerInput(
                idSection: secIdQ,
                idQuestion: q.id,
                idResponse: r.id,
              ));
            }
          } else {
            final s = (v is String) ? v.trim() : '';
            if (s.isNotEmpty) {
              result.add(AnswerInput(
                idSection: secIdQ,
                idQuestion: q.id,
                idResponse: r.id,
                value: s,
              ));
            }
          }
        }
      }
    }

    return result;
  }

  Future<void> _finish() async {
    final ok = await _validateAll();
    if (!ok) {
      _showError(
          'Debes completar todas las preguntas de las secciones activas.');
      return;
    }

    setState(() => _finishing = true);

    try {
      final me = await AuthRepository().me();
      final int myId = me.userId;
      final bool isRevisor = (me.roles['revisor'] == true);

      final evalId = await _evals.create(
        patientId: widget.patientId,
        surveyId: widget.surveyId,
        idRevisor: isRevisor ? myId : null,
      );

      final payload = await _buildAnswersPayload();
      await _evals.saveAnswers(evaluationId: evalId, answers: payload);

      await _evals.submit(evalId);

      if (!mounted) return;

      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AlertDialog(
          title: Text('Éxito'),
          content: Text('Formulario guardado correctamente.'),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (mounted) {
        context.go('/revisor/pacientes/${widget.patientId}');
      }
    } catch (e) {
      _showError('No se pudo finalizar: $e');
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _buildSidebar(SurveyTree tree) {
    final scheme = Theme.of(context).colorScheme;

    Color dotFor(SurveySectionNode s) {
      if (_hasOptional(s) && !_isActive(s)) return Colors.orange.shade600;
      if (_isSectionComplete(s)) return Colors.green.shade600;
      if (_isActive(s)) return Colors.red.shade600;
      return scheme.outline;
    }

    return Container(
      width: 280,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Secciones',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              itemCount: tree.sections.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final s = tree.sections[i];
                final selected = i == _secIndex;
                final color = dotFor(s);
                return ListTile(
                  selected: selected,
                  selectedTileColor:
                      scheme.primary.withOpacity(0.06),
                  leading: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  title: Text(
                    '${s.order}. ${s.name}'.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: _hasOptional(s)
                      ? const Text('Sección opcional',
                          style: TextStyle(
                              fontStyle: FontStyle.italic))
                      : null,
                  onTap: () => setState(() => _secIndex = i),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionBody(SurveySectionNode sec) {
    final scheme = Theme.of(context).colorScheme;
    final qs = sec.questions;

    final hasTriggerText = _hasOptional(sec);
    final active = _isActive(sec);

    final contentCard = Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (hasTriggerText)
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: Row(
                  children: [
                    Expanded(
                        child:
                            Text(sec.questionOptional!.trim())),
                    const SizedBox(width: 8),
                    Switch(
                      value: active,
                      onChanged: (v) => setState(
                          () => _sectionActive[sec.id] = v),
                    ),
                  ],
                ),
              ),
            const Divider(height: 1),
            if (!active)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                    'Sección excluida. No es necesario responder estas preguntas.',
                    style: TextStyle(
                        fontStyle: FontStyle.italic)),
              )
            else if (qs.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                    'Esta sección no contiene preguntas.'),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: qs.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final q = qs[index];
                    return _QuestionCard(
                      question: q,
                      loadExtended: _loadQuestionExtendedOnce,
                      getResponses: (qId) =>
                          _responsesCache[qId] ??
                          const <_ResponseExt>[],
                      getItems: (qId) =>
                          _itemsCache[qId] ??
                          const <_ItemExt>[],
                      getAnswer: _getAnswer,
                      setAnswer: _setAnswer,
                      getItemRadio: _getItemRadio,
                      setItemRadio: _setItemRadio,
                      getItemValStr: _getItemValStr,
                      setItemVal: _setItemVal,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: Padding(
          padding:
              const EdgeInsets.fromLTRB(0, 16, 16, 16),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(
                    bottom: 8, left: 4, right: 4),
                child: Row(
                  children: [
                    Text(
                      'Sección ${_secIndex + 1} de ${_tree!.sections.length}',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                              fontWeight:
                                  FontWeight.w700),
                    ),
                    const Spacer(),
                    if (_isSectionComplete(sec))
                      Chip(
                        label: const Text('Completa'),
                        avatar: const Icon(Icons.check,
                            size: 18),
                        backgroundColor:
                            Colors.green.shade50,
                        side: BorderSide(
                            color:
                                Colors.green.shade600),
                      )
                    else if (_hasOptional(sec) &&
                        !_isActive(sec))
                      Chip(
                        label: const Text(
                            'Opcional (excluida)'),
                        avatar: const Icon(
                            Icons.info_outline,
                            size: 18),
                        backgroundColor:
                            Colors.orange.shade50,
                        side: BorderSide(
                            color:
                                Colors.orange.shade600),
                      )
                    else
                      Chip(
                        label: const Text('Pendiente'),
                        avatar: const Icon(
                            Icons.warning_amber_rounded,
                            size: 18),
                        backgroundColor:
                            Colors.red.shade50,
                        side: BorderSide(
                            color:
                                Colors.red.shade600),
                      ),
                  ],
                ),
              ),
              Expanded(child: contentCard),
              Container(
                decoration: BoxDecoration(
                    border: Border(
                        top: BorderSide(
                            color:
                                scheme.outlineVariant))),
                padding:
                    const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    Text('Sección ${_secIndex + 1}'),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _secIndex > 0 &&
                              !_finishing
                          ? () => setState(
                              () => _secIndex--)
                          : null,
                      icon: const Icon(
                          Icons.chevron_left),
                      label: const Text('Anterior'),
                    ),
                    const SizedBox(width: 8),
                    if (_secIndex <
                        (_tree?.sections.length ?? 1) -
                            1)
                      FilledButton.icon(
                        onPressed: !_finishing
                            ? () => setState(
                                () => _secIndex++)
                            : null,
                        icon: const Icon(
                            Icons.chevron_right),
                        label: const Text('Siguiente'),
                      )
                    else
                      FilledButton.icon(
                        onPressed:
                            !_finishing ? _finish : null,
                        icon: _finishing
                            ? const Icon(
                                Icons.hourglass_top)
                            : const Icon(Icons.flag),
                        label: Text(_finishing
                            ? 'Guardando…'
                            : 'Finalizar'),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget body() {
      if (_loading) {
        return const Center(
            child: CircularProgressIndicator());
      }
      if (_error != null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Error: $_error'),
          ),
        );
      }
      final tree = _tree!;
      if (tree.sections.isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
                'Este formulario no tiene secciones.'),
          ),
        );
      }
      final sec = tree.sections[_secIndex];
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSidebar(tree),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(
                  right: 16, top: 16, bottom: 16),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: _buildSectionBody(sec),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
            'Formulario #${widget.surveyId} • Paciente #${widget.patientId}'),
      ),
      body: body(),
    );
  }
}

// ----------------- modelos auxiliares -----------------

class _ResponseExt {
  final int id;
  final String name;
  final int? type;
  final String? min;
  final String? max;
  final String? unity;
  final int? order;

  _ResponseExt({
    required this.id,
    required this.name,
    this.type,
    this.min,
    this.max,
    this.unity,
    this.order,
  });

  factory _ResponseExt.fromJson(Map<String, dynamic> json) {
    int? asInt(dynamic v) =>
        (v is num) ? v.toInt() : int.tryParse('${v ?? ''}');
    String? asStr(dynamic v) =>
        (v == null) ? null : v.toString();
    return _ResponseExt(
      id: (json['id'] as num).toInt(),
      name: (json['name'] ?? '').toString(),
      type: asInt(json['type']),
      min: asStr(json['min']),
      max: asStr(json['max']),
      unity: asStr(json['unity']),
      order: asInt(json['order']),
    );
  }
}

class _ItemExt {
  final int id;
  final String name;
  final int? order;

  _ItemExt({required this.id, required this.name, this.order});

  factory _ItemExt.fromJson(Map<String, dynamic> json) {
    int? asInt(dynamic v) =>
        (v is num) ? v.toInt() : int.tryParse('${v ?? ''}');
    return _ItemExt(
      id: (json['id'] as num).toInt(),
      name: (json['name'] ?? '').toString(),
      order: asInt(json['order']),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final SurveyQuestionNode question;

  final Future<void> Function(int qId) loadExtended;
  final List<_ResponseExt> Function(int qId) getResponses;
  final List<_ItemExt> Function(int qId) getItems;

  final T? Function<T>(int qId, int rId) getAnswer;
  final void Function(int qId, int rId, dynamic value)
      setAnswer;

  final int? Function(int qId, int itemQuestionId)
      getItemRadio;
  final void Function(
          int qId, int itemQuestionId, int responseId)
      setItemRadio;
  final String Function(int qId, int rId, int itemQuestionId)
      getItemValStr;
  final void Function(
          int qId, int rId, int itemQuestionId, String value)
      setItemVal;

  const _QuestionCard({
    required this.question,
    required this.loadExtended,
    required this.getResponses,
    required this.getItems,
    required this.getAnswer,
    required this.setAnswer,
    required this.getItemRadio,
    required this.setItemRadio,
    required this.getItemValStr,
    required this.setItemVal,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<void>(
      future: loadExtended(question.id),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(),
          );
        }
        if (snap.hasError) {
          return Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 8),
            child: Text(
                'Error cargando pregunta: ${snap.error}'),
          );
        }

        final responses = getResponses(question.id);
        final items = getItems(question.id);

        if (items.isNotEmpty) {
          return Card(
            elevation: 0,
            margin: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    '${question.order}. ${question.name}',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(
                            fontWeight:
                                FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  _ItemsMatrix(
                    questionId: question.id,
                    items: items,
                    responses: responses,
                    getItemRadio: getItemRadio,
                    setItemRadio: setItemRadio,
                    getItemValStr: getItemValStr,
                    setItemVal: setItemVal,
                  ),
                ],
              ),
            ),
          );
        }

        return Card(
          elevation: 0,
          margin: const EdgeInsets.symmetric(
              horizontal: 8, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  '${question.order}. ${question.name}',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(
                          fontWeight:
                              FontWeight.w700),
                ),
                const SizedBox(height: 12),
                _ResponsesList(
                  questionId: question.id,
                  responses: responses,
                  getAnswer: getAnswer,
                  setAnswer: setAnswer,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ItemsMatrix extends StatelessWidget {
  final int questionId;
  final List<_ItemExt> items;
  final List<_ResponseExt> responses;

  final int? Function(int qId, int itemQuestionId)
      getItemRadio;
  final void Function(
          int qId, int itemQuestionId, int responseId)
      setItemRadio;
  final String Function(int qId, int rId, int itemQuestionId)
      getItemValStr;
  final void Function(
          int qId, int rId, int itemQuestionId, String value)
      setItemVal;

  const _ItemsMatrix({
    required this.questionId,
    required this.items,
    required this.responses,
    required this.getItemRadio,
    required this.setItemRadio,
    required this.getItemValStr,
    required this.setItemVal,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(
              vertical: 8, horizontal: 12),
          child: Row(
            children: [
              const SizedBox(width: 8),
              const Expanded(child: Text('Ítem')),
              for (final r in responses)
                SizedBox(
                  width: 110,
                  child: Center(
                    child: Text(
                      r.name,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        ...items.map((it) {
          final selectedRadio =
              getItemRadio(questionId, it.id);
          return Container(
            padding: const EdgeInsets.symmetric(
                vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(
                      color: scheme.outlineVariant)),
            ),
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment.center,
              children: [
                const SizedBox(width: 8),
                Expanded(child: Text(it.name)),
                for (final r in responses)
                  SizedBox(
                    width: 110,
                    child: Center(
                      child: () {
                        switch (r.type ?? 0) {
                          case 0:
                            return Radio<int>(
                              value: r.id,
                              groupValue: selectedRadio,
                              onChanged: (v) {
                                if (v != null) {
                                  setItemRadio(
                                      questionId,
                                      it.id,
                                      v);
                                }
                              },
                            );

                          case 1:
                            final ctrl =
                                TextEditingController(
                              text: getItemValStr(
                                  questionId,
                                  r.id,
                                  it.id),
                            );
                            return TextField(
                              controller: ctrl,
                              decoration:
                                  const InputDecoration(
                                isDense: true,
                                hintText: 'Valor',
                              ),
                              onChanged: (s) =>
                                  setItemVal(
                                      questionId,
                                      r.id,
                                      it.id,
                                      s),
                              keyboardType: (r.unity !=
                                          null &&
                                      r.unity!
                                          .isNotEmpty)
                                  ? TextInputType.number
                                  : TextInputType.text,
                            );

                          case 2:
                            final min =
                                double.tryParse(
                                        r.min ?? '') ??
                                    0.0;
                            final max =
                                double.tryParse(
                                        r.max ?? '') ??
                                    100.0;
                            final current = double
                                    .tryParse(
                                        getItemValStr(
                                            questionId,
                                            r.id,
                                            it.id)) ??
                                min;
                            final double clamped =
                                (current.clamp(
                                        min, max)
                                    as double);
                            return Slider(
                              value: clamped,
                              min: min,
                              max: max,
                              divisions: 10,
                              label: clamped
                                  .round()
                                  .toString(),
                              onChanged: (d) =>
                                  setItemVal(
                                      questionId,
                                      r.id,
                                      it.id,
                                      d.toString()),
                            );

                          default:
                            return const SizedBox
                                .shrink();
                        }
                      }(),
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _ResponsesList extends StatelessWidget {
  final int questionId;
  final List<_ResponseExt> responses;
  final T? Function<T>(int qId, int rId) getAnswer;
  final void Function(int qId, int rId, dynamic value)
      setAnswer;

  const _ResponsesList({
    required this.questionId,
    required this.responses,
    required this.getAnswer,
    required this.setAnswer,
  });

  @override
  Widget build(BuildContext context) {
    final allSelectable = responses
        .every((r) => (r.type == null || r.type == 0));

    if (allSelectable) {
      return Column(
        children: [
          for (final r in responses)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(r.name),
              value:
                  getAnswer<bool>(questionId, r.id) ??
                      false,
              onChanged: (v) =>
                  setAnswer(questionId, r.id, v ?? false),
            ),
        ],
      );
    }

    return Column(
      children: [
        for (final r in responses)
          _ResponseInput(
            questionId: questionId,
            response: r,
            getAnswer: getAnswer,
            setAnswer: setAnswer,
          ),
      ],
    );
  }
}

class _ResponseInput extends StatelessWidget {
  final int questionId;
  final _ResponseExt response;
  final T? Function<T>(int qId, int rId) getAnswer;
  final void Function(int qId, int rId, dynamic value)
      setAnswer;

  const _ResponseInput({
    required this.questionId,
    required this.response,
    required this.getAnswer,
    required this.setAnswer,
  });

  @override
  Widget build(BuildContext context) {
    final type = response.type ?? 0;

    switch (type) {
      case 0:
        final checked =
            getAnswer<bool>(questionId, response.id) ??
                false;
        return CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(response.name),
          value: checked,
          onChanged: (v) =>
              setAnswer(questionId, response.id, v ?? false),
        );

      case 1:
        final value =
            getAnswer<String>(questionId, response.id) ??
                '';
        final controller =
            TextEditingController(text: value);
        return Padding(
          padding:
              const EdgeInsets.symmetric(vertical: 6),
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: response.name,
              hintText: (response.unity ?? '')
                      .isNotEmpty
                  ? 'Unidad: ${response.unity}'
                  : null,
            ),
            onChanged: (v) =>
                setAnswer(questionId, response.id, v),
            keyboardType: (response.unity != null &&
                    response.unity!.isNotEmpty)
                ? TextInputType.number
                : TextInputType.text,
          ),
        );

      case 2:
        final min = int.tryParse(response.min ?? '');
        final max = int.tryParse(response.max ?? '');
        final value =
            getAnswer<String>(questionId, response.id) ??
                '';
        final controller =
            TextEditingController(text: value);
        final hint = (min != null || max != null)
            ? '[${min ?? '-'} .. ${max ?? '-'}]'
            : null;
        return Padding(
          padding:
              const EdgeInsets.symmetric(vertical: 6),
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: response.name,
              hintText: hint,
            ),
            onChanged: (v) =>
                setAnswer(questionId, response.id, v),
            keyboardType: TextInputType.number,
          ),
        );

      default:
        final value =
            getAnswer<String>(questionId, response.id) ??
                '';
        final controller =
            TextEditingController(text: value);
        return Padding(
          padding:
              const EdgeInsets.symmetric(vertical: 6),
          child: TextField(
            controller: controller,
            decoration: const InputDecoration(
                labelText: 'Respuesta'),
            onChanged: (v) =>
                setAnswer(questionId, response.id, v),
          ),
        );
    }
  }
}
