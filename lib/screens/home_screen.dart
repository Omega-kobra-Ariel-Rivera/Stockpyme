import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/i18n.dart';
import '../services/cart_service.dart';
import '../services/inventory_service.dart';
import '../services/subscription_service.dart';
import '../utils/constants.dart';
import '../utils/theme.dart';
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
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= _wideLayout;

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
      // Atajos de teclado del PC: Ctrl+1..4 cambian de sección, F2 = vender.
      return CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.digit1, control: true): () =>
              _goTo(0),
          const SingleActivator(LogicalKeyboardKey.digit2, control: true): () =>
              _goTo(1),
          const SingleActivator(LogicalKeyboardKey.digit3, control: true): () =>
              _goTo(2),
          const SingleActivator(LogicalKeyboardKey.digit4, control: true): () =>
              _goTo(3),
          const SingleActivator(LogicalKeyboardKey.f2): () => _goTo(2),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: scheme.surfaceContainerLowest,
            body: Row(
              children: [
                _DesktopSidebar(
                  index: _index,
                  onSelect: _goTo,
                  extended: width >= 1100,
                  cartLines: cartLines,
                ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1280),
                      child: pages,
                    ),
                  ),
                ),
              ],
            ),
          ),
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
            icon: const Icon(Icons.space_dashboard_outlined),
            selectedIcon: const Icon(Icons.space_dashboard),
            label: tr('Inicio'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.inventory_2_outlined),
            selectedIcon: const Icon(Icons.inventory_2),
            label: tr('Productos'),
          ),
          NavigationDestination(
            icon: cartIcon(Icons.point_of_sale_outlined),
            selectedIcon: cartIcon(Icons.point_of_sale),
            label: tr('Vender'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.bar_chart_outlined),
            selectedIcon: const Icon(Icons.bar_chart),
            label: tr('Reportes'),
          ),
        ],
      ),
    );
  }
}

class _NavEntry {
  const _NavEntry(this.icon, this.selectedIcon, this.label, this.shortcut);
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String shortcut;
}

/// Menú lateral del PC con los colores de la marca y la firma de
/// Rivera Systems abajo.
class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({
    required this.index,
    required this.onSelect,
    required this.extended,
    required this.cartLines,
  });

  final int index;
  final ValueChanged<int> onSelect;
  final bool extended;
  final int cartLines;

  @override
  Widget build(BuildContext context) {
    final inv = context.watch<InventoryService>();
    final sub = context.watch<SubscriptionService>();
    final entries = [
      _NavEntry(Icons.space_dashboard_outlined, Icons.space_dashboard,
          tr('Inicio'), 'Ctrl+1'),
      _NavEntry(Icons.inventory_2_outlined, Icons.inventory_2, tr('Productos'),
          'Ctrl+2'),
      _NavEntry(Icons.point_of_sale_outlined, Icons.point_of_sale,
          tr('Vender'), 'F2'),
      _NavEntry(Icons.bar_chart_outlined, Icons.bar_chart, tr('Reportes'),
          'Ctrl+4'),
    ];

    return Container(
      width: extended ? 248 : 88,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppTheme.seedDark, Color(0xFF083B37)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Marca
            Padding(
              padding: EdgeInsets.symmetric(horizontal: extended ? 18 : 0),
              child: Row(
                mainAxisAlignment: extended
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const AppLogo(size: 46),
                  ),
                  if (extended) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            AppConstants.appName,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            inv.businessLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.onBrandMuted,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 22),
            // Botón destacado: nueva venta
            Padding(
              padding: EdgeInsets.symmetric(horizontal: extended ? 16 : 14),
              child: SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: const Color(0xFF3B2600),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => onSelect(2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_shopping_cart, size: 20),
                      if (extended) ...[
                        const SizedBox(width: 8),
                        Text(tr('Nueva venta'),
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 15)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            for (var i = 0; i < entries.length; i++)
              _SidebarItem(
                entry: entries[i],
                selected: i == index,
                extended: extended,
                badge: i == 2 && cartLines > 0 ? '$cartLines' : null,
                onTap: () => onSelect(i),
              ),
            const Spacer(),
            // Estado del plan
            if (extended)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        sub.negocioActive
                            ? Icons.verified
                            : Icons.workspace_premium_outlined,
                        size: 18,
                        color: sub.negocioActive
                            ? const Color(0xFF6EE7B7)
                            : AppTheme.accent,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          sub.adminAccess
                              ? tr('Administrador · acceso total')
                              : sub.negocioActive
                                  ? tr('Plan Negocio activo')
                                  : tr('Sin Plan Negocio'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Divider(
              color: Colors.white.withValues(alpha: 0.12),
              indent: 16,
              endIndent: 16,
            ),
            // Firma de la empresa
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
              child: extended
                  ? Column(
                      children: [
                        const MadeByRivera(onBrand: true),
                        const SizedBox(height: 6),
                        Text(
                          'v${AppConstants.appVersion} · ${AppConstants.companyLocation}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    )
                  : Tooltip(
                      message:
                          '${tr('Hecho por')} ${AppConstants.company}',
                      child: const CompanyLogo(size: 34),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.entry,
    required this.selected,
    required this.extended,
    required this.onTap,
    this.badge,
  });

  final _NavEntry entry;
  final bool selected;
  final bool extended;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : const Color(0xFFB7DCD6);
    Widget icon = Icon(selected ? entry.selectedIcon : entry.icon,
        color: fg, size: 22);
    if (badge != null) {
      icon = Badge(label: Text(badge!), child: icon);
    }

    final tile = Material(
      color: selected ? Colors.white.withValues(alpha: 0.14) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        hoverColor: Colors.white.withValues(alpha: 0.07),
        onTap: onTap,
        child: Container(
          height: 48,
          padding: EdgeInsets.only(right: extended ? 12 : 0),
          child: Row(
            mainAxisAlignment:
                extended ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              if (extended) ...[
                Container(
                  width: 4,
                  height: 22,
                  decoration: BoxDecoration(
                    color: selected ? AppTheme.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              icon,
              if (extended) ...[
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    entry.label,
                    style: TextStyle(
                      color: fg,
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  entry.shortcut,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: extended ? 12 : 14, vertical: 3),
      child: extended ? tile : Tooltip(message: entry.label, child: tile),
    );
  }
}
