import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_repository.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _dni = TextEditingController();
  final _pwd = TextEditingController();
  final _repo = AuthRepository();
  bool _busy = false;
  String? _err;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Iniciar sesión')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: _dni, decoration: const InputDecoration(labelText: 'DNI')),
                const SizedBox(height: 12),
                TextField(controller: _pwd, decoration: const InputDecoration(labelText: 'Contraseña'), obscureText: true),
                const SizedBox(height: 16),
                if (_err != null) Text(_err!, style: const TextStyle(color: Colors.red)),
                FilledButton(
                  onPressed: _busy ? null : () async {
                    setState(() { _busy = true; _err = null; });
                    try {
                      await _repo.login(dni: _dni.text.trim(), password: _pwd.text);
                      if (mounted) context.go('/role');
                    } catch (_) {
                      setState(() => _err = 'Credenciales inválidas o error de red');
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
                  child: _busy ? const CircularProgressIndicator() : const Text('Entrar'),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
