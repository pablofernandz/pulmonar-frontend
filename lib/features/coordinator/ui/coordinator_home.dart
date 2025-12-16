import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CoordinatorHomePage extends StatelessWidget {
  const CoordinatorHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    final cards = <_HomeCard>[
      _HomeCard(
        title: 'Estadísticas',
        icon: Icons.analytics_outlined,
        route: '/coordinator/stats',
        color: Colors.blue,
      ),
      _HomeCard(
        title: 'Formularios',
        icon: Icons.assignment_outlined,
        route: '/coordinator/forms',
        color: Colors.orange,
      ),
      _HomeCard(
        title: 'Usuarios',
        icon: Icons.people_alt_outlined,
        route: '/coordinator/users',
        color: Colors.teal,
      ),
      _HomeCard(
        title: 'Grupos',
        icon: Icons.groups_2_outlined,
        route: '/coordinator/groups',
        color: Colors.purple,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inicio coordinador'),
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
