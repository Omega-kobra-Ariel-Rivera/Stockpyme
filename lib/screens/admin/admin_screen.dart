import 'package:flutter/material.dart';

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
      appBar: AppBar(title: const Text('Panel de administración')),
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
          final sales30 = all.fold<int>(0, (s, u) => s + u.sales30d);
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
                      label: 'Cuentas',
                      value: '${all.length}',
                      icon: Icons.people_outline),
                  AdminMetric(
                      label: 'Activas 7 días',
                      value: '$active7d',
                      icon: Icons.bolt_outlined),
                  AdminMetric(
                      label: 'Pro',
                      value: '$pro',
                      icon: Icons.workspace_premium_outlined,
                      color: scheme.primary),
                  AdminMetric(
                      label: 'En prueba / vencidas',
                      value: '$trial / $expired',
                      icon: Icons.hourglass_bottom_outlined,
                      color: scheme.tertiary),
                  AdminMetric(
                      label: 'Ventas 30 días (todos)',
                      value: formatCLP(sales30),
                      icon: Icons.payments_outlined),
                  AdminMetric(
                      label: 'Productos (todos)',
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
                  hintText: 'Buscar negocio, nombre o correo',
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
                    (_Filter.all, 'Todas (${all.length})'),
                    (_Filter.pro, 'Pro ($pro)'),
                    (_Filter.trial, 'Prueba ($trial)'),
                    (_Filter.expired, 'Vencidas ($expired)'),
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
                        ? 'Aún no hay cuentas registradas.'
                        : 'Ninguna cuenta coincide con la búsqueda.',
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
            '${user.products} productos · ${formatCLP(user.sales30d)} en 30 días · ${formatAgo(user.lastSeen)}',
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
