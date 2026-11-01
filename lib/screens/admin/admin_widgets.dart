import 'package:flutter/material.dart';

import '../../l10n/i18n.dart';
import '../../models/admin_user.dart';

/// Etiqueta de color con el plan de un usuario.
class PlanBadge extends StatelessWidget {
  const PlanBadge({super.key, required this.plan, this.trialDaysLeft = 0});

  final AdminPlan plan;
  final int trialDaysLeft;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (Color bg, Color fg, String label) = switch (plan) {
      AdminPlan.proMercadoPago => (
          scheme.primaryContainer,
          scheme.onPrimaryContainer,
          tr('Pro')
        ),
      AdminPlan.proManual => (
          scheme.secondaryContainer,
          scheme.onSecondaryContainer,
          tr('Pro manual')
        ),
      AdminPlan.trial => (
          scheme.tertiaryContainer,
          scheme.onTertiaryContainer,
          tr('Prueba · {n}d', {'n': trialDaysLeft})
        ),
      AdminPlan.expired => (
          scheme.errorContainer,
          scheme.onErrorContainer,
          tr('Vencida')
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Tarjeta pequeña de número + etiqueta para el resumen del panel.
class AdminMetric extends StatelessWidget {
  const AdminMetric({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (color ?? scheme.primary).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: color ?? scheme.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(value, style: text.titleLarge),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mensaje cuando Firestore niega el acceso o falla la conexión.
class AdminErrorView extends StatelessWidget {
  const AdminErrorView({super.key, required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    final text = error.toString();
    final denied = text.contains('permission-denied');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(denied ? Icons.lock_outline : Icons.cloud_off_outlined,
                size: 48),
            const SizedBox(height: 12),
            Text(
              denied
                  ? tr('Tu correo no tiene permiso de administrador. Revisa la colección "admins" y las reglas de Firestore (ver README).')
                  : tr('No se pudieron cargar los datos. Revisa tu conexión.'),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
