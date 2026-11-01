import 'package:flutter/material.dart';

import '../../l10n/i18n.dart';
import '../../models/admin_user.dart';
import '../../models/product.dart';
import '../../models/sale.dart';
import '../../services/admin_service.dart';
import '../../utils/constants.dart';
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

  Future<void> _changePlan(AdminUser user,
      {int? days, PlanTier tier = PlanTier.basico}) async {
    final grant = days != null;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(grant ? tr('Activar Pro') : tr('Quitar Pro manual')),
        content: Text(grant
            ? tr('¿Dar {days} días del Plan {tier} a {name}? Úsalo cuando te pague por fuera de la app (efectivo, transferencia) o para regalar días.',
                {'days': days, 'tier': tr(tier.title), 'name': user.displayName})
            : tr('¿Quitar el Pro manual de {name}? Si paga con Mercado Pago, esa suscripción sigue activa.',
                {'name': user.displayName})),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(tr('Cancelar')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(grant ? tr('Activar') : tr('Quitar')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      if (days != null) {
        await AdminService.grantPro(user, days, tier);
      } else {
        await AdminService.revokePro(user);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(grant ? tr('Pro activado') : tr('Pro manual quitado'))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(tr('No se pudo cambiar el plan: {error}',
                  {'error': e}))));
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
              bottom: TabBar(
                tabs: [
                  Tab(text: tr('Resumen')),
                  Tab(text: tr('Inventario')),
                  Tab(text: tr('Ventas')),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _SummaryTab(
                  user: user,
                  busy: _busy,
                  onGrant: (days, tier) =>
                      _changePlan(user, days: days, tier: tier),
                  onRevoke: () => _changePlan(user),
                ),
                _InventoryTab(stream: _products, currency: user.currency),
                _SalesTab(stream: _sales, currency: user.currency),
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
  final void Function(int days, PlanTier tier) onGrant;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final String planDetail = switch (user.plan) {
      AdminPlan.proMercadoPago => tr('Suscripción activa en Mercado Pago.'),
      AdminPlan.proManual =>
        tr('Plan {tier} activado a mano hasta el {date}.', {
          'tier': tr(user.manualProTier.title),
          'date': formatDate(user.manualProUntil!),
        }),
      AdminPlan.trial =>
        tr('Le quedan {n} días de prueba gratis.', {'n': user.trialDaysLeft}),
      AdminPlan.expired => tr('La prueba terminó y no tiene suscripción.'),
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
                        plan: user.plan,
                        trialDaysLeft: user.trialDaysLeft,
                        tier: user.displayTier),
                  ],
                ),
                const SizedBox(height: 10),
                _Info(Icons.person_outline,
                    user.name.isEmpty ? tr('Sin nombre') : user.name),
                _Info(Icons.mail_outline, user.email),
                _Info(
                  Icons.login,
                  user.provider == 'google.com'
                      ? tr('Entra con Google')
                      : tr('Entra con correo y contraseña'),
                ),
                _Info(Icons.event_outlined,
                    tr('Registro: {date}', {
                      'date': user.createdAt == null
                          ? tr('sin datos')
                          : formatDate(user.createdAt!),
                    })),
                _Info(Icons.access_time,
                    tr('Última conexión: {ago}', {'ago': formatAgo(user.lastSeen)})),
                _Info(Icons.payments_outlined,
                    tr('Moneda: {name} ({code})', {
                      'name': tr(user.currency.label),
                      'code': user.currency.code,
                    })),
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
                label: tr('Productos'),
                value: '${user.products}',
                icon: Icons.inventory_2_outlined),
            AdminMetric(
                label: tr('Stock bajo'),
                value: '${user.lowStock}',
                icon: Icons.warning_amber_rounded,
                color: user.lowStock > 0 ? scheme.error : null),
            AdminMetric(
                label: tr('Valor inventario'),
                value: user.currency.format(user.inventoryValue),
                icon: Icons.warehouse_outlined),
            AdminMetric(
                label: tr('Ventas hoy'),
                value: user.currency.format(user.salesToday),
                icon: Icons.today_outlined),
            AdminMetric(
                label: tr('Ventas 30 días'),
                value: user.currency.format(user.sales30d),
                icon: Icons.payments_outlined),
            AdminMetric(
                label: tr('N° ventas 30 días'),
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
                Text(tr('Plan'), style: text.titleMedium),
                const SizedBox(height: 4),
                Text(planDetail,
                    style: text.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 14),
                if (user.tier != null) ...[
                  const SizedBox(height: 4),
                  Text(
                      tr('Nivel activo: {tier}', {'tier': tr(user.tier!.title)}),
                      style: text.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ],
                for (final tier in PlanTier.values) ...[
                  const SizedBox(height: 14),
                  Text('${tr(tier.title)} · ${tr(tier.subtitle)}',
                      style: text.labelLarge),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final (days, label) in [
                        (30, tr('30 días')),
                        (182, tr('6 meses')),
                        (365, tr('1 año')),
                      ])
                        FilledButton.tonalIcon(
                          onPressed: busy ? null : () => onGrant(days, tier),
                          icon: const Icon(Icons.add),
                          label: Text(label),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (user.manualProActive)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 40),
                          foregroundColor: scheme.error,
                        ),
                        onPressed: busy ? null : onRevoke,
                        icon: const Icon(Icons.remove_circle_outline),
                        label: Text(tr('Quitar Pro manual')),
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
  const _InventoryTab({required this.stream, required this.currency});

  final Stream<List<Product>> stream;
  final AppCurrency currency;

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
          return Center(child: Text(tr('Este negocio aún no tiene productos.')));
        }
        final value = products.fold<int>(
            0, (s, p) => s + (p.costPrice * (p.stock < 0 ? 0 : p.stock)).round());
        final low = products.where((p) => p.isLowStock).length;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Text(
              tr('{n} productos · {low} con stock bajo · valor {value}', {
                'n': products.length,
                'low': low,
                'value': currency.format(value),
              }),
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            Card(
              child: Column(
                children: [
                  for (var i = 0; i < products.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _ProductRow(product: products[i], currency: currency),
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
  const _ProductRow({required this.product, required this.currency});

  final Product product;
  final AppCurrency currency;

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
                    tr('costo {price}', {'price': currency.format(p.costPrice)}),
                    tr('margen {pct}', {'pct': formatPercent(p.marginPercent)}),
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
              Text(currency.format(p.salePrice),
                  style: text.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
              Text(
                '${formatQty(p.stock)} ${unitLabel(p.unit)}',
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
  const _SalesTab({required this.stream, required this.currency});

  final Stream<List<Sale>> stream;
  final AppCurrency currency;

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
          return Center(child: Text(tr('Este negocio aún no tiene ventas.')));
        }
        final total = sales.fold<int>(0, (s, x) => s + x.total);
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Text(
              tr('Últimas {n} ventas · {total}', {
                'n': sales.length,
                'total': currency.format(total),
              }),
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            Card(
              child: Column(
                children: [
                  for (final sale in sales)
                    ExpansionTile(
                      shape: const Border(),
                      title: Text('${tr('N°')} ${sale.number} · ${currency.format(sale.total)}',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                          '${formatDateTime(sale.date)} · ${sale.paymentMethod.label}'),
                      children: [
                        for (final item in sale.items)
                          ListTile(
                            dense: true,
                            title: Text(item.name),
                            subtitle: Text(
                                '${formatQty(item.quantity)} × ${currency.format(item.unitPrice)}'),
                            trailing: Text(currency.format(item.subtotal)),
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
