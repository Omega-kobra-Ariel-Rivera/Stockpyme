import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/i18n.dart';
import '../services/cart_service.dart';
import '../widgets/app_logo.dart';
import 'dashboard_screen.dart';
import 'products_screen.dart';
import 'reports_screen.dart';
import 'sale_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  void _goTo(int index) => setState(() => _index = index);

  /// En pantallas anchas (PC o tablet) el menú va a la izquierda.
  static const double _wideLayout = 840;

  @override
  Widget build(BuildContext context) {
    final cartLines = context.watch<CartService>().lineCount;
    final wide = MediaQuery.sizeOf(context).width >= _wideLayout;

    Widget cartIcon(IconData icon) => Badge(
          isLabelVisible: cartLines > 0,
          label: Text('$cartLines'),
          child: Icon(icon),
        );

    final pages = IndexedStack(
      index: _index,
      children: [
        DashboardScreen(onNavigate: _goTo),
        const ProductsScreen(),
        const SaleScreen(),
        const ReportsScreen(),
      ],
    );

    if (wide) {
      final scheme = Theme.of(context).colorScheme;
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              extended: MediaQuery.sizeOf(context).width >= 1100,
              selectedIndex: _index,
              onDestinationSelected: _goTo,
              backgroundColor: scheme.surfaceContainer,
              leading: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: AppLogo(size: 44),
              ),
              destinations: [
                NavigationRailDestination(
                  icon: Icon(Icons.space_dashboard_outlined),
                  selectedIcon: Icon(Icons.space_dashboard),
                  label: Text(tr('Inicio')),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.inventory_2_outlined),
                  selectedIcon: Icon(Icons.inventory_2),
                  label: Text(tr('Productos')),
                ),
                NavigationRailDestination(
                  icon: cartIcon(Icons.point_of_sale_outlined),
                  selectedIcon: cartIcon(Icons.point_of_sale),
                  label: Text(tr('Vender')),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.bar_chart_outlined),
                  selectedIcon: Icon(Icons.bar_chart),
                  label: Text(tr('Reportes')),
                ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: pages,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: pages,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _goTo,
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard),
            label: tr('Inicio'),
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: tr('Productos'),
          ),
          NavigationDestination(
            icon: cartIcon(Icons.point_of_sale_outlined),
            selectedIcon: cartIcon(Icons.point_of_sale),
            label: tr('Vender'),
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: tr('Reportes'),
          ),
        ],
      ),
    );
  }
}
