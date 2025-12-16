import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SurveysLandingPage extends StatelessWidget {
  const SurveysLandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Formularios')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (_, c) {
                final wide = c.maxWidth >= 700;
                final card = (IconData icon, String title, String route) => Card(
                  elevation: 2,
                  child: InkWell(
                    onTap: () => context.go(route),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 42),
                          const SizedBox(width: 16),
                          Text(title, style: t.titleLarge),
                        ],
                      ),
                    ),
                  ),
                );
                return Wrap(
                  spacing: 20, runSpacing: 20, alignment: WrapAlignment.center,
                  children: [
                    SizedBox(width: wide ? 380 : double.infinity,
                      child: card(Icons.search, 'Buscar formularios', '/coordinator/forms/search')),
                    SizedBox(width: wide ? 380 : double.infinity,
                      child: card(Icons.add_circle_outline, 'Crear formulario', '/coordinator/forms/create')),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
