import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_repository.dart';

const _roleLabel = <String, String>{
  'coordinator': 'Investigador',
  'revisor': 'Tutor',
  'patient': 'Paciente',
};

const _uiOrder = ['coordinator', 'revisor', 'patient'];

class RoleSelectPage extends StatefulWidget {
  const RoleSelectPage({super.key});
  @override
  State<RoleSelectPage> createState() => _RoleSelectPageState();
}

class _RoleSelectPageState extends State<RoleSelectPage> {
  final _repo = AuthRepository();
  Future<List<String>>? _rolesFut;
  bool _autoNavigating = true; 

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }


  Future<void> _bootstrap() async {
    try {
      final me = await _repo.me(); 
      if (!mounted) return;

      if (me.role != null && me.role!.isNotEmpty) {
        _goByRole(me.role!);
        return;
      }

      final enabled = <String>[];
      me.roles.forEach((k, v) {
        final on = v == true || v == 1 || v == 'true';
        if (on) enabled.add(k);
      });
      enabled.sort((a, b) => _uiOrder.indexOf(a).compareTo(_uiOrder.indexOf(b)));

      if (enabled.length == 1) {
        await _choose(enabled.first);
        return;
      }

      setState(() {
        _rolesFut = Future.value(enabled);
        _autoNavigating = false;
      });
    } catch (e) {
      setState(() {
        _rolesFut = Future.error(e);
        _autoNavigating = false;
      });
    }
  }

  Future<void> _choose(String role) async {
    await _repo.selectRole(role); 
    if (!mounted) return;
    _goByRole(role);
  }

  void _goByRole(String role) {
    switch (role) {
      case 'coordinator':
        context.go('/coordinator');
        break;
      case 'revisor':
        context.go('/revisor');
        break;
      case 'patient':
        context.go('/patient');
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rol no soportado: $role')),
        );
        setState(() => _autoNavigating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_autoNavigating) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return FutureBuilder<List<String>>(
      future: _rolesFut,
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Elige tu rol')),
            body: Center(child: Text('No se pudieron cargar tus roles.\n${snap.error}')),
          );
        }

        final roles = (snap.data ?? const <String>[]);
        return Scaffold(
          appBar: AppBar(title: const Text('Elige tu rol')),
          body: Center(
            child: roles.isEmpty
                ? const Text('No tienes roles asignados.')
                : Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: roles.map((role) {
                      final label = _roleLabel[role] ?? role;
                      return FilledButton.tonal(
                        onPressed: () => _choose(role),
                        child: Text(label),
                      );
                    }).toList(),
                  ),
          ),
        );
      },
    );
  }
}
