import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/i18n.dart';
import '../services/auth_service.dart';
import '../services/inventory_service.dart';
import '../services/report_service.dart';
import '../utils/formatters.dart';
import '../utils/theme.dart';
import '../widgets/app_logo.dart';
import '../widgets/price_calculator.dart';
import '../widgets/product_tile.dart';
import '../widgets/report_charts.dart';
import '../widgets/stat_card.dart';
import '../widgets/trial_banner.dart';
import 'admin/admin_screen.dart';
import 'receive_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.onNavigate});

  /// Cambia de pestaña: 1 = productos, 2 = vender, 3 = reportes.
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final inv = context.watch<InventoryService>();
    final scheme = Theme.of(context).colorScheme;
    final low = inv.lowStockProducts;
    final recent = inv.sales.take(5).toList();

    // En el PC (pantalla ancha) se usa un tablero en dos columnas.
    if (MediaQuery.sizeOf(context).width >= 840) {
      return _DesktopDashboard(onNavigate: onNavigate);
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            const AppLogo(size: 32),
            const SizedBox(width: 10),
            Expanded(
              child: Text(inv.businessLabel, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        actions: [
          if (context.watch<AuthService>().isAdmin)
            IconButton(
              tooltip: tr('Panel de administración'),
              icon: const Icon(Icons.admin_panel_settings_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdminScreen()),
              ),
            ),
          IconButton(
            tooltip: tr('Ajustes'),
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const TrialBanner(),
          _TodaySummary(
            total: inv.todayTotal,
            profit: inv.todayProfit,
            count: inv.todaySalesCount,
          ),
          const SizedBox(height: 12),
          StatGrid(
            maxColumns: 2,
            children: [
              StatCard(
                icon: Icons.warehouse_outlined,
                label: tr('Valor del inventario'),
                value: formatMoney(inv.inventoryValue),
              ),
              StatCard(
                icon: Icons.warning_amber_rounded,
                label: tr('Productos con stock bajo'),
                value: '${low.length}',
                highlight: low.isNotEmpty,
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => onNavigate(2),
            icon: const Icon(Icons.point_of_sale),
            label: Text(tr('Nueva venta')),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ReceiveScreen()),
            ),
            icon: const Icon(Icons.move_to_inbox_outlined),
            label: Text(tr('Recibir mercadería')),
          ),
          const SizedBox(height: 24),
          _SectionHeader(
            title: tr('Stock bajo'),
            actionLabel: low.isEmpty ? null : tr('Ver productos'),
            onAction: () => onNavigate(1),
          ),
          if (inv.products.isEmpty)
            _InfoCard(
              icon: Icons.inventory_2_outlined,
              message: tr('Aún no tienes productos. Agrégalos en la pestaña Productos.'),
              actionLabel: tr('Ir a productos'),
              onAction: () => onNavigate(1),
            )
          else if (low.isEmpty)
            _InfoCard(
              icon: Icons.check_circle_outline,
              message: tr('Todo en orden: ningún producto bajo el mínimo.'),
            )
          else
            Card(
              child: Column(
                children: [
                  for (final p in low.take(5)) ProductTile(product: p),
                ],
              ),
            ),
          const SizedBox(height: 24),
          _SectionHeader(
            title: tr('Últimas ventas'),
            actionLabel: recent.isEmpty ? null : tr('Ver reportes'),
            onAction: () => onNavigate(3),
          ),
          if (recent.isEmpty)
            _InfoCard(
              icon: Icons.receipt_long_outlined,
              message: tr('Las ventas que registres aparecerán aquí.'),
            )
          else
            Card(
              child: Column(
                children: [
                  for (final sale in recent)
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: scheme.secondaryContainer,
                        foregroundColor: scheme.onSecondaryContainer,
                        child: const Icon(Icons.receipt_outlined, size: 20),
                      ),
                      title: Text(formatMoney(sale.total),
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                          '${tr('N°')} ${sale.number} · ${formatDateTime(sale.date)} · ${sale.paymentMethod.label}'),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 32),
          const Center(child: MadeByRivera()),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Resumen destacado de las ventas del día.
class _TodaySummary extends StatelessWidget {
  const _TodaySummary({
    required this.total,
    required this.profit,
    required this.count,
  });

  final int total;
  final int profit;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.seed, AppTheme.seedDark],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                tr('Ventas de hoy'),
                style: TextStyle(
                  color: AppTheme.onBrandMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                formatDate(DateTime.now()),
                style: const TextStyle(
                  color: AppTheme.onBrandMuted,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatMoney(total),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SummaryPill(
                icon: Icons.receipt_long_outlined,
                label: count == 1
                    ? tr('1 venta')
                    : tr('{n} ventas', {'n': count}),
              ),
              _SummaryPill(
                icon: Icons.trending_up,
                label: tr('Ganancia {amount}', {'amount': formatMoney(profit)}),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
            if (actionLabel != null)
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Tablero del PC
// -----------------------------------------------------------------------------

class _DesktopDashboard extends StatelessWidget {
  const _DesktopDashboard({required this.onNavigate});

  final ValueChanged<int> onNavigate;

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return tr('Buenos días');
    if (h < 20) return tr('Buenas tardes');
    return tr('Buenas noches');
  }

  @override
  Widget build(BuildContext context) {
    final inv = context.watch<InventoryService>();
    final auth = context.watch<AuthService>();
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final low = inv.lowStockProducts;
    final recent = inv.sales.take(8).toList();
    final today = ReportService(inv, ReportRange.lastDays(1));
    final week = ReportService(inv, ReportRange.lastDays(7));
    final soon = ReportService.restock(inv)
        .where((x) => x.daysLeft != null && x.daysLeft! <= 7)
        .take(6)
        .toList();

    String? vsYesterday(num now, num before) {
      final pct = ReportService.change(now, before);
      if (pct == null) return null;
      return '${pct >= 0 ? '▲' : '▼'} ${pct.abs().toStringAsFixed(0)}% ${tr('vs ayer')}';
    }

    Color? vsColor(num now, num before) {
      final pct = ReportService.change(now, before);
      if (pct == null) return null;
      return pct >= 0 ? const Color(0xFF15803D) : scheme.error;
    }

    final left = Column(
      children: [
        _DeskPanel(
          title: tr('Ventas de los últimos 7 días'),
          trailing: Text(formatMoney(week.total),
              style: text.titleMedium?.copyWith(color: scheme.primary)),
          child: SizedBox(
            height: 200,
            child: SimpleBarChart(items: dailyBars(week.dailySales())),
          ),
        ),
        const SizedBox(height: 16),
        _DeskPanel(
          title: tr('Últimas ventas'),
          trailing: recent.isEmpty
              ? null
              : TextButton(
                  onPressed: () => onNavigate(3),
                  child: Text(tr('Ver reportes'))),
          child: recent.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(tr('Las ventas que registres aparecerán aquí.'),
                      style: TextStyle(color: scheme.onSurfaceVariant)),
                )
              : Column(
                  children: [
                    for (final sale in recent)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: scheme.secondaryContainer,
                          foregroundColor: scheme.onSecondaryContainer,
                          child: const Icon(Icons.receipt_outlined, size: 18),
                        ),
                        title: Text(
                            '${tr('N°')} ${sale.number} · ${sale.paymentMethod.label}'),
                        subtitle: Text(formatDateTime(sale.date)),
                        trailing: Text(formatMoney(sale.total),
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
        ),
      ],
    );

    final right = Column(
      children: [
        _DeskPanel(
          title: tr('Accesos rápidos'),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _QuickAction(
                icon: Icons.add_shopping_cart,
                label: tr('Nueva venta'),
                hint: 'F2',
                onTap: () => onNavigate(2),
                primary: true,
              ),
              _QuickAction(
                icon: Icons.move_to_inbox_outlined,
                label: tr('Recibir mercadería'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ReceiveScreen()),
                ),
              ),
              _QuickAction(
                icon: Icons.inventory_2_outlined,
                label: tr('Productos'),
                hint: 'Ctrl+2',
                onTap: () => onNavigate(1),
              ),
              _QuickAction(
                icon: Icons.insights_outlined,
                label: tr('Reportes'),
                hint: 'Ctrl+4',
                onTap: () => onNavigate(3),
              ),
              _QuickAction(
                icon: Icons.calculate_outlined,
                label: tr('Calculadora de precios'),
                onTap: () => showPriceCalculator(context, showUseButton: false),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _DeskPanel(
          title: tr('Stock bajo'),
          trailing: low.isEmpty
              ? null
              : TextButton(
                  onPressed: () => onNavigate(1),
                  child: Text(tr('Ver productos'))),
          child: inv.products.isEmpty
              ? _InfoCard(
                  icon: Icons.inventory_2_outlined,
                  message: tr(
                      'Aún no tienes productos. Agrégalos en la pestaña Productos.'),
                  actionLabel: tr('Ir a productos'),
                  onAction: () => onNavigate(1),
                )
              : low.isEmpty
                  ? _InfoCard(
                      icon: Icons.check_circle_outline,
                      message:
                          tr('Todo en orden: ningún producto bajo el mínimo.'),
                    )
                  : Column(
                      children: [
                        for (final p in low.take(6)) ProductTile(product: p),
                      ],
                    ),
        ),
        if (soon.isNotEmpty) ...[
          const SizedBox(height: 16),
          _DeskPanel(
            title: tr('Se acaban pronto'),
            trailing: TextButton(
                onPressed: () => onNavigate(3),
                child: Text(tr('Ver reposición'))),
            child: Column(
              children: [
                for (final x in soon)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Icon(Icons.event_busy_outlined,
                        color: x.daysLeft! <= 3
                            ? scheme.error
                            : const Color(0xFFD97706)),
                    title: Text(x.product.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Text(
                      x.daysLeft! < 1
                          ? tr('Hoy')
                          : tr('{n} días', {'n': x.daysLeft!.floor()}),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${_greeting()}, ${auth.displayName}',
                        style: text.headlineSmall),
                    const SizedBox(height: 2),
                    Text(
                      '${inv.businessLabel} · ${formatDate(DateTime.now())}',
                      style: text.bodyMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (auth.isAdmin)
                IconButton.filledTonal(
                  tooltip: tr('Panel de administración'),
                  icon: const Icon(Icons.admin_panel_settings_outlined),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AdminScreen()),
                  ),
                ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: tr('Ajustes'),
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const TrialBanner(),
          StatGrid(
            children: [
              StatCard(
                icon: Icons.payments_outlined,
                label: tr('Ventas de hoy'),
                value: formatMoney(today.total),
                caption: vsYesterday(today.total, today.previous.total) ??
                    tr('{n} ventas', {'n': today.sales.length}),
                captionColor: vsColor(today.total, today.previous.total),
                onTap: () => onNavigate(3),
              ),
              StatCard(
                icon: Icons.trending_up,
                label: tr('Ganancia de hoy'),
                value: formatMoney(today.profit),
                caption: tr('Margen {pct}',
                    {'pct': formatPercent(today.marginPercent)}),
                onTap: () => onNavigate(3),
              ),
              StatCard(
                icon: Icons.warehouse_outlined,
                label: tr('Valor del inventario'),
                value: formatMoney(inv.inventoryValue),
                caption: tr('{n} productos', {'n': inv.products.length}),
                onTap: () => onNavigate(1),
              ),
              StatCard(
                icon: Icons.warning_amber_rounded,
                label: tr('Productos con stock bajo'),
                value: '${low.length}',
                highlight: low.isNotEmpty,
                caption: low.isEmpty ? tr('Todo en orden') : tr('Revisa y repón'),
                onTap: () => onNavigate(1),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: left),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: right),
            ],
          ),
          const SizedBox(height: 28),
          const Center(child: MadeByRivera()),
        ],
      ),
    );
  }
}

class _DeskPanel extends StatelessWidget {
  const _DeskPanel({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 36,
              child: Row(
                children: [
                  Expanded(
                    child: Text(title,
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.hint,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final String? hint;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = primary ? AppTheme.accent : scheme.surfaceContainerHighest;
    final fg = primary ? const Color(0xFF3B2600) : scheme.onSurface;
    return SizedBox(
      width: 160,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: fg),
                    const Spacer(),
                    if (hint != null)
                      Text(hint!,
                          style: TextStyle(
                              fontSize: 11, color: fg.withValues(alpha: 0.6))),
                  ],
                ),
                const SizedBox(height: 10),
                Text(label,
                    maxLines: 2,
                    style: TextStyle(
                        color: fg, fontWeight: FontWeight.w700, height: 1.15)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
