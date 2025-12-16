import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/components/top_actions.dart';

class CoordinatorShell extends StatelessWidget {
  final Widget child;
  const CoordinatorShell({super.key, required this.child});

  int _indexForLocation(String loc) {
    if (loc.startsWith('/coordinator/stats')) return 0;
    if (loc.startsWith('/coordinator/forms')) return 1;
    if (loc.startsWith('/coordinator/users')) return 2;
    if (loc.startsWith('/coordinator/groups')) return 3;
    return 2;
  }

  String _titleForLocation(String loc) {
    if (loc == '/coordinator' || loc == '/coordinator/') return 'Menú';
    if (loc.startsWith('/coordinator/profile')) return 'Mi perfil';
    return 'Menú';
  }

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    final sel = _indexForLocation(loc);
    final title = _titleForLocation(loc);

    void goTo(int i) {
      switch (i) {
        case 0:
          context.go('/coordinator/stats');
          break;
        case 1:
          context.go('/coordinator/forms');
          break;
        case 2:
          context.go('/coordinator/users');
          break;
        case 3:
          context.go('/coordinator/groups');
          break;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: const [
          GlobalTopActions(
            homeRoute: '/coordinator',
            profileRoute: '/coordinator/profile',
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            children: [
              const DrawerHeader(
                child: Text('Panel de coordinación', style: TextStyle(fontSize: 18)),
              ),
              ListTile(
                leading: const Icon(Icons.insights_outlined),
                title: const Text('Estadísticas'),
                selected: sel == 0,
                onTap: () {
                  Navigator.pop(context);
                  goTo(0);
                },
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Formularios'),
                selected: sel == 1,
                onTap: () {
                  Navigator.pop(context);
                  goTo(1);
                },
              ),
              ListTile(
                leading: const Icon(Icons.people_alt_outlined),
                title: const Text('Usuarios'),
                selected: sel == 2,
                onTap: () {
                  Navigator.pop(context);
                  goTo(2);
                },
              ),
              ListTile(
                leading: const Icon(Icons.groups_2_outlined),
                title: const Text('Grupos'),
                selected: sel == 3,
                onTap: () {
                  Navigator.pop(context);
                  goTo(3);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.home_outlined),
                title: const Text('Inicio'),
                onTap: () {
                  Navigator.pop(context);
                  context.go('/coordinator');
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Mi perfil'),
                onTap: () {
                  Navigator.pop(context);
                  context.go('/coordinator/profile');
                },
              ),
            ],
          ),
        ),
      ),
      body: Row(
        children: [
          LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 1000;
              if (!wide) return const SizedBox.shrink();
              return NavigationRail(
                selectedIndex: sel,
                onDestinationSelected: goTo,
                labelType: NavigationRailLabelType.selected,
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.insights_outlined),
                    selectedIcon: Icon(Icons.insights),
                    label: Text('Estadísticas'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.description_outlined),
                    selectedIcon: Icon(Icons.description),
                    label: Text('Formularios'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.people_alt_outlined),
                    selectedIcon: Icon(Icons.people_alt),
                    label: Text('Usuarios'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.groups_2_outlined),
                    selectedIcon: Icon(Icons.groups_2),
                    label: Text('Grupos'),
                  ),
                ],
              );
            },
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}
