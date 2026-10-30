import 'package:flutter/material.dart';

import '../../models/admin_user.dart';
import '../../models/product.dart';
import '../../models/sale.dart';
import '../../services/admin_service.dart';
import '../../utils/formatters.dart';
import 'admin_widgets.dart';

/// Detalle de una cuenta: negocio, plan, inventario con precios y ventas.
class AdminUserScreen extends StatefulWidget {
  const AdminUserScreen({super.key, required this.initial});

  final AdminUser initial;

  @override
  State<AdminUserScreen> createState() => _AdminUserScreenState();
}

class _AdminUserScreenState extends State<AdminUserScreen> {
  late final Stream<AdminUser> _user =
      AdminService.watchUser(widget.initial.uid);
  late final Stream<List<Product>> _products =
      AdminService.watchProducts(widget.initial.uid);
  late final Stream<List<Sale>> _sales =
      AdminService.watchSales(widget.initial.uid);
  bool _busy = false;

  Future<void> _changePlan(AdminUser user, {int? days}) async {
    final grant = days != null;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(grant ? 'Activar Pro' : 'Quitar Pro manual'),
        content: Text(grant
            ? '¿Dar $days días de Pro a ${user.displayName}? Úsalo cuando te pague por fuera de la app (efectivo, transferencia) o para regalar días.'
            : '¿Quitar el Pro manual de ${user.displayName}? Si paga con Mercado Pago, esa suscripción sigue activa.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(grant ? 'Activar' : 'Quitar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      if (days != null) {
        await AdminService.grantPro(user, days);
      } else {
        await AdminService.revokePro(user);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(grant ? 'Pro activado' : 'Pro manual quitado')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo cambiar el plan: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: StreamBuilder<AdminUser>(
        stream: _user,
        initialData: widget.initial,
        builder: (context, snap) {
          final user = snap.data ?? widget.initial;
          return Scaffold(
            appBar: AppBar(
              title: Text(user.displayName,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              bottom: const TabBar(
                tabs: [
                  Tab(text: 'Resumen'),
                  Tab(text: 'Inventario'),
                  Tab(text: 'Ventas'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _SummaryTab(
                  user: user,
                  busy: _busy,
                  onGrant: (days) => _changePlan(user, days: days),
                  onRevoke: () => _changePlan(user),
                ),
                _InventoryTab(stream: _products),
                _SalesTab(stream: _sales),
              ],
            ),
          );
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Resumen
// -----------------------------------------------------------------------------

class _SummaryTab extends StatelessWidget {
  const _SummaryTab({
    required this.user,
    required this.busy,
    required this.onGrant,
    required this.onRevoke,
  });

  final AdminUser user;
  final bool busy;
  final ValueChanged<int> onGrant;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final String planDetail = switch (user.plan) {
      AdminPlan.proMercadoPago => 'Suscripción activa en Mercado Pago.',
      AdminPlan.proManual =>
        'Activado a mano hasta el ${formatDate(user.manualProUntil!)}.',
      AdminPlan.trial =>
        'Le quedan ${user.trialDaysLeft} días de prueba gratis.',
      AdminPlan.expired => 'La prueba terminó y no tiene suscripción.',
    };

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(user.displayName, style: text.titleLarge),
                    ),
                    PlanBadge(
                        plan: user.plan, trialDaysLeft: user.trialDaysLeft),
                  ],
                ),
                const SizedBox(height: 10),
                _Info(Icons.person_outline,
                    user.name.isEmpty ? 'Sin nombre' : user.name),
                _Info(Icons.mail_outline, user.email),
                _Info(
                  Icons.login,
                  user.provider == 'google.com'
                      ? 'Entra con Google'
                      : 'Entra con correo y contraseña',
                ),
                _Info(Icons.event_outlined,
                    'Registro: ${user.createdAt == null ? 'sin datos' : formatDate(user.createdAt!)}'),
                _Info(Icons.access_time,
                    'Última conexión: ${formatAgo(user.lastSeen)}'),
                if (user.appVersion.isNotEmpty)
                  _Info(Icons.phone_android,
                      'StockPyme ${user.appVersion} · ${user.platform}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.3,
          children: [
            AdminMetric(
                label: 'Productos',
                value: '${user.products}',
                icon: Icons.inventory_2_outlined),
            AdminMetric(
                label: 'Stock bajo',
                value: '${user.lowStock}',
                icon: Icons.warning_amber_rounded,
                color: user.lowStock > 0 ? scheme.error : null),
            AdminMetric(
                label: 'Valor inventario',
                value: formatCLP(user.inventoryValue),
                icon: Icons.warehouse_outlined),
            AdminMetric(
                label: 'Ventas hoy',
                value: formatCLP(user.salesToday),
                icon: Icons.today_outlined),
            AdminMetric(
                label: 'Ventas 30 días',
                value: formatCLP(user.sales30d),
                icon: Icons.payments_outlined),
            AdminMetric(
                label: 'N° ventas 30 días',
                value: '${user.salesCount30d}',
                icon: Icons.receipt_long_outlined),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Plan', style: text.titleMedium),
                const SizedBox(height: 4),
                Text(planDetail,
                    style: text.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: busy ? null : () => onGrant(30),
                      icon: const Icon(Icons.add),
                      label: const Text('Pro 30 días'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: busy ? null : () => onGrant(365),
                      icon: const Icon(Icons.add),
                      label: const Text('Pro 1 año'),
                    ),
                    if (user.manualProActive)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 40),
                          foregroundColor: scheme.error,
                        ),
                        onPressed: busy ? null : onRevoke,
                        icon: const Icon(Icons.remove_circle_outline),
                        label: const Text('Quitar Pro manual'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Info extends StatelessWidget {
  const _Info(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Inventario
// -----------------------------------------------------------------------------

class _InventoryTab extends StatelessWidget {
  const _InventoryTab({required this.stream});

  final Stream<List<Product>> stream;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return StreamBuilder<List<Product>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) return AdminErrorView(error: snap.error);
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final products = snap.data!;
        if (products.isEmpty) {
          return const Center(child: Text('Este negocio aún no tiene productos.'));
        }
        final value = products.fold<int>(
            0, (s, p) => s + (p.costPrice * (p.stock < 0 ? 0 : p.stock)).round());
        final low = products.where((p) => p.isLowStock).length;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Text(
              '${products.length} productos · $low con stock bajo · valor ${formatCLP(value)}',
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            Card(
              child: Column(
                children: [
                  for (var i = 0; i < products.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _ProductRow(product: products[i]),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final p = product;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleSmall),
                Text(
                  [
                    if (p.category.isNotEmpty) p.category,
                    'costo ${formatCLP(p.costPrice)}',
                    'margen ${formatPercent(p.marginPercent)}',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatCLP(p.salePrice),
                  style: text.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
              Text(
                '${formatQty(p.stock)} ${p.unit}',
                style: text.bodySmall?.copyWith(
                  color: p.isLowStock ? scheme.error : scheme.onSurfaceVariant,
                  fontWeight: p.isLowStock ? FontWeight.w700 : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Ventas
// -----------------------------------------------------------------------------

class _SalesTab extends StatelessWidget {
  const _SalesTab({required this.stream});

  final Stream<List<Sale>> stream;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return StreamBuilder<List<Sale>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) return AdminErrorView(error: snap.error);
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final sales = snap.data!;
        if (sales.isEmpty) {
          return const Center(child: Text('Este negocio aún no tiene ventas.'));
        }
        final total = sales.fold<int>(0, (s, x) => s + x.total);
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Text(
              'Últimas ${sales.length} ventas · ${formatCLP(total)}',
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            Card(
              child: Column(
                children: [
                  for (final sale in sales)
                    ExpansionTile(
                      shape: const Border(),
                      title: Text('N° ${sale.number} · ${formatCLP(sale.total)}',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                          '${formatDateTime(sale.date)} · ${sale.paymentMethod.label}'),
                      children: [
                        for (final item in sale.items)
                          ListTile(
                            dense: true,
                            title: Text(item.name),
                            subtitle: Text(
                                '${formatQty(item.quantity)} × ${formatCLP(item.unitPrice)}'),
                            trailing: Text(formatCLP(item.subtotal)),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
