import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/i18n.dart';
import '../services/auth_service.dart';
import '../services/language_service.dart';
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
        title: Text(tr('Nombre del negocio')),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(hintText: tr('Ej: Almacén Don Pedro')),
          onSubmitted: (v) => Navigator.of(dialogContext).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(tr('Cancelar')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: Text(tr('Guardar')),
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
        title: Text(tr('Borrar todos los datos')),
        content: Text(
            tr('Se eliminarán productos, ventas y movimientos de este teléfono y de tu respaldo en la nube. Esta acción no se puede deshacer. Te recomendamos exportar antes.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(tr('Cancelar')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(tr('Borrar todo')),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    context.read<CartService>().clear();
    await context.read<InventoryService>().deleteAllData();
    if (context.mounted) showMessage(context, tr('Datos eliminados'));
  }

  Future<void> _signOut(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('Cerrar sesión')),
        content: Text(
            tr('Tus datos quedan guardados en este teléfono y en la nube. Podrás verlos otra vez al iniciar sesión.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(tr('Cancelar')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(tr('Cerrar sesión')),
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

  Future<void> _pickCurrency(BuildContext context) async {
    final inv = context.read<InventoryService>();
    final chosen = await showDialog<AppCurrency>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(tr('Moneda del negocio')),
        children: [
          for (final c in AppCurrency.values)
            ListTile(
              title: Text('${tr(c.label)} (${c.code})'),
              subtitle: Text(c.format(123456)),
              trailing: c == inv.currency ? const Icon(Icons.check) : null,
              onTap: () => Navigator.of(dialogContext).pop(c),
            ),
        ],
      ),
    );
    if (chosen == null || chosen == inv.currency || !context.mounted) return;

    // Si ya hay precios, avisa que no se convierten.
    if (inv.products.isNotEmpty || inv.sales.isNotEmpty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(tr('Cambiar moneda')),
          content: Text(tr(
              'Tus precios y ventas quedan con el mismo número en la moneda nueva (por ejemplo, {from} pasa a {to}). No se convierten con el tipo de cambio: revisa tus precios después.',
              {
                'from': inv.currency.format(1290 * inv.currency.factor),
                'to': chosen.format(1290 * chosen.factor),
              })),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(tr('Cancelar')),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(tr('Cambiar')),
            ),
          ],
        ),
      );
      if (ok != true || !context.mounted) return;
    }
    await inv.setCurrency(chosen);
    if (context.mounted) {
      showMessage(context, tr('Moneda cambiada a {name}', {'name': tr(chosen.label)}));
    }
  }

  Future<void> _pickLanguage(BuildContext context) async {
    final language = context.read<LanguageService>();
    final chosen = await showDialog<AppLanguage>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(tr('Idioma de la app')),
        children: [
          for (final l in AppLanguage.values)
            ListTile(
              title: Text(l.nativeName),
              trailing: l == language.language ? const Icon(Icons.check) : null,
              onTap: () => Navigator.of(dialogContext).pop(l),
            ),
        ],
      ),
    );
    if (chosen != null) await language.setLanguage(chosen);
  }

  String _syncLabel(CloudSyncService sync) {
    if (sync.syncing) return tr('Respaldando…');
    if (sync.error != null) return sync.error!;
    final last = sync.lastSync;
    if (last == null) return tr('Toca para respaldar ahora');
    return tr('Último respaldo: {date}', {'date': formatDateTime(last)});
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
      subStatus = tr('Activa hasta el {date}',
          {'date': formatDate(sub.manualProUntil!)});
    } else if (sub.isSubscribed) {
      subStatus = tr('Activa · {price}', {'price': sub.priceLabel});
    } else if (sub.inTrial) {
      subStatus = tr('Prueba gratis: {n} días restantes',
          {'n': sub.trialDaysLeft});
    } else {
      subStatus = tr('Prueba terminada');
    }

    return Scaffold(
      appBar: AppBar(title: Text(tr('Ajustes'))),
      body: ListView(
        children: [
          _Header(tr('Cuenta')),
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
            title: Text(tr('Respaldo en la nube')),
            subtitle: Text(_syncLabel(sync)),
            onTap: sync.syncing ? null : () => sync.syncNow(),
          ),
          if (auth.isAdmin)
            ListTile(
              leading: Icon(Icons.admin_panel_settings_outlined,
                  color: scheme.tertiary),
              title: Text(tr('Panel de administración')),
              subtitle: Text(tr('Usuarios, negocios e inventarios')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdminScreen()),
              ),
            ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(tr('Cerrar sesión')),
            onTap: () => _signOut(context),
          ),
          _Header(tr('Negocio')),
          ListTile(
            leading: const Icon(Icons.storefront_outlined),
            title: Text(tr('Nombre del negocio')),
            subtitle: Text(inv.businessLabel),
            onTap: () => _editBusinessName(context),
          ),
          ListTile(
            leading: const Icon(Icons.payments_outlined),
            title: Text(tr('Moneda')),
            subtitle: Text(
                '${tr(inv.currency.label)} (${inv.currency.code}) · ${formatMoney(123456)}'),
            onTap: () => _pickCurrency(context),
          ),
          _Header(tr('Idioma')),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(tr('Idioma de la app')),
            subtitle: Text(context.watch<LanguageService>().language.nativeName),
            onTap: () => _pickLanguage(context),
          ),
          _Header(tr('Suscripción')),
          ListTile(
            leading: const Icon(Icons.workspace_premium_outlined),
            title: Text('${AppConstants.appName} Pro'),
            subtitle: Text(subStatus),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PaywallScreen()),
            ),
          ),
          _Header(tr('Datos')),
          ListTile(
            leading: const Icon(Icons.table_view_outlined),
            title: Text(tr('Copiar inventario (CSV)')),
            subtitle: Text(tr('Para pegar en Excel o Google Sheets')),
            onTap: () async {
              await Clipboard.setData(
                  ClipboardData(text: inv.exportProductsCsv()));
              if (context.mounted) showMessage(context, tr('Inventario copiado'));
            },
          ),
          ListTile(
            leading: const Icon(Icons.auto_awesome_outlined),
            title: Text(tr('Cargar productos de ejemplo')),
            subtitle: Text(tr('Útil para probar la app')),
            onTap: () async {
              await inv.loadDemoData();
              if (context.mounted) showMessage(context, tr('Productos de ejemplo agregados'));
            },
          ),
          ListTile(
            leading: Icon(Icons.delete_forever_outlined, color: scheme.error),
            title: Text(tr('Borrar todos los datos'),
                style: TextStyle(color: scheme.error)),
            onTap: () => _deleteAll(context),
          ),
          _Header(tr('Acerca de')),
          ListTile(
            leading: const AppLogo(size: 40),
            title: Text('${AppConstants.appName} ${AppConstants.appVersion}'),
            subtitle: Text(tr(AppConstants.tagline)),
          ),
          ListTile(
            leading: const CompanyLogo(size: 40),
            title: Text(tr('Desarrollado por {company}',
                {'company': AppConstants.company})),
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
