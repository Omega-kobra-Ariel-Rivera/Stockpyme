import 'package:flutter/material.dart';

import '../../l10n/i18n.dart';
import '../../models/admin_user.dart';
import '../../services/admin_service.dart';
import '../../utils/formatters.dart';
import 'admin_user_screen.dart';
import 'admin_widgets.dart';

enum _Filter { all, pro, trial, expired }

/// Panel de administración: todas las cuentas y sus negocios.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _search = TextEditingController();
  final Stream<List<AdminUser>> _users = AdminService.watchUsers();
  _Filter _filter = _Filter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _passesFilter(AdminUser u) => switch (_filter) {
        _Filter.all => true,
        _Filter.pro => u.plan.isPro,
        _Filter.trial => u.plan == AdminPlan.trial,
        _Filter.expired => u.plan == AdminPlan.expired,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(tr('Panel de administración'))),
      body: StreamBuilder<List<AdminUser>>(
        stream: _users,
        builder: (context, snap) {
          if (snap.hasError) return AdminErrorView(error: snap.error);
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snap.data!;
          final pro = all.where((u) => u.plan.isPro).length;
          final trial = all.where((u) => u.plan == AdminPlan.trial).length;
          final expired =
              all.where((u) => u.plan == AdminPlan.expired).length;
          final active7d = all
              .where((u) =>
                  u.lastSeen != null &&
                  DateTime.now().difference(u.lastSeen!).inDays < 7)
              .length;
          // Solo se suman negocios en pesos chilenos (no se mezclan monedas).
          final sales30 = all
              .where((u) => u.currency == AppCurrency.clp)
              .fold<int>(0, (s, u) => s + u.sales30d);
          final products = all.fold<int>(0, (s, u) => s + u.products);

          final list = all
              .where((u) => _passesFilter(u) && u.matches(_search.text))
              .toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.3,
                children: [
                  AdminMetric(
                      label: tr('Cuentas'),
                      value: '${all.length}',
                      icon: Icons.people_outline),
                  AdminMetric(
                      label: tr('Activas 7 días'),
                      value: '$active7d',
                      icon: Icons.bolt_outlined),
                  AdminMetric(
                      label: tr('Pro'),
                      value: '$pro',
                      icon: Icons.workspace_premium_outlined,
                      color: scheme.primary),
                  AdminMetric(
                      label: tr('En prueba / vencidas'),
                      value: '$trial / $expired',
                      icon: Icons.hourglass_bottom_outlined,
                      color: scheme.tertiary),
                  AdminMetric(
                      label: tr('Ventas 30 días (CLP)'),
                      value: formatCLP(sales30),
                      icon: Icons.payments_outlined),
                  AdminMetric(
                      label: tr('Productos (todos)'),
                      value: '$products',
                      icon: Icons.inventory_2_outlined),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: tr('Buscar negocio, nombre o correo'),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(_search.clear),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  for (final (f, label) in [
                    (_Filter.all, tr('Todas ({n})', {'n': all.length})),
                    (_Filter.pro, tr('Pro ({n})', {'n': pro})),
                    (_Filter.trial, tr('Prueba ({n})', {'n': trial})),
                    (_Filter.expired, tr('Vencidas ({n})', {'n': expired})),
                  ])
                    ChoiceChip(
                      label: Text(label),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Text(
                    all.isEmpty
                        ? tr('Aún no hay cuentas registradas.')
                        : tr('Ninguna cuenta coincide con la búsqueda.'),
                    textAlign: TextAlign.center,
                    style: text.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                )
              else
                Card(
                  child: Column(
                    children: [
                      for (var i = 0; i < list.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        _UserTile(user: list[i]),
                      ],
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user});

  final AdminUser user;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final initial = user.displayName.isEmpty
        ? '?'
        : user.displayName.substring(0, 1).toUpperCase();

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        child: Text(initial),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(user.displayName,
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          PlanBadge(plan: user.plan, trialDaysLeft: user.trialDaysLeft),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(user.email, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(
            tr('{n} productos · {amount} en 30 días · {ago}', {
              'n': user.products,
              'amount': user.currency.format(user.sales30d),
              'ago': formatAgo(user.lastSeen),
            }),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => AdminUserScreen(initial: user)),
      ),
    );
  }
}
