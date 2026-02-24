import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ScaffoldWithNavBar extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const ScaffoldWithNavBar({
    required this.navigationShell,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.list_alt), label: 'Expenses'),
          NavigationDestination(icon: Icon(Icons.add_circle_outline), label: 'Add'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Analytics'),
          NavigationDestination(icon: Icon(Icons.flag_outlined), label: 'Goals'),
        ],
      ),
    );
  }
}
