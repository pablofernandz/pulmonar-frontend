import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/token_storage.dart';
import '../../../ui/components/top_actions.dart';

class RevisorHomePage extends StatelessWidget {
  const RevisorHomePage({super.key});

  Future<void> _logout(BuildContext context) async {
    await TokenStorage.instance.clearToken();
    await TokenStorage.instance.clearRole();
    if (context.mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    final cards = <_HomeCard>[
      _HomeCard(
        title: 'Pacientes',
        icon: Icons.people_outline,
        route: '/revisor/pacientes',
        color: Colors.teal, 
      ),
      _HomeCard(
        title: 'Evaluar pacientes',
        icon: Icons.task_alt_outlined,
        route: '/revisor/evaluar',
        color: Colors.purple, 
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inicio • Tutor/Revisor'),
        actions: const [
          GlobalTopActions(
            homeRoute: '/revisor',
            profileRoute: '/revisor/profile',
          ),
        ],

      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (_, c) {
                  final w = c.maxWidth;
                  final cols = w >= 1000
                      ? 4
                      : w >= 740
                          ? 3
                          : w >= 480
                              ? 2
                              : 1;

                  return GridView.count(
                    crossAxisCount: cols,
                    childAspectRatio: 1.22,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    children: cards
                        .map((card) => _NavCard(card: card, textTheme: t))
                        .toList(),
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

class _HomeCard {
  final String title;
  final IconData icon;
  final String route;
  final Color color;
  const _HomeCard({
    required this.title,
    required this.icon,
    required this.route,
    required this.color,
  });
}

class _NavCard extends StatelessWidget {
  final _HomeCard card;
  final TextTheme textTheme;
  const _NavCard({required this.card, required this.textTheme});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    return Semantics(
      button: true,
      label: card.title,
      child: Tooltip(
        message: card.title,
        child: Card(
          elevation: 2,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: radius),
          child: InkWell(
            borderRadius: radius,
            onTap: () => context.go(card.route),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(card.icon, size: 52, color: card.color),
                  const SizedBox(height: 14),
                  Text(card.title, style: textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                    'Entrar',
                    style: textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

