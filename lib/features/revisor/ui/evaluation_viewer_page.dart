import 'package:flutter/material.dart';

import '../../surveys/data/surveys_repository.dart';
import '../../surveys/data/survey_models.dart';
import '../../evaluations/data/evaluations_repository.dart';

class EvaluationViewerPage extends StatefulWidget {
  final int evaluationId;
  const EvaluationViewerPage({super.key, required this.evaluationId});

  @override
  State<EvaluationViewerPage> createState() => _EvaluationViewerPageState();
}

class _EvaluationViewerPageState extends State<EvaluationViewerPage> {
  final _evals = EvaluationsRepository();
  final _surveys = SurveysRepository();

  bool _loading = true;
  String? _error;

  late int _surveyId;
  late String _surveyName = '';

  SurveyTree? _tree;

  final Map<int, Map<int?, Map<int, String?>>> _answersIndex = {};

  final Map<int, _QExt> _extCache = {};

  int _secIndex = 0;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _evals.dispose();
    _surveys.dispose();
    super.dispose();
  }

  int? _asIntOrNull(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  int? _pickFirstInt(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v != null) {
        final n = _asIntOrNull(v);
        if (n != null) return n;
      }
    }
    return null;
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final view = await _evals.view(widget.evaluationId);

      final eval = (view['evaluation'] as Map).cast<String, dynamic>();
      final survey = (view['survey'] as Map).cast<String, dynamic>();
      _surveyId = (survey['id'] as num).toInt();
      _surveyName = (survey['name'] ?? 'Formulario $_surveyId').toString();

      final tree = await _surveys.getTree(_surveyId);

      _answersIndex.clear();
      final secs = (view['sections'] as List?) ?? const [];
      for (final s in secs.whereType<Map>()) {
        final qs = (s['questions'] as List?) ?? const [];
        for (final q in qs.whereType<Map>()) {
          final qq = q.cast<String, dynamic>();
          final qId = (qq['id'] as num).toInt();

          final rawAnswers = (qq['answers'] as List?) ??
              (qq['answer'] != null ? [qq['answer']] : const []);

          final perItem = <int?, Map<int, String?>>{};

          for (final a0 in rawAnswers.whereType<Map>()) {
            final a = a0.cast<String, dynamic>();

            final itemKey = _pickFirstInt(a, [
              'idItem',
              'itemId',
              'idQuestion', 
              'questionId',
              'idQuestionList',
              'idQuestionListItem',
              'questionListItemId',
              'id_question_list',
              'id_question_list_item',
            ]);

            final respId = _pickFirstInt(a, [
              'idResponse',
              'responseId',
              'id',
              'id_response',
            ]);
            if (respId == null) continue;

            final val = a['value']?.toString();

            if (itemKey != null) {
              perItem.putIfAbsent(itemKey, () => <int, String?>{});
              perItem[itemKey]![respId] = val;
            }

            perItem.putIfAbsent(null, () => <int, String?>{});
            perItem[null]![respId] = val;
          }

          _answersIndex[qId] = perItem;
        }
      }

      setState(() {
        _tree = tree;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<_QExt> _getExt(int questionId) async {
    final cached = _extCache[questionId];
    if (cached != null) return cached;

    final ext = await _surveys.getQuestionExtended(questionId);

    List respRaw = const [];
    if (ext['responses'] is List) {
      respRaw = ext['responses'];
    } else if (ext['data'] is List) {
      respRaw = ext['data'];
    }

    final responses = respRaw
        .whereType<Map>()
        .map((m) => _ResponseExt.fromJson(m.cast<String, dynamic>()))
        .toList()
      ..sort((a, b) => (a.order ?? 0).compareTo(b.order ?? 0));

    final itemsRaw = (ext['items'] as List?) ?? const [];
    final items = itemsRaw
        .whereType<Map>()
        .map((m) => _ItemExt.fromJson(m.cast<String, dynamic>()))
        .toList()
      ..sort((a, b) => (a.order ?? 0).compareTo(b.order ?? 0));

    final model = _QExt(responses: responses, items: items);
    _extCache[questionId] = model;
    return model;
  }

  void _goSec(int idx) => setState(() => _secIndex = idx);

  _SectionState _computeSectionState(SurveySectionNode sec) {
    int totalQ = sec.questions.length;
    int answered = 0;

    for (final q in sec.questions) {
      final perItem = _answersIndex[q.id];
      if (perItem == null || perItem.isEmpty) continue;

      final hasAny = perItem.values.any((byResp) => byResp.isNotEmpty);
      if (hasAny) answered++;
    }

    if (answered == 0) return _SectionState.red;
    if (answered < totalQ) return _SectionState.orange;
    return _SectionState.green;
  }

  Color _colorFor(_SectionState s, ThemeData t) {
    switch (s) {
      case _SectionState.green:
        return Colors.green.shade600;
      case _SectionState.orange:
        return Colors.orange.shade700;
      case _SectionState.red:
        return Colors.red.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    Widget body() {
      if (_loading) return const Center(child: CircularProgressIndicator());
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
          child: Text('Este formulario no tiene secciones.'),
        );
      }

      final sec = tree.sections[_secIndex];

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 240, maxWidth: 280),
            child: Card(
              margin: const EdgeInsets.fromLTRB(12, 12, 8, 12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: tree.sections.length,
                  itemBuilder: (_, i) {
                    final s = tree.sections[i];
                    final state = _computeSectionState(s);
                    final color = _colorFor(state, t);
                    final selected = i == _secIndex;

                    return ListTile(
                      dense: true,
                      selected: selected,
                      leading: Icon(Icons.circle, size: 14, color: color),
                      title: Text(
                        '${s.order}. ${s.name}'.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _goSec(i),
                    );
                  },
                ),
              ),
            ),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${sec.order}. ${sec.name}',
                    style: t.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: ListView.separated(
                          itemCount: sec.questions.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (_, i) => _QuestionReadOnly(
                            question: sec.questions[i],
                            getExt: _getExt,
                            answersIndex: _answersIndex,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Evaluación #${widget.evaluationId} — $_surveyName'),
      ),
      body: body(),
    );
  }
}

enum _SectionState { green, orange, red }

class _QExt {
  final List<_ResponseExt> responses;
  final List<_ItemExt> items;
  const _QExt({required this.responses, required this.items});
}

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
    String? asStr(dynamic v) {
      final s = v?.toString();
      return (s == null || s.trim().isEmpty) ? null : s;
    }

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

  factory _ItemExt.fromJson(Map<String, dynamic> json) => _ItemExt(
        id: (json['id'] as num).toInt(),
        name: (json['name'] ?? '').toString(),
        order: (json['order'] is num)
            ? (json['order'] as num).toInt()
            : int.tryParse('${json['order'] ?? ''}'),
      );
}

class _QuestionReadOnly extends StatelessWidget {
  final SurveyQuestionNode question;
  final Future<_QExt> Function(int qId) getExt;
  final Map<int, Map<int?, Map<int, String?>>> answersIndex;

  const _QuestionReadOnly({
    required this.question,
    required this.getExt,
    required this.answersIndex,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: FutureBuilder<_QExt>(
        future: getExt(question.id),
        builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(),
            );
          }
          if (snap.hasError) {
            return Text('Error cargando catálogo: ${snap.error}');
          }
          final ext = snap.data!;
          final hasItems = ext.items.isNotEmpty;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${question.order}. ${question.name}',
                style: t.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              if (hasItems)
                _ItemsTableReadOnly(
                  questionId: question.id,
                  items: ext.items,
                  responses: ext.responses,
                  answersIndex: answersIndex,
                )
              else
                _ResponsesReadOnly(
                  questionId: question.id,
                  responses: ext.responses,
                  answersIndex: answersIndex,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ResponsesReadOnly extends StatelessWidget {
  final int questionId;
  final List<_ResponseExt> responses;
  final Map<int, Map<int?, Map<int, String?>>> answersIndex;

  const _ResponsesReadOnly({
    required this.questionId,
    required this.responses,
    required this.answersIndex,
  });

  @override
  Widget build(BuildContext context) {
    final byResp = answersIndex[questionId]?[null] ?? const <int, String?>{};

    final allSelectable =
        responses.every((r) => (r.type == null || r.type == 0));
    if (allSelectable) {
      return Column(
        children: responses
            .map(
              (r) => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: byResp.containsKey(r.id),
                onChanged: null,
                title: Text(r.name),
              ),
            )
            .toList(),
      );
    }

    return Column(
      children: responses.map((r) {
        final type = r.type ?? 0;
        switch (type) {
          case 0:
            return CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: byResp.containsKey(r.id),
              onChanged: null,
              title: Text(r.name),
            );
          case 1:
          case 2:
          default:
            final value = byResp[r.id] ?? '';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: TextField(
                enabled: false,
                controller: TextEditingController(text: value),
                decoration: InputDecoration(labelText: r.name),
              ),
            );
        }
      }).toList(),
    );
  }
}

class _ItemsTableReadOnly extends StatelessWidget {
  final int questionId;
  final List<_ItemExt> items;
  final List<_ResponseExt> responses;
  final Map<int, Map<int?, Map<int, String?>>> answersIndex;

  const _ItemsTableReadOnly({
    required this.questionId,
    required this.items,
    required this.responses,
    required this.answersIndex,
  });

  @override
  Widget build(BuildContext context) {
    final perItem =
        answersIndex[questionId] ?? const <int?, Map<int, String?>>{};

    final allSelectable =
        responses.every((r) => (r.type == null || r.type == 0));

    return Table(
      columnWidths: {
        0: const FlexColumnWidth(2),
        for (int i = 0; i < responses.length; i++)
          (i + 1): const FlexColumnWidth(1),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Ítem',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            for (final r in responses)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Align(
                  alignment: allSelectable
                      ? Alignment.center
                      : Alignment.centerLeft,
                  child: Text(
                    r.name,
                    textAlign:
                        allSelectable ? TextAlign.center : TextAlign.left,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
          ],
        ),

        for (final it in items)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(it.name),
              ),
              for (final r in responses)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Builder(
                    builder: (_) {
                      final byResp =
                          perItem[it.id] ?? const <int, String?>{};
                      final type = r.type ?? 0;
                      if (type == 0) {
                        return _RadioFake(
                          selected: byResp.containsKey(r.id),
                        );
                      } else {
                        final value = byResp[r.id] ?? '';
                        return value.isEmpty
                            ? const SizedBox.shrink()
                            : Text(value);
                      }
                    },
                  ),
                ),
            ],
          ),
      ],
    );
  }
}


class _RadioFake extends StatelessWidget {
  final bool selected;
  const _RadioFake({required this.selected});

  @override
  Widget build(BuildContext context) {
    return Icon(
      selected
          ? Icons.radio_button_checked
          : Icons.radio_button_unchecked,
      size: 20,
      color: selected
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).disabledColor,
    );
  }
}
