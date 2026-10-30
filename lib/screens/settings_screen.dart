import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/cart_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/inventory_service.dart';
import '../services/subscription_service.dart';
import '../utils/access_guard.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../widgets/app_logo.dart';
import 'admin/admin_screen.dart';
import 'paywall_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _editBusinessName(BuildContext context) async {
    final inv = context.read<InventoryService>();
    final controller = TextEditingController(text: inv.businessName);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nombre del negocio'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Ej: Almacén Don Pedro'),
          onSubmitted: (v) => Navigator.of(dialogContext).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null) await inv.setBusinessName(name);
  }

  Future<void> _deleteAll(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Borrar todos los datos'),
        content: const Text(
            'Se eliminarán productos, ventas y movimientos de este teléfono y de tu respaldo en la nube. Esta acción no se puede deshacer. Te recomendamos exportar antes.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Borrar todo'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    context.read<CartService>().clear();
    await context.read<InventoryService>().deleteAllData();
    if (context.mounted) showMessage(context, 'Datos eliminados');
  }

  Future<void> _signOut(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text(
            'Tus datos quedan guardados en este teléfono y en la nube. Podrás verlos otra vez al iniciar sesión.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    final sync = context.read<CloudSyncService>();
    final auth = context.read<AuthService>();
    // Sube lo pendiente antes de salir (si hay internet).
    await sync.syncNow().timeout(const Duration(seconds: 6), onTimeout: () {});
    await auth.signOut();
  }

  String _syncLabel(CloudSyncService sync) {
    if (sync.syncing) return 'Respaldando…';
    if (sync.error != null) return sync.error!;
    final last = sync.lastSync;
    if (last == null) return 'Toca para respaldar ahora';
    return 'Último respaldo: ${formatDateTime(last)}';
  }

  @override
  Widget build(BuildContext context) {
    final inv = context.watch<InventoryService>();
    final auth = context.watch<AuthService>();
    final sync = context.watch<CloudSyncService>();
    final sub = context.watch<SubscriptionService>();
    final scheme = Theme.of(context).colorScheme;

    final String subStatus;
    if (sub.manualProActive && !sub.mercadoPagoActive) {
      subStatus = 'Activa hasta el ${formatDate(sub.manualProUntil!)}';
    } else if (sub.isSubscribed) {
      subStatus = 'Activa · ${sub.priceLabel}';
    } else if (sub.inTrial) {
      subStatus = 'Prueba gratis: ${sub.trialDaysLeft} días restantes';
    } else {
      subStatus = 'Prueba terminada';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        children: [
          const _Header('Cuenta'),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: scheme.primaryContainer,
              foregroundColor: scheme.onPrimaryContainer,
              child: Text(
                auth.displayName.isEmpty
                    ? '?'
                    : auth.displayName.substring(0, 1).toUpperCase(),
              ),
            ),
            title: Text(auth.displayName),
            subtitle: Text(
                auth.usesGoogle ? '${auth.email} · Google' : auth.email),
          ),
          ListTile(
            leading: Icon(
              sync.error == null
                  ? Icons.cloud_done_outlined
                  : Icons.cloud_off_outlined,
              color: sync.error == null ? scheme.primary : scheme.error,
            ),
            title: const Text('Respaldo en la nube'),
            subtitle: Text(_syncLabel(sync)),
            onTap: sync.syncing ? null : () => sync.syncNow(),
          ),
          if (auth.isAdmin)
            ListTile(
              leading: Icon(Icons.admin_panel_settings_outlined,
                  color: scheme.tertiary),
              title: const Text('Panel de administración'),
              subtitle: const Text('Usuarios, negocios e inventarios'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdminScreen()),
              ),
            ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Cerrar sesión'),
            onTap: () => _signOut(context),
          ),
          const _Header('Negocio'),
          ListTile(
            leading: const Icon(Icons.storefront_outlined),
            title: const Text('Nombre del negocio'),
            subtitle: Text(inv.businessName),
            onTap: () => _editBusinessName(context),
          ),
          const _Header('Suscripción'),
          ListTile(
            leading: const Icon(Icons.workspace_premium_outlined),
            title: Text('${AppConstants.appName} Pro'),
            subtitle: Text(subStatus),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PaywallScreen()),
            ),
          ),
          const _Header('Datos'),
          ListTile(
            leading: const Icon(Icons.table_view_outlined),
            title: const Text('Copiar inventario (CSV)'),
            subtitle: const Text('Para pegar en Excel o Google Sheets'),
            onTap: () async {
              await Clipboard.setData(
                  ClipboardData(text: inv.exportProductsCsv()));
              if (context.mounted) showMessage(context, 'Inventario copiado');
            },
          ),
          ListTile(
            leading: const Icon(Icons.auto_awesome_outlined),
            title: const Text('Cargar productos de ejemplo'),
            subtitle: const Text('Útil para probar la app'),
            onTap: () async {
              await inv.loadDemoData();
              if (context.mounted) showMessage(context, 'Productos de ejemplo agregados');
            },
          ),
          ListTile(
            leading: Icon(Icons.delete_forever_outlined, color: scheme.error),
            title: Text('Borrar todos los datos',
                style: TextStyle(color: scheme.error)),
            onTap: () => _deleteAll(context),
          ),
          const _Header('Acerca de'),
          ListTile(
            leading: const AppLogo(size: 40),
            title: Text('${AppConstants.appName} ${AppConstants.appVersion}'),
            subtitle: const Text(AppConstants.tagline),
          ),
          ListTile(
            leading: const CompanyLogo(size: 40),
            title: const Text('Desarrollado por ${AppConstants.company}'),
            subtitle: const Text(AppConstants.companyLocation),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
