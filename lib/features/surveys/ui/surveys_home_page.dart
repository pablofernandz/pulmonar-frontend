import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SurveysHomePage extends StatelessWidget {
  const SurveysHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cards = <_CardDef>[
      _CardDef('Buscar formularios', Icons.search_outlined, '/coordinator/forms/search', Colors.teal),
      _CardDef('Crear formulario', Icons.add_box_outlined, '/coordinator/forms/new', Colors.orange),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Formularios')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (_, c) {
                  final w = c.maxWidth;
                  final cols = w >= 1000 ? 4 : w >= 740 ? 3 : w >= 480 ? 2 : 1;
                  return GridView.count(
                    crossAxisCount: cols,
                    childAspectRatio: 1.22,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    children: cards.map((e) => _NavCard(def: e, textTheme: t)).toList(),
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

class _CardDef {
  final String title;
  final IconData icon;
  final String route;
  final Color color;
  const _CardDef(this.title, this.icon, this.route, this.color);
}

class _NavCard extends StatelessWidget {
  final _CardDef def;
  final TextTheme textTheme;
  const _NavCard({required this.def, required this.textTheme});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: radius),
      child: InkWell(
        borderRadius: radius,
        onTap: () => context.go(def.route),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(def.icon, size: 52, color: def.color),
              const SizedBox(height: 14),
              Text(def.title, style: textTheme.titleMedium),
              const SizedBox(height: 6),
              Text('Entrar', style: textTheme.bodySmall?.copyWith(color: Colors.grey[700])),
            ],
          ),
        ),
      ),
    );
  }
}
