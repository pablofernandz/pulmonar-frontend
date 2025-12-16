import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tfg_app2/core/auth/auth_repository.dart';

class GlobalTopActions extends StatelessWidget {
  final String homeRoute;  
  final String profileRoute; 

  const GlobalTopActions({
    super.key,
    this.homeRoute = '/coordinator',
    this.profileRoute = '/coordinator/me',
  });

  Future<void> _handleLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Cerrar sesión'),
            content: const Text(
              '¿Seguro que quieres cerrar sesión en esta aplicación?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Cerrar sesión'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    try {
      await AuthRepository().logout();
      context.go('/login');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cerrar sesión: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Inicio',
          icon: const Icon(Icons.home_outlined),
          onPressed: () => context.go(homeRoute),
        ),
        IconButton(
          tooltip: 'Mi perfil',
          icon: const Icon(Icons.account_circle_outlined),
          onPressed: () => context.go(profileRoute),
        ),
        IconButton(
          tooltip: 'Cerrar sesión',
          icon: const Icon(Icons.logout),
          onPressed: () => _handleLogout(context),
        ),
      ],
    );
  }
}
