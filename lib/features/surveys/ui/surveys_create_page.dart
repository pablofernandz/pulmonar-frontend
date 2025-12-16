import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../data/surveys_repository.dart';
import '../data/survey_models.dart';
import '../../../core/auth/auth_repository.dart'; 
import '../../../core/auth/token_storage.dart';
import '../../../core/env.dart';

import 'dart:convert' show jsonDecode, jsonEncode;


enum SurveyTypeUi { history, revision }
enum _LoadRespMode { choiceFixed, choiceFillable, choiceRange, table }
enum _QuestionUiKind { choice, table }



class _RenderedItem {
  final int id;
  final String name;
  _RenderedItem({required this.id, required this.name});
}

class _RenderedQuestion {
  final int id;
  final String name;
  final int order;
  final List<_RenderedItem> items; 
  _RenderedQuestion({
    required this.id,
    required this.name,
    required this.order,
    required this.items,
  });
}

class _RenderedSection {
  final int id;
  final String name;
  final int order;
  final List<_RenderedQuestion> questions;
  _RenderedSection({
    required this.id,
    required this.name,
    required this.order,
    required this.questions,
  });
}


class _StageResponseNew {
  final String name;
  final int? type;     
  final String? min;
  final String? max;
  final String? unity;

  _StageResponseNew({
    required this.name,
    this.type,
    this.min,
    this.max,
    this.unity,
  });
}

class _StageQuestion {
  final int? existingId;     
  final String? existingName; 
  final String? newName;     

  _QuestionUiKind kind = _QuestionUiKind.choice; 
  String? tableTitle;                             

  final Set<int> selectedResponseIds = {};              
  final Map<int, String> selectedResponseNames = {};   

  final List<_StageResponseNew> newResponses = [];

  int? listId;                  
  final List<_ListItem> listItems = []; 

  List<Map<String, dynamic>> _loadedResponses = []; 

  _StageQuestion.existing({required this.existingId, required this.existingName})
      : newName = null;

  _StageQuestion.newOne(this.newName)
      : existingId = null,
        existingName = null;

  String get label =>
      (existingName?.trim().isNotEmpty ?? false)
          ? existingName!
          : (existingId != null ? 'Pregunta #$existingId' : (newName ?? 'Pregunta'));

  void setLoadedResponses(List<Map<String, dynamic>> rs) {
    _loadedResponses = rs;
  }

  List<Map<String, dynamic>> get loadedResponses => _loadedResponses;
}



class _ListItem {
  final int id;
  final String name;
  final List<Map<String, dynamic>> responses;

  _ListItem({required this.id, required this.name, required this.responses});
}

class _StageSection {
  final int? existingSectionId; 
  String name;                 
  final List<_StageQuestion> questions = [];

  _StageSection.existing({required this.existingSectionId, required this.name});
  _StageSection.newOne({required this.name}) : existingSectionId = null;
}

class SurveysCreatePage extends StatefulWidget {
  const SurveysCreatePage({super.key});
  @override
  State<SurveysCreatePage> createState() => _SurveysCreatePageState();
}

class _SurveysCreatePageState extends State<SurveysCreatePage> {
  final _repo = SurveysRepository();

  final _nameCtrl = TextEditingController();
  SurveyTypeUi? _type;

  int? _createdSurveyId;
  Future<SurveyTree>? _futTree;

  SurveyTree? _tree;     
  bool _loading = false;
  String? _error;

  bool get _isCow => _createdSurveyId != null;
int get _cowSurveyId => _createdSurveyId!;





  bool _creating = false;



  Future<void> _refreshTree() async {
  if (_createdSurveyId == null) return;
  setState(() => _loading = true);
  try {
    final tree = await _repo.getTree(_createdSurveyId!);
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


Future<void> _onAttachQuestionsCow({
  required int surveyId,      
  required int sectionId,     
  required List<int> questionIds,
  int? insertAfterOrder,      
}) async {
  setState(() => _loading = true);
  _error = null;
  try {
    await _repo.attachQuestionsCow(
      surveyId: surveyId,
      sectionId: sectionId,
      questionIds: questionIds,
      insertAfterOrder: insertAfterOrder,
    );
    _tree = await _repo.getTree(surveyId);
  } catch (e) {
    _error = '$e';
  } finally {
    if (mounted) setState(() => _loading = false);
  }
}

Future<void> _onCreateQuestionCow({
  required int surveyId,
  required int sectionId,
  required String name,
  int? targetOrder,           
}) async {
  setState(() => _loading = true);
  _error = null;
  try {
    await _repo.createQuestionCow(
      surveyId: surveyId,
      sectionId: sectionId,
      name: name,
      targetOrder: targetOrder,
    );
    _tree = await _repo.getTree(surveyId);
  } catch (e) {
    _error = '$e';
  } finally {
    if (mounted) setState(() => _loading = false);
  }
}

Future<void> _onDetachQuestionCow({
  required int surveyId,
  required int sectionId,
  required int questionId,
}) async {
  setState(() => _loading = true);
  _error = null;
  try {
    await _repo.detachQuestionCow(
      surveyId: surveyId,
      sectionId: sectionId,
      questionId: questionId,
    );
    _tree = await _repo.getTree(surveyId);
  } catch (e) {
    _error = '$e';
  } finally {
    if (mounted) setState(() => _loading = false);
  }
}

Future<void> _onDetachSection({
  required int surveyId,
  required int sectionId,
}) async {
  setState(() => _loading = true);
  _error = null;
  try {
    await _repo.detachSection(surveyId: surveyId, sectionId: sectionId);
    _tree = await _repo.getTree(surveyId);
  } catch (e) {
    _error = '$e';
  } finally {
    if (mounted) setState(() => _loading = false);
  }
}


  int? _srcSurveyId; 
  String? _srcSurveyName;

  final List<_StageSection> _sections = [];
  final Set<int> _srcSectionIds = {}; 

  bool get _canStageActions =>
      _nameCtrl.text.trim().isNotEmpty && _type != null;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _repo.dispose();
    super.dispose();
  }

  Future<Map<String, String>> _headers() async {
    final token = await TokenStorage.instance.getToken();
    return {
      'Authorization': 'Bearer ${token ?? ''}',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
  }

  Future<List<Map<String, dynamic>>> _getCatalogItems() async {
    final uri = Uri.parse('${Env.apiBaseUrl}/catalog/items');
    final res = await http.get(uri, headers: await _headers());
    if (res.statusCode < 200 || res.statusCode >= 300) return [];
    final decoded = await Future.value(res.body).then((b) => b).then((b) => b);
    final data = (decoded.isNotEmpty) ? decoded : '[]';
    final list = (List.castFrom<dynamic, dynamic>(jsonDecode(data)) as List)
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
    return list;
  }

  Future<List<Map<String, dynamic>>> _getCatalogItemQuestions(int listId) async {
    final uri = Uri.parse('${Env.apiBaseUrl}/catalog/items/$listId/questions');
    final res = await http.get(uri, headers: await _headers());
    if (res.statusCode < 200 || res.statusCode >= 300) return [];
    final decoded = jsonDecode(res.body);
    final list = (decoded is List ? decoded : const [])
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
    return list;
  }

  Future<int?> _ensureQuestionList(int questionId) async {
    try {
      final ext = await _repo.getQuestionExtended(questionId);
      final ql = ext['questionList'];
      if (ql is Map && ql['id'] != null) {
        return (ql['id'] as num).toInt();
      }
      final uri = Uri.parse('${Env.apiBaseUrl}/surveys/questions/$questionId/list');
      final res = await http.post(uri, headers: await _headers());
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      final decoded = jsonDecode(res.body);
      if (decoded is Map && decoded['id'] != null) {
        return (decoded['id'] as num).toInt();
      }
      return null;
    } catch (_) {
      return null;
    }
  }


Future<List<_RenderedSection>> _loadCreatedSurveyPreview(int surveyId) async {
  final tree = await _repo.getTree(surveyId);

  final sectionsOut = <_RenderedSection>[];

  for (final sec in tree.sections) {
    final qsOut = <_RenderedQuestion>[];

    for (final q in sec.questions) {
      Map<String, dynamic> ext = const {};
      try {
        ext = await _repo.getQuestionExtended(q.id);
      } catch (_) {
      }

      int? listId;
      final ql = ext['questionList'];
      if (ql is Map && ql['id'] != null) {
        listId = (ql['id'] as num).toInt();
      } else if (ql != null) {
        listId = int.tryParse(ql.toString());
      }

      final items = <_RenderedItem>[];
      if (listId != null) {
        try {
          final raw = await _repo.getListQuestions(listId);
          for (final m in raw) {
            final id = (m['id'] as num?)?.toInt();
            final name = (m['name'] ?? '').toString();
            if (id != null) {
              items.add(_RenderedItem(id: id, name: name.isEmpty ? 'Pregunta #$id' : name));
            }
          }
        } catch (_) {
        }
      }

      qsOut.add(_RenderedQuestion(
        id: q.id,
        name: q.name,
        order: q.order,
        items: items,
      ));
    }

    sectionsOut.add(_RenderedSection(
      id: sec.id,
      name: sec.name,
      order: sec.order,
      questions: qsOut,
    ));
  }

  return sectionsOut;
}


  

  Future<void> _pickAndStageSourceSurvey() async {
    final res = await _repo.search(
      type: _type == null ? null : (_type == SurveyTypeUi.history ? 0 : 1),
      limit: 20,
      orderBy: 'date_insert',
      orderDir: 'DESC',
      page: 1,
    );
    if (!mounted) return;
    final selectedId = await showDialog<int>(
      context: context,
      useRootNavigator: true,
      builder: (_) => SimpleDialog(
        title: const Text('Selecciona un formulario origen'),
        children: [
          for (final s in res.items)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context, rootNavigator: true).pop(s.id),
              child: Text('${s.name}  (#${s.id})'),
            ),
        ],
      ),
    );
    if (selectedId == null) return;

    try {
      final tree = await _repo.getTree(selectedId);
      if (!mounted) return;

      setState(() {
        _srcSurveyId = tree.id;
        _srcSurveyName = tree.name;

        for (final s in tree.sections) {
          final stageSec = _StageSection.existing(
            existingSectionId: s.id,
            name: s.name,
          );
          for (final q in s.questions) {
            stageSec.questions.add(
              _StageQuestion.existing(existingId: q.id, existingName: q.name),
            );
          }
          _sections.add(stageSec);
          _srcSectionIds.add(s.id); 
        }
      });


      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Se cargará el contenido de "$_srcSurveyName"')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo leer el formulario: $e')),
      );
    }
  }

  Future<void> _pickAndAttachSections() async {
    final items = await _repo.searchSections(limit: 50, orderBy: 'name', orderDir: 'ASC');
    if (!mounted) return;

    final selected = <int>{};
    final picked = await showDialog<List<int>>(
      context: context,
      useRootNavigator: true,
      builder: (_) => StatefulBuilder(
        builder: (_, setSt) => AlertDialog(
          title: const Text('Selecciona secciones a adjuntar'),
          content: SizedBox(
            width: 500, height: 420,
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (_, i) {
                final it = items[i]; 
                final int id = (it['id'] as num).toInt();
                final String name = (it['name'] ?? '').toString();
                final on = selected.contains(id);
                return CheckboxListTile(
                  value: on,
                  onChanged: (v) => setSt(() {
                    if (v == true) {
                      selected.add(id);
                    } else {
                      selected.remove(id);
                    }
                  }),
                  title: Text(name),
                  controlAffinity: ListTileControlAffinity.leading,
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context, rootNavigator: true).pop(null),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context, rootNavigator: true).pop(selected.toList()),
              child: const Text('Añadir'),
            ),
          ],
        ),
      ),
    );

    if (picked == null || picked.isEmpty) return;

    setState(() {
      final existingIds = _sections
          .where((s) => s.existingSectionId != null)
          .map((s) => s.existingSectionId!)
          .toSet();

      for (final id in picked) {
        if (existingIds.contains(id)) continue;
        final found = items.firstWhere((m) => (m['id'] as num).toInt() == id);
        final stageSec = _StageSection.existing(
          existingSectionId: id,
          name: (found['name'] ?? '').toString(),
        );
        _sections.add(stageSec);
      }
    });
  }

Future<void> _stageCreateSection() async {
  final name = await _askText(title: 'Nueva sección', label: 'Nombre de la sección');
  if (name == null || name.trim().isEmpty) return;
setState(() {
  _sections.add(_StageSection.newOne(name: name.trim()));
});
}

Future<void> _stageCreateQuestion(_StageSection sec) async {
  final name = await _askText(title: 'Nueva pregunta', label: 'Texto / enunciado');
  if (name == null || name.trim().isEmpty) return;
setState(() {
  sec.questions.add(_StageQuestion.newOne(name.trim()));
});

}


  void _moveSection(int idx, int dir) {
  final newIdx = (idx + dir).clamp(0, _sections.length - 1);
  if (newIdx == idx) return;
  setState(() {
    final item = _sections.removeAt(idx);
    _sections.insert(newIdx, item);
  });
  }

  void _removeSection(int idx) {
     if (idx < 0 || idx >= _sections.length) return;
     setState(() {
       _sections.removeAt(idx);
     });
  }


void _invalidateSource() {
  setState(() {
    _srcSurveyId = null;
    _srcSurveyName = null;
  });

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Origen desmarcado.')),
  );
}




void _clearSource() {
  setState(() {
    _srcSurveyId = null;
    _srcSurveyName = null;

    if (_srcSectionIds.isNotEmpty) {
      _sections.removeWhere((sec) =>
        sec.existingSectionId != null &&
        _srcSectionIds.contains(sec.existingSectionId!)
      );
      _srcSectionIds.clear();
    }
  });
}

void _clearAllStaging() {
  setState(() {
    _srcSurveyId = null;
    _srcSurveyName = null;
    _sections.clear();
    _createdSurveyId = null;
    _futTree = null;
  });
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Formulario limpiado.')),
  );
}



  Future<void> _stageLoadQuestions(_StageSection sec) async {
    final list = await _repo.searchQuestionsAll(
    pageSize: 400,
    orderBy: 'date_insert',
    orderDir: 'DESC',
  );
    if (!mounted) return;

    final already = sec.questions
        .where((q) => q.existingId != null)
        .map((q) => q.existingId!)
        .toSet();

    final selected = <int>{...already};
    final picked = await showDialog<List<int>>(
      context: context,
      useRootNavigator: true,
      builder: (_) => StatefulBuilder(
        builder: (_, setSt) => AlertDialog(
          title: Text('Preguntas para “${sec.name}”'),
          content: SizedBox(
            width: 540, height: 440,
            child: ListView.builder(
              itemCount: list.length,
              itemBuilder: (_, i) {
                final it = list[i]; 
                final int id = (it['id'] as num).toInt();
                final String name = (it['name'] ?? '').toString();
                final on = selected.contains(id);
                return CheckboxListTile(
                  value: on,
                  onChanged: (v) => setSt(() {
                    v == true ? selected.add(id) : selected.remove(id);
                  }),
                  title: Text(name),
                  subtitle: Text('ID: $id'),
                  controlAffinity: ListTileControlAffinity.leading,
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context, rootNavigator: true).pop(null),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context, rootNavigator: true).pop(selected.toList()),
              child: const Text('Añadir'),
            ),
          ],
        ),
      ),
    );

    if (picked == null) return;

    setState(() {
      final byId = <int, _StageQuestion>{
        for (final q in sec.questions.where((q) => q.existingId != null)) q.existingId!: q
      };
      for (final id in picked) {
        if (!byId.containsKey(id)) {
          final found = list.firstWhere((m) => (m['id'] as num).toInt() == id);
          final name = (found['name'] ?? '').toString();
          sec.questions.add(_StageQuestion.existing(existingId: id, existingName: name));
        }
      }
      sec.questions.removeWhere((q) => q.existingId != null && !picked.contains(q.existingId));
    });
  }

  void _moveQuestion(_StageSection sec, int idx, int dir) {
    final newIdx = idx + dir;
    if (newIdx < 0 || newIdx >= sec.questions.length) return;
setState(() {
  final q = sec.questions.removeAt(idx);
  sec.questions.insert(newIdx, q);
});

  }

  void _removeQuestion(_StageSection sec, int idx) {
setState(() {
  sec.questions.removeAt(idx);
});

  }


  Future<void> _loadQuestionResponsesIfNeeded(_StageQuestion q) async {
    if (q.existingId == null) return;
    if (q.loadedResponses.isNotEmpty && (q.listId == null || q.listItems.isNotEmpty)) {
      return;
    }

    try {
      final ext = await _repo.getQuestionExtended(q.existingId!);

      final List resps = (ext['responses'] is List) ? ext['responses'] as List : const [];
      final mapped = resps.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
      setState(() => q.setLoadedResponses(mapped));

      int? listId;
      final questionList = ext['questionList'];
      if (questionList is Map) {
        listId = (questionList['id'] as num?)?.toInt();
      } else if (questionList != null) {
        listId = int.tryParse(questionList.toString());
      }

      if (listId != null) {
        final List rawItems = (ext['items'] is List) ? ext['items'] as List : const [];
        final built = <_ListItem>[];
        for (final it in rawItems) {
          if (it is! Map) continue;
          final id = (it['id'] as num?)?.toInt();
          final name = (it['name'] ?? '').toString();
          if (id == null) continue;
          built.add(_ListItem(id: id, name: name, responses: const []));
        }

        setState(() {
          q.listId = listId;
          q.listItems
            ..clear()
            ..addAll(built);
        });
      }
    } catch (_) {
    }
  }

  Future<_PickMode?> _askPickMode() async {
    bool asTable = false;
    bool fillable = false;
    return showDialog<_PickMode>(
      context: context,
      useRootNavigator: true,
      builder: (_) => StatefulBuilder(
        builder: (_, setSt) => AlertDialog(
          title: const Text('Qué quieres cargar'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                value: asTable,
                onChanged: (v) => setSt(() => asTable = v),
                title: const Text('Tabla (lista de ítems)'),
                contentPadding: EdgeInsets.zero,
              ),
              if (!asTable)
                SwitchListTile(
                  value: fillable,
                  onChanged: (v) => setSt(() => fillable = v),
                  title: const Text('Rellenable por el paciente'),
                  contentPadding: EdgeInsets.zero,
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context, rootNavigator: true).pop(null),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context, rootNavigator: true).pop(_PickMode(asTable: asTable, fillable: fillable)),
              child: const Text('Continuar'),
            ),
          ],
        ),
      ),
    );
  }

Future<void> _pickResponsesForQuestion(_StageQuestion q) async {
  final all = await _repo.searchResponses(
    limit: 1000,
    orderBy: 'name',
    orderDir: 'ASC',
  );
  if (!mounted) return;

  final nameById = <int, String>{
    for (final m in all)
      (m['id'] as num).toInt(): (m['name'] ?? '').toString(),
  };

  final selected = <int>{...q.selectedResponseIds};
  final searchCtrl = TextEditingController();
  List<Map<String, dynamic>> filtered = all;

  List<Map<String, dynamic>> applyFilter(String txt) {
    final s = txt.trim().toLowerCase();
    if (s.isEmpty) return all;
    return all.where((m) {
      final name = (m['name'] ?? '').toString().toLowerCase();
      return name.contains(s);
    }).map((m) => Map<String, dynamic>.from(m)).toList();
  }

  final picked = await showDialog<List<int>>(
    context: context,
    useRootNavigator: true,
    builder: (_) => StatefulBuilder(
      builder: (_, setSt) => AlertDialog(
        title: const Text('Selecciona respuestas'),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: searchCtrl,
                decoration: const InputDecoration(
                  labelText: 'Buscar por nombre',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setSt(() => filtered = applyFilter(v)),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 420,
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final it = filtered[i];
                    final int id = (it['id'] as num).toInt();
                    final String name = (it['name'] ?? '').toString();
                    final on = selected.contains(id);

                    return CheckboxListTile(
                      value: on,
                      onChanged: (v) => setSt(() {
                        v == true ? selected.add(id) : selected.remove(id);
                      }),
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(name), 
                      subtitle: null,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(null),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(selected.toList()),
            child: const Text('Añadir'),
          ),
        ],
      ),
    ),
  );

  if (picked == null) return;

  setState(() {
    q.selectedResponseIds
      ..clear()
      ..addAll(picked);

    q.selectedResponseNames
      ..clear()
      ..addEntries(picked.map(
        (id) => MapEntry(id, nameById[id] ?? 'Respuesta #$id'),
      ));
  });
}



  Future<void> _createResponseForQuestion(_StageQuestion q) async {
final plan = await showDialog<_ResponsePlan>(
  context: context,
  useRootNavigator: true,
  builder: (_) => const _ResponseWizardDialog(),
);
if (plan == null) return;

setState(() {
  switch (plan.kind) {
    case _ResponsePlanKind.choiceFillable:
      q.newResponses.add(
        _StageResponseNew(
          name: plan.choiceFillable!.name,
          type: plan.choiceFillable!.type,   
          min: plan.choiceFillable!.min?.toString(),
          max: plan.choiceFillable!.max?.toString(),
          unity: plan.choiceFillable!.unity,
        ),
      );
      break;

    case _ResponsePlanKind.choiceFixed:
      for (final opt in plan.choiceFixed!.options) {
        if (opt.trim().isEmpty) continue;
        q.newResponses.add(
          _StageResponseNew(
            name: opt.trim(),
            type: 0, 
          ),
        );
      }
      break;
  }
});

  }

  Future<int> _resolveNewSectionId({
  required int surveyId,
  required int order,
  required String name,
}) async {
  final tree = await _repo.getTree(surveyId);

  final byOrder = tree.sections.where((e) => e.order == order).toList();
  if (byOrder.isNotEmpty) return byOrder.first.id;

  final target = name.trim().toLowerCase();
  final byName = tree.sections
      .where((e) => e.name.trim().toLowerCase() == target)
      .toList();
  if (byName.isNotEmpty) return byName.last.id;

  throw Exception('No pude resolver el ID de la sección (order=$order, name="$name")');
}


Future<int> _fallbackCreateQuestionAndResolveId({
  required int sectionId,
  required String name,
}) async {
  final before = await _repo.tryGetSectionQuestions(sectionId);
  final beforeIds = before
      .map((m) => (m['id'] as num?)?.toInt())
      .whereType<int>()
      .toSet();

  await _repo.createQuestion(sectionId: sectionId, name: name);

  const delays = [0, 150, 300, 600, 1200, 2000, 3200, 5200];
  for (final ms in delays) {
    if (ms > 0) await Future.delayed(Duration(milliseconds: ms));
    final after = await _repo.tryGetSectionQuestions(sectionId);
    final added = after.where((m) {
      final id = (m['id'] as num?)?.toInt();
      return id != null && !beforeIds.contains(id);
    }).toList();

    if (added.isNotEmpty) {
      final target = name.trim().toLowerCase();
      final sameName = added.where((m) {
        final n = (m['name'] ?? '').toString().trim().toLowerCase();
        return n == target;
      }).toList();
      final chosen = sameName.isNotEmpty ? sameName.last : added.last;
      return (chosen['id'] as num).toInt();
    }
  }

  throw Exception(
    'No pude localizar la pregunta recién creada (sectionId=$sectionId, name="$name").',
  );
}

Future<int> _createSectionReturnId({
  required int surveyId,
  required String name,
  required int order,
}) async {
  try {
    final id = await _repo.createSectionReturnId(
      surveyId: surveyId,
      name: name,
      targetOrder: order,
    );
    return id;
  } catch (_) {
    await _repo.createSection(
      surveyId: surveyId,
      name: name,
      targetOrder: order,
    );
    final tree = await _repo.getTree(surveyId);
    final byOrder = tree.sections.where((e) => e.order == order).toList();
    if (byOrder.isNotEmpty) return byOrder.first.id;
    final byName = tree.sections.where((e) => e.name == name).toList();
    if (byName.isNotEmpty) return byName.last.id;
    throw Exception('No pude resolver el ID de la sección (order=$order, name=$name)');
  }
}

Future<int> _createQuestionReturnId({
  required int sectionId,
  required String name,
}) async {
  try {
    final id = await _repo.createQuestionReturnId(
      sectionId: sectionId,
      name: name,
    );
    return id;
  } catch (_) {
    return _fallbackCreateQuestionAndResolveId(sectionId: sectionId, name: name);
  }
}


Future<void> _safeAttachQuestions({
  required int sectionId,
  required List<int> questionIds,
  required int insertAfterOrder,
  int chunkSize = 12,  
}) async {
  for (int i = 0; i < questionIds.length; i += chunkSize) {
    final chunk = questionIds.sublist(
      i,
      (i + chunkSize > questionIds.length) ? questionIds.length : i + chunkSize,
    );

    const delays = [0, 200, 400, 800, 1500, 2500];
    bool ok = false;

    for (var t = 0; t < delays.length; t++) {
      if (delays[t] > 0) {
        await Future.delayed(Duration(milliseconds: delays[t]));
      }
      try {
        await _repo.attachQuestions(
          sectionId: sectionId,
          questionIds: chunk,
          insertAfterOrder: insertAfterOrder,
        );
        ok = true;
        break;
      } catch (e) {
        final msg = '$e';
        final isLockTimeout = msg.contains('ER_LOCK_WAIT_TIMEOUT') ||
                              msg.contains('Lock wait timeout');
        if (!isLockTimeout || t == delays.length - 1) rethrow;
        debugPrint('[RETRY] attachQuestions por lock timeout (intento ${t + 1}) '
                   'sec=$sectionId, chunk(${chunk.length})');
      }
    }

    if (!ok) {
      throw Exception('No se pudo adjuntar preguntas (sec=$sectionId) tras reintentos.');
    }
  }
}




Future<void> _createAll() async {
  if (!_canStageActions || _creating) return;

  setState(() => _creating = true);

  Future<int> _createQuestionAndResolveIdLocal({
    required int sectionId,
    required String name,
  }) async {
    try {
      final id = await _repo.createQuestionReturnId(sectionId: sectionId, name: name);
      if (id > 0) return id;
    } catch (_) {}

    final before = await _repo.tryGetSectionQuestions(sectionId);
    final beforeIds = before.map((m) => (m['id'] as num?)?.toInt()).whereType<int>().toSet();

    try {
      await _repo.createQuestion(sectionId: sectionId, name: name);
    } catch (_) {}

    const delays = [0, 250, 500, 900, 1500, 2200, 3500, 5000];
    for (final ms in delays) {
      if (ms > 0) await Future.delayed(Duration(milliseconds: ms));
      final after = await _repo.tryGetSectionQuestions(sectionId);
      final added = after.where((m) {
        final id = (m['id'] as num?)?.toInt();
        return id != null && !beforeIds.contains(id);
      }).toList();

      if (added.isNotEmpty) {
        final target = name.trim().toLowerCase();
        final sameName = added.where((m) {
          final n = (m['name'] ?? '').toString().trim().toLowerCase();
          return n == target;
        }).toList();
        final chosen = sameName.isNotEmpty ? sameName.last : added.last;
        return (chosen['id'] as num).toInt();
      }
    }

    throw Exception('No pude localizar la pregunta recién creada (sectionId=$sectionId, name="$name").');
  }

  try {
    final me = await AuthRepository().me();
    final idCoordinator = me.userId;

    final newId = await _repo.createSurvey(
      name: _nameCtrl.text.trim(),
      type: _type == SurveyTypeUi.history ? 0 : 1,
      idCoordinator: idCoordinator,
    );
    debugPrint('[CREATE] Survey creada -> id=$newId');

    var runningOrder = 1;
    for (final s in _sections) {
      int sectionRealId;

      final userDefineQuestions = s.questions.isNotEmpty;

      if (s.existingSectionId != null && !userDefineQuestions) {
        await _repo.attachSections(
          surveyId: newId,
          sectionIds: [s.existingSectionId!],
          insertAfterOrder: runningOrder - 1,
        );
        sectionRealId = s.existingSectionId!;
      } else {
        final sectionName = s.name.trim().isEmpty ? 'Sección' : s.name.trim();
        sectionRealId = await _repo.createSectionReturnId(
          surveyId: newId,
          name: sectionName,
          targetOrder: runningOrder,
        );
      }
      debugPrint('[CREATE] -> sectionRealId=$sectionRealId');

      final itemQuestionIds = <int>{
        for (final q in s.questions.where((q) => q.kind == _QuestionUiKind.table))
          ...q.listItems.map((it) => it.id).where((id) => id > 0),
      };

      final List<int> existingToAttach = [];
      final Map<int, Set<int>> responsesForExisting = {};

      for (final q in s.questions) {
        if (q.existingId != null) {
          final qid = q.existingId!;
          if (itemQuestionIds.contains(qid)) continue;

          existingToAttach.add(qid);

          if (q.selectedResponseIds.isNotEmpty) {
            responsesForExisting[qid] = {...q.selectedResponseIds};
          }
          continue;
        }

        final newName = (q.newName?.trim().isNotEmpty ?? false) ? q.newName!.trim() : 'Pregunta';
        int questionId;
        try {
          questionId = await _repo.createQuestionReturnId(
            sectionId: sectionRealId,
            name: newName,
          );
        } catch (_) {
          questionId = await _createQuestionAndResolveIdLocal(sectionId: sectionRealId, name: newName);
        }

        if (q.selectedResponseIds.isNotEmpty) {
          await _repo.attachResponses(
            questionId: questionId,
            responseIds: q.selectedResponseIds.toList(),
            insertAfterOrder: null,
          );
        }
        for (final r in q.newResponses) {
          await _repo.createResponseAndAttach(
            questionId: questionId,
            name: r.name,
            type: r.type,
            unity: r.unity,
            min: r.min,
            max: r.max,
            insertAfterOrder: null,
          );
        }

        if (q.kind == _QuestionUiKind.table && q.listItems.isNotEmpty) {
          final listname = (q.tableTitle ?? '').trim().isEmpty ? null : q.tableTitle!.trim();

          final listId = await _repo.createQuestionListSafe(
            questionId: questionId,
            listname: listname,
          );
          debugPrint('[CREATE] list for q=$questionId -> listId=$listId');

          final materialized = <_ListItem>[];
          for (final it in q.listItems) {
            if (it.id > 0) {
              materialized.add(it);
              continue;
            }
            final newItemQId = await _repo.createQuestionReturnId(
              sectionId: sectionRealId,
              name: it.name,
            );
            materialized.add(_ListItem(id: newItemQId, name: it.name, responses: const []));
          }

          final existingItems = await _repo.getListQuestions(listId);
          final existingIds = existingItems
              .map((m) => (m['id'] as num?)?.toInt())
              .whereType<int>()
              .toSet();

          var order = existingItems.length + 1;
          for (final it in materialized) {
            if (existingIds.contains(it.id)) {
              debugPrint('[CREATE] skip existing item qItem=${it.id} in list=$listId');
              continue;
            }
            final isMaterialized = q.listItems.any((li) => li.id <= 0 && li.name == it.name);
            if (isMaterialized) {
              await _repo.addQuestionToList(
                listId: listId,
                dtoQuestionId: it.id,
                order: order++,
                forceDetach: true,
              );
            } else {
              await _repo.addQuestionToListSafe(
                listId: listId,
                dtoQuestionId: it.id,
                order: order++,
              );
            }
            debugPrint('[CREATE] addQuestionToList list=$listId qItem=${it.id}');
          }
        }
      } 

      if (existingToAttach.isNotEmpty) {
        final current = await _repo.tryGetSectionQuestions(sectionRealId);
        final currentIds = current
            .map((m) => (m['id'] as num?)?.toInt())
            .whereType<int>()
            .toSet();

        final missing = existingToAttach
            .where((id) => !currentIds.contains(id))
            .toSet()
            .toList();

        if (missing.isNotEmpty) {
          await _safeAttachQuestions(
            sectionId: sectionRealId,
            questionIds: missing,          
            insertAfterOrder: 999999,      
          );
        }

        for (final qid in responsesForExisting.keys) {
          final respIds = responsesForExisting[qid]!.toList();
          if (respIds.isEmpty) continue;
          await _repo.attachResponses(
            questionId: qid,
            responseIds: respIds,
            insertAfterOrder: null,
          );
        }
      }

      runningOrder++;
    }

    debugPrint('[CREATE] finalizeSurvey id=$newId');
    await _repo.finalizeSurvey(newId);

    setState(() {
      _createdSurveyId = newId;
      _futTree = _repo.getTree(newId);
      _srcSurveyId = null;
      _srcSurveyName = null;
      _sections.clear();
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Formulario creado (#$newId)')),
    );
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('No se pudo crear el formulario: $e')),
    );
  } finally {
    if (mounted) setState(() => _creating = false);
  }
}



Future<void> _loadSourceSurveyIntoStaging(int sourceId, String sourceName) async {
  final tree = await _repo.getTree(sourceId);

  final staged = <_StageSection>[];
  for (final sec in tree.sections) {
    final ss = _StageSection.existing(
      existingSectionId: sec.id,
      name: sec.name,
    );

    staged.add(ss);
  }

  setState(() {
    _srcSurveyId = sourceId;       
    _srcSurveyName = sourceName;   
    _sections
      ..clear()
      ..addAll(staged);      
  });
}





@override
Widget build(BuildContext context) {
  final t = Theme.of(context).textTheme;

  final bool isCreated = _createdSurveyId != null;
  final bool canStageNow = _canStageActions && !isCreated; 

  return Scaffold(
    appBar: AppBar(title: const Text('Crear formulario')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              elevation: 1.5,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Datos básicos', style: t.titleMedium),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12, runSpacing: 12,
                      children: [
                        SizedBox(
                          width: 420,
                          child: TextField(
                            controller: _nameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Nombre del formulario',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => setState((){}),
                          ),
                        ),
                        SizedBox(
                          width: 260,
                          child: DropdownButtonFormField<SurveyTypeUi>(
                            value: _type,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Tipo',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: SurveyTypeUi.history,
                                child: Text('Historia clínica'),
                              ),
                              DropdownMenuItem(
                                value: SurveyTypeUi.revision,
                                child: Text('Revisión'),
                              ),
                            ],
                            onChanged: (v) => setState(() => _type = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Wrap(
                      spacing: 12, runSpacing: 8,
                      children: [
                        if (!isCreated) ...[
                          OutlinedButton.icon(
                            onPressed: canStageNow ? _pickAndStageSourceSurvey : null,
                            icon: const Icon(Icons.copy_all_outlined),
                            label: const Text('Cargar formulario'),
                          ),
                          OutlinedButton.icon(
                            onPressed: canStageNow ? _pickAndAttachSections : null,
                            icon: const Icon(Icons.playlist_add_outlined),
                            label: const Text('Cargar secciones'),
                          ),
                          OutlinedButton.icon(
                            onPressed: canStageNow ? _stageCreateSection : null,
                            icon: const Icon(Icons.add_box_outlined),
                            label: const Text('Crear sección'),
                          ),
                          FilledButton.icon(
                            onPressed: (canStageNow && !_creating) ? _createAll : null,
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('Crear formulario'),
                          ),
                          if (_sections.isNotEmpty || _srcSurveyId != null)
                            TextButton.icon(
                              onPressed: _clearAllStaging,
                              icon: const Icon(Icons.delete_sweep),
                              label: const Text('Quitar formulario'),
                            ),
                        ] else ...[
                          FilledButton.icon(
                            onPressed: () async {
                              await _refreshTree();
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Vista actualizada')),
                              );
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Actualizar vista'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () {
                              _clearAllStaging(); 
                            },
                            icon: const Icon(Icons.add_circle_outline),
                            label: const Text('Crear otro formulario'),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            if (canStageNow)
              Card(
                elevation: 1.5,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Secciones (staging)', style: t.titleMedium),
                      const SizedBox(height: 8),
                      if (_sections.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Text('— Aún no has añadido secciones —'),
                        )
                      else
                        Column(
                          children: [
                            for (int i = 0; i < _sections.length; i++)
                              _SectionTile(
                                index: i,
                                sec: _sections[i],
                                onMove: _moveSection,
                                onRemove: _removeSection,
                                onLoadQuestions: _stageLoadQuestions,
                                onCreateQuestion: _stageCreateQuestion,
                                onMoveQuestion: _moveQuestion,
                                onRemoveQuestion: _removeQuestion,
                                onPickResponses: _pickResponsesForQuestion,
                                onCreateResponse: _createResponseForQuestion,
                                onEnsureResponsesLoaded: _loadQuestionResponsesIfNeeded,
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 12),

            if (isCreated)
              FutureBuilder<List<_RenderedSection>>(
                future: (_futTree == null)
                    ? _loadCreatedSurveyPreview(_createdSurveyId!)
                    : _loadCreatedSurveyPreview(_createdSurveyId!),
                builder: (_, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  if (snap.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Error cargando vista: ${snap.error}'),
                    );
                  }
                  final sections = snap.data ?? const <_RenderedSection>[];

                  return Card(
                    elevation: 1.5,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            child: Text(
                              'Formulario creado: ${_nameCtrl.text.trim()} (#${_createdSurveyId})',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              'Vista de solo lectura.',
                              style: TextStyle(fontStyle: FontStyle.italic),
                            ),
                          ),
                          const SizedBox(height: 8),

                          for (final s in sections) ...[
                            ListTile(
                              leading: CircleAvatar(child: Text('${s.order}')),
                              title: Text(s.name),
                              subtitle: Text('${s.questions.length} preguntas'),
                            ),

                            if (s.questions.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(left: 52, bottom: 8, right: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    for (final q in s.questions) ...[
                                      Padding(
                                        padding: const EdgeInsets.only(top: 6, bottom: 2),
                                        child: Text('• ${q.order}. ${q.name}'),
                                      ),
                                      if (q.items.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(left: 14, bottom: 6, top: 2),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('Ítems:', style: TextStyle(fontStyle: FontStyle.italic)),
                                              const SizedBox(height: 4),
                                              for (final it in q.items)
                                                Padding(
                                                  padding: const EdgeInsets.only(left: 10, bottom: 2),
                                                  child: Text('· ${it.name}'),
                                                ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ],
                                ),
                              ),
                          ],
                        ],
                      ),
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

  Future<String?> _askText({required String title, required String label}) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      useRootNavigator: true,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(controller: ctrl, decoration: InputDecoration(labelText: label)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(null),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(ctrl.text),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }


Future<_LoadRespMode?> _askLoadMode() async {
  return showDialog<_LoadRespMode>(
    context: context,
    useRootNavigator: true,
    builder: (_) => SimpleDialog(
      title: const Text('¿Qué quieres cargar?'),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(_LoadRespMode.choiceFixed),
          child: const Text('Elección · No rellenable (type=0)'),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(_LoadRespMode.choiceFillable),
          child: const Text('Elección · Rellenable con unidad (type=1)'),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(_LoadRespMode.choiceRange),
          child: const Text('Elección · Rellenable sin unidad (rango, type=2)'),
        ),
        const Divider(),
        SimpleDialogOption(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(_LoadRespMode.table),
          child: const Text('Tabla (listas)'),
        ),
      ],
    ),
  );
}

Future<int?> _pickListIdByName() async {
  try {
    final lists = await _repo.searchLists(limit: 200, orderBy: 'name', orderDir: 'ASC');
    if (!mounted) return null;

    return showDialog<int>(
      context: context,
      useRootNavigator: true,
      builder: (_) => SimpleDialog(
        title: const Text('Selecciona una lista'),
        children: [
          if (lists.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No hay listas disponibles'),
            )
          else
            ...lists.map((m) {
              final id = (m['id'] as num?)?.toInt();
              final name = (m['name'] ?? '').toString();
              return SimpleDialogOption(
                onPressed: () => Navigator.of(context, rootNavigator: true).pop(id),
                child: Text(name.isEmpty ? 'Lista #$id' : '$name  (#$id)'),
              );
            }),
        ],
      ),
    );
  } catch (e) {
    if (!mounted) return null;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('No se pudieron cargar las listas: $e')),
    );
    return null;
  }
}

Future<List<int>?> _pickItemsFromList(int listId) async {
  try {
    final items = await _repo.getListQuestions(listId);
    if (!mounted) return null;

    final picked = <int>{};
    return showDialog<List<int>>(
      context: context,
      useRootNavigator: true,
      builder: (_) => StatefulBuilder(
        builder: (_, setSt) => AlertDialog(
          title: const Text('Selecciona items de la lista'),
          content: SizedBox(
            width: 540, height: 440,
            child: items.isEmpty
                ? const Center(child: Text('Esta lista no tiene items'))
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final it = items[i];
                      final id = (it['id'] as num?)?.toInt();
                      final name = (it['name'] ?? '').toString();
                      final on = id != null && picked.contains(id);
                      return CheckboxListTile(
                        value: on,
                        onChanged: (v) => setSt(() {
                          if (id == null) return;
                          v == true ? picked.add(id) : picked.remove(id);
                        }),
                        title: Text(name.isEmpty ? 'Item #$id' : name),
                        subtitle: Text('ID: ${id ?? '-'}'),
                        controlAffinity: ListTileControlAffinity.leading,
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context, rootNavigator: true).pop(null),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context, rootNavigator: true).pop(picked.toList()),
              child: const Text('Añadir'),
            ),
          ],
        ),
      ),
    );
  } catch (e) {
    if (!mounted) return null;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('No se pudieron cargar los items: $e')),
    );
    return null;
  }
}



}


class _SectionTile extends StatefulWidget {
  final int index;
  final _StageSection sec;
  final void Function(int idx, int dir) onMove;
  final void Function(int idx) onRemove;

  final Future<void> Function(_StageSection sec) onLoadQuestions;
  final Future<void> Function(_StageSection sec) onCreateQuestion;
  final void Function(_StageSection sec, int idx, int dir) onMoveQuestion;
  final void Function(_StageSection sec, int idx) onRemoveQuestion;

  final Future<void> Function(_StageQuestion q) onPickResponses;
  final Future<void> Function(_StageQuestion q) onCreateResponse;
  final Future<void> Function(_StageQuestion q) onEnsureResponsesLoaded;

  const _SectionTile({
    super.key,
    required this.index,
    required this.sec,
    required this.onMove,
    required this.onRemove,
    required this.onLoadQuestions,
    required this.onCreateQuestion,
    required this.onMoveQuestion,
    required this.onRemoveQuestion,
    required this.onPickResponses,
    required this.onCreateResponse,
    required this.onEnsureResponsesLoaded,
  });

  @override
  State<_SectionTile> createState() => _SectionTileState();
}

class _SectionTileState extends State<_SectionTile> {
  bool _autoTried = false; 
  bool _loadingAuto = false;

  Future<void> _autoLoadIfPossible(BuildContext context) async {
    if (_autoTried) return;
    _autoTried = true;

    if (widget.sec.existingSectionId == null) return;
    if (widget.sec.questions.isNotEmpty) return;

    setState(() => _loadingAuto = true);

    final repo = SurveysRepository(); 
    final list = await repo.tryGetSectionQuestions(widget.sec.existingSectionId!);
    if (!mounted) return;

    if (list.isNotEmpty) {
      setState(() {
        for (final m in list) {
          final id = (m['id'] as num?)?.toInt();
          final name = (m['name'] ?? '').toString();
          if (id != null) {
            widget.sec.questions.add(
              _StageQuestion.existing(existingId: id, existingName: name),
            );
          }
        }
      });
    }

    setState(() => _loadingAuto = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final index = widget.index;
    final sec = widget.sec;

    final subtitle = sec.existingSectionId != null
        ? (sec.questions.isNotEmpty
            ? 'Sección existente #${sec.existingSectionId} — ${sec.questions.length} preguntas'
            : _loadingAuto
                ? 'Cargando preguntas...'
                : 'Sección existente #${sec.existingSectionId} — pulsa “Cargar preguntas” si no aparecen automáticamente')
        : (sec.questions.isNotEmpty
            ? 'Sección nueva — ${sec.questions.length} preguntas'
            : 'Sección nueva — aún sin preguntas');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 8),
          title: Text('${index + 1}. ${sec.name}', style: t.titleMedium),
          subtitle: Text(subtitle),
          trailing: Wrap(
            spacing: 4,
            children: [
              IconButton(
                tooltip: 'Subir sección',
                onPressed: index > 0 ? () => widget.onMove(index, -1) : null,
                icon: const Icon(Icons.arrow_upward),
              ),
              IconButton(
                tooltip: 'Bajar sección',
                onPressed: () => widget.onMove(index, 1),
                icon: const Icon(Icons.arrow_downward),
              ),
              IconButton(
                tooltip: 'Quitar sección',
                onPressed: () => widget.onRemove(index),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          onExpansionChanged: (open) {
            if (open) _autoLoadIfPossible(context);
          },
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => widget.onLoadQuestions(sec),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Cargar preguntas'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => widget.onCreateQuestion(sec),
                    icon: const Icon(Icons.add),
                    label: const Text('Crear pregunta'),
                  ),
                ],
              ),
            ),
            if (sec.questions.isEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _loadingAuto
                        ? 'Cargando preguntas...'
                        : '— Esta sección no tiene preguntas en staging —',
                  ),
                ),
              )
            else
              Column(
                children: [
                  for (int i = 0; i < sec.questions.length; i++)
                    _QuestionTile(
                      index: i,
                      question: sec.questions[i],
                      onMove: (idx, dir) => widget.onMoveQuestion(sec, idx, dir),
                      onRemove: (idx) => widget.onRemoveQuestion(sec, idx),
                      onPickResponses: widget.onPickResponses,
                      onCreateResponse: widget.onCreateResponse,
                      onEnsureResponsesLoaded: widget.onEnsureResponsesLoaded,
                    ),
                ],
              ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

class _QuestionTile extends StatefulWidget {
  final int index;
  final _StageQuestion question;
  final void Function(int idx, int dir) onMove;
  final void Function(int idx) onRemove;

  final Future<void> Function(_StageQuestion q) onPickResponses;
  final Future<void> Function(_StageQuestion q) onCreateResponse;
  final Future<void> Function(_StageQuestion q) onEnsureResponsesLoaded;

  const _QuestionTile({
    super.key,
    required this.index,
    required this.question,
    required this.onMove,
    required this.onRemove,
    required this.onPickResponses,
    required this.onCreateResponse,
    required this.onEnsureResponsesLoaded,
  });

  @override
  State<_QuestionTile> createState() => _QuestionTileState();
}

class _QuestionTileState extends State<_QuestionTile> {
  bool _expanded = false;
  bool _loading = false;

  Future<void> _ensureLoaded() async {
    if (!_expanded) return;
    if (widget.question.existingId == null) return;
    if (widget.question.loadedResponses.isNotEmpty) return;

    setState(() => _loading = true);
    await widget.onEnsureResponsesLoaded(widget.question);
    if (mounted) setState(() => _loading = false);
  }

  Future<String?> _askText({required String title, required String label}) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      useRootNavigator: true,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(controller: ctrl, decoration: InputDecoration(labelText: label)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(null),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(ctrl.text),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    final i = widget.index;

    final trailing = Wrap(
      spacing: 4,
      children: [
        IconButton(
          tooltip: 'Subir',
          onPressed: i > 0 ? () => widget.onMove(i, -1) : null,
          icon: const Icon(Icons.arrow_upward),
        ),
        IconButton(
          tooltip: 'Bajar',
          onPressed: () => widget.onMove(i, 1),
          icon: const Icon(Icons.arrow_downward),
        ),
        IconButton(
          tooltip: 'Quitar',
          onPressed: () => widget.onRemove(i),
          icon: const Icon(Icons.close),
        ),
      ],
    );

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ExpansionTile(
        onExpansionChanged: (open) async {
          setState(() => _expanded = open);
          await _ensureLoaded();
        },
        tilePadding: const EdgeInsets.symmetric(horizontal: 8),
        title: Text('${i + 1}. ${q.label}'),
        subtitle: q.existingId != null
            ? (_loading
                ? const Text('Cargando respuestas…')
                : Text('Pregunta #${q.existingId} · Respuestas: ${q.loadedResponses.length}'))
            : const Text('Pregunta nueva (sin respuestas aún)'),
        trailing: trailing,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 8, bottom: 4),
            child: Row(
              children: [
                const SizedBox(width: 8),
                const Text('Selecciona el tipo de pregunta:  '),
                Radio<_QuestionUiKind>(
                  value: _QuestionUiKind.choice,
                  groupValue: q.kind,
                  onChanged: (v) => setState(() => q.kind = v!),
                ),
                const Text('Elección'),
                const SizedBox(width: 16),
                Radio<_QuestionUiKind>(
                  value: _QuestionUiKind.table,
                  groupValue: q.kind,
                  onChanged: (v) => setState(() => q.kind = v!),
                ),
                const Text('Tabla'),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => widget.onPickResponses(q),
                  icon: const Icon(Icons.playlist_add),
                  label: const Text('Cargar respuestas'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => widget.onCreateResponse(q),
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Crear respuesta'),
                ),
              ],
            ),
          ),

          if (_loading)
            const Padding(
              padding: EdgeInsets.only(left: 16, bottom: 6),
              child: Align(alignment: Alignment.centerLeft, child: Text('Cargando respuestas…')),
            )
          else
            _ResponsesReadonlyList(responses: q.loadedResponses),

if (q.selectedResponseIds.isNotEmpty || q.newResponses.isNotEmpty)
  Padding(
    padding: const EdgeInsets.only(left: 16, right: 8, bottom: 10, top: 6),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('A añadir en la creación:', style: TextStyle(fontWeight: FontWeight.w600)),

                  if (q.selectedResponseIds.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    for (final id in q.selectedResponseIds)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(

                          children: [
                            Expanded(
                              child: Text(
                                q.selectedResponseNames[id] ?? 'Respuesta #$id',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Quitar',
                              icon: const Icon(Icons.close),
                              onPressed: () => setState(() {
                                q.selectedResponseIds.remove(id);
                                q.selectedResponseNames.remove(id);
                              }),
                            ),
                          ],
                        ),
                      ),
                  ],

                  if (q.newResponses.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    for (int idx = 0; idx < q.newResponses.length; idx++)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                q.newResponses[idx].name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Quitar',
                              icon: const Icon(Icons.close),
                              onPressed: () => setState(() {
                                q.newResponses.removeAt(idx);
                              }),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),


          if (q.kind == _QuestionUiKind.table) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
              child: Row(
                children: [
                  Text('Ítems de la tabla', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final repo = SurveysRepository();

                      final all = await repo.searchQuestionsAll(
                        pageSize: 200,
                        orderBy: 'date_insert',
                        orderDir: 'DESC',
                      );
                      if (!mounted) return;

                      final already = widget.question.listItems
                          .where((e) => e.id > 0)
                          .map((e) => e.id)
                          .toSet();

                      final picked = await showDialog<Set<int>>(
                        context: context,
                        useRootNavigator: true,
                        builder: (_) {
                          final selected = <int>{...already};
                          return StatefulBuilder(
                            builder: (ctx, setSt) => AlertDialog(
                              title: const Text('Selecciona ítems (preguntas)'),
                              content: SizedBox(
                                width: 560,
                                height: 420,
                                child: ListView.builder(
                                  itemCount: all.length,
                                  itemBuilder: (_, idx) {
                                    final m = all[idx];
                                    final id = (m['id'] as num).toInt();
                                    final name = (m['name'] ?? '').toString();
                                    final on = selected.contains(id);
                                    return CheckboxListTile(
                                      value: on,
                                      onChanged: (v) => setSt(() {
                                        v == true ? selected.add(id) : selected.remove(id);
                                      }),
                                      title: Text(name),
                                      subtitle: Text('ID: $id'),
                                      controlAffinity: ListTileControlAffinity.leading,
                                    );
                                  },
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(null),
                                  child: const Text('Cancelar'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(selected),
                                  child: const Text('Añadir'),
                                ),
                              ],
                            ),
                          );
                        },
                      );

                      if (picked == null) return;


                      setState(() {
                        final q = widget.question;

                        final createdLocal = q.listItems.where((e) => e.id <= 0).toList();

                        final existingById = {
                          for (final it in q.listItems.where((e) => e.id > 0)) it.id: it,
                        };

                        final List<_ListItem> merged = [];

                        for (final id in picked) {
                          final found = existingById[id];
                          if (found != null) {
                            merged.add(found);
                          }
                        }

                        final pickedOnlyNew = picked.where((id) => !existingById.containsKey(id)).toSet();
                        if (pickedOnlyNew.isNotEmpty) {
                          final byId = {
                            for (final m in all) (m['id'] as num).toInt(): m,
                          };
                          for (final id in pickedOnlyNew) {
                            final m = byId[id];
                            if (m == null) continue;
                            merged.add(
                              _ListItem(
                                id: id,
                                name: (m['name'] ?? '').toString(),
                                responses: const [],
                              ),
                            );
                          }
                        }

                        merged.addAll(createdLocal);

                        final seen = <int>{};
                        final deduped = <_ListItem>[];
                        for (final it in merged) {
                          if (!seen.contains(it.id)) {
                            deduped.add(it);
                            seen.add(it.id);
                          }
                        }

                        q.listItems
                          ..clear()
                          ..addAll(deduped);
                      });
                    },
                    icon: const Icon(Icons.playlist_add),
                    label: const Text('Cargar ítems'),
                  ),

                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final name = await _askText(
                        title: 'Crear ítem',
                        label: 'Nombre del ítem',
                      );
                      if (name == null || name.trim().isEmpty) return;
                      setState(() {
                        q.listItems.add(
                          _ListItem(
                            id: -DateTime.now().millisecondsSinceEpoch, 
                            name: name.trim(),
                            responses: const [],
                          ),
                        );
                      });
                    },
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Crear ítem'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Escribe el título de la tabla (ej.: Lista de enfermedades)',
                ),
                controller: TextEditingController(text: q.tableTitle)
                  ..selection = TextSelection.collapsed(offset: (q.tableTitle ?? '').length),
                onChanged: (v) => q.tableTitle = v,
              ),
            ),
            const SizedBox(height: 8),

            if (q.listItems.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 8, bottom: 10, top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final it in q.listItems)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Expanded(child: Text(it.name)),
                            IconButton(
                              tooltip: 'Quitar ítem',
                              icon: const Icon(Icons.close),
                              onPressed: () => setState(() => q.listItems.remove(it)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}



class _ResponsesReadonlyList extends StatelessWidget {
  final List<Map<String, dynamic>> responses;
  const _ResponsesReadonlyList({super.key, required this.responses});

  @override
  Widget build(BuildContext context) {
    if (responses.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(left: 16, bottom: 6),
        child: Align(alignment: Alignment.centerLeft, child: Text('— La pregunta no tiene respuestas activas —')),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 8, bottom: 10),
      child: Column(
        children: [
          for (final r in responses)
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.only(left: 0, right: 8),
              title: Text((r['name'] ?? 'Respuesta').toString()),
              subtitle: _subtitleFor(r),
            ),
        ],
      ),
    );
  }

  Widget? _subtitleFor(Map<String, dynamic> r) {
    final parts = <String>[];
    if (r['type'] != null) parts.add('tipo: ${r['type']}');
    if (r['min'] != null && r['min'].toString().isNotEmpty) parts.add('min: ${r['min']}');
    if (r['max'] != null && r['max'].toString().isNotEmpty) parts.add('max: ${r['max']}');
    if (r['unity'] != null && r['unity'].toString().isNotEmpty) parts.add('unidad: ${r['unity']}');
    if (parts.isEmpty) return null;
    return Text(parts.join(' · '));
  }
}


enum _ResponsePlanKind { choiceFillable, choiceFixed }

class _ResponsePlan {
  final _ResponsePlanKind kind;
  final _ChoiceFillableData? choiceFillable;
  final _ChoiceFixedData? choiceFixed;

  _ResponsePlan.choiceFillable(this.choiceFillable)
      : kind = _ResponsePlanKind.choiceFillable,
        choiceFixed = null;

  _ResponsePlan.choiceFixed(this.choiceFixed)
      : kind = _ResponsePlanKind.choiceFixed,
        choiceFillable = null;
}

class _ChoiceFillableData {
  final String name;
  final int? type;   
  final num? min;
  final num? max;
  final String? unity;
  _ChoiceFillableData({required this.name, this.type, this.min, this.max, this.unity});
}

class _ChoiceFixedData {
  final List<String> options; 
  _ChoiceFixedData({required this.options});
}


class _TableData {
  final List<_PickerItem> items; 
  _TableData({required this.items});
}

class _PickerItem {
  final int id;
  final String name;
  _PickerItem({required this.id, required this.name});
}

class _ResponseWizardDialog extends StatefulWidget {
  const _ResponseWizardDialog({super.key});
  @override
  State<_ResponseWizardDialog> createState() => _ResponseWizardDialogState();
}

class _ResponseWizardDialogState extends State<_ResponseWizardDialog> {
  bool _fillable = true;

  final _nameCtrl = TextEditingController();
  final _minCtrl = TextEditingController();
  final _maxCtrl = TextEditingController();
  final _unityCtrl = TextEditingController();

  final List<TextEditingController> _opts = [TextEditingController()];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _minCtrl.dispose();
    _maxCtrl.dispose();
    _unityCtrl.dispose();
    for (final c in _opts) c.dispose();
    super.dispose();
  }

  void _addOption() => setState(() => _opts.add(TextEditingController()));
  void _removeOption(int i) {
    if (_opts.length <= 1) return;
    final c = _opts.removeAt(i);
    c.dispose();
    setState(() {});
  }

  void _submit() {
    if (_fillable) {
      final name = _nameCtrl.text.trim();
      if (name.isEmpty) return;

      final unity = _unityCtrl.text.trim().isEmpty ? null : _unityCtrl.text.trim();
      final minTxt = _minCtrl.text.trim();
      final maxTxt = _maxCtrl.text.trim();

      num? min = minTxt.isEmpty ? null : num.tryParse(minTxt);
      num? max = maxTxt.isEmpty ? null : num.tryParse(maxTxt);

      int? type;
      if (unity != null && unity.isNotEmpty) {
        type = 1;
      } else if (min != null && max != null) {
        type = 2;
      }

      if (type == 2 && (min == null || max == null)) return;

      Navigator.of(context, rootNavigator: true).pop(
        _ResponsePlan.choiceFillable(
          _ChoiceFillableData(name: name, type: type, min: min, max: max, unity: unity),
        ),
      );
      return;
    }

    final opts = _opts.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();
    if (opts.isEmpty) return;
    Navigator.of(context, rootNavigator: true).pop(
      _ResponsePlan.choiceFixed(_ChoiceFixedData(options: opts)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Crear respuestas'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              value: _fillable,
              onChanged: (v) => setState(() => _fillable = v),
              title: const Text('Rellenable por el paciente'),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),
            if (_fillable)
              Column(
                children: [
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'Nombre de la respuesta'),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _unityCtrl,
                          decoration: const InputDecoration(labelText: 'Unidad'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _minCtrl,
                          decoration: const InputDecoration(labelText: 'Min'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _maxCtrl,
                          decoration: const InputDecoration(labelText: 'Max'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Opciones'),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _addOption,
                        icon: const Icon(Icons.add),
                        label: const Text('Añadir opción'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  for (int i = 0; i < _opts.length; i++)
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _opts[i],
                            decoration: InputDecoration(labelText: 'Opción #${i + 1}'),
                          ),
                        ),
                        IconButton(
                          onPressed: () => _removeOption(i),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                ],
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(null),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Aceptar'),
        ),
      ],
    );
  }
}


class _PickMode {
  final bool asTable;
  final bool fillable;
  _PickMode({required this.asTable, required this.fillable});
}
