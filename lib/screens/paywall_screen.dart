import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/i18n.dart';
import '../services/auth_service.dart';
import '../services/subscription_service.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../widgets/app_logo.dart';

/// Pantalla de suscripción: planes mensual, semestral y anual con Mercado Pago.
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  static const Color _mercadoPagoBlue = Color(0xFF009EE3);

  // Textos en español; se traducen al mostrarlos.
  static const _features = [
    (Icons.qr_code_scanner, 'Productos ilimitados con escáner de código de barras'),
    (Icons.point_of_sale, 'Punto de venta con cálculo de vuelto'),
    (Icons.notifications_active_outlined, 'Alertas de stock bajo'),
    (Icons.bar_chart, 'Reportes de ventas, ganancias y más vendidos'),
    (Icons.table_view_outlined, 'Exporta tus datos a Excel'),
  ];

  late final TextEditingController _email = TextEditingController(
    text: context.read<SubscriptionService>().payerEmail.isNotEmpty
        ? context.read<SubscriptionService>().payerEmail
        : context.read<AuthService>().email,
  );

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sub = context.watch<SubscriptionService>();
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final String status;
    if (sub.isSubscribed) {
      status = tr('Tu suscripción está activa. Gracias por confiar en {app}.',
          {'app': AppConstants.appName});
    } else if (sub.inTrial) {
      status = sub.trialDaysLeft == 1
          ? tr('Te queda 1 día de prueba gratis.')
          : tr('Te quedan {n} días de prueba gratis.', {'n': sub.trialDaysLeft});
    } else {
      status =
          tr('Tu prueba gratis terminó. Suscríbete para seguir vendiendo y controlando tu stock. Tus datos siguen guardados.');
    }

    final String renewal = switch (sub.plan) {
          PremiumPlan.anual => tr(
              'Pagas una vez al año y se renueva solo. Cancela cuando quieras desde tu cuenta de Mercado Pago.'),
          PremiumPlan.semestral => tr(
              'Pagas cada 6 meses y se renueva solo. Cancela cuando quieras desde tu cuenta de Mercado Pago.'),
          PremiumPlan.mensual => tr(
              'Cobro automático cada mes con Mercado Pago. Cancela cuando quieras desde tu cuenta de Mercado Pago.'),
        };
    final planInfo = Money.currency == AppCurrency.clp
        ? renewal
        : '$renewal\n${tr('Los planes se cobran en pesos chilenos (CLP).')}';

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          children: [
            const Center(child: AppLogo(size: 84)),
            const SizedBox(height: 12),
            Text(
              '${AppConstants.appName} Pro',
              textAlign: TextAlign.center,
              style: text.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(status, textAlign: TextAlign.center, style: text.bodyLarge),
            const SizedBox(height: 24),
            for (final (icon, label) in _features)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon,
                          size: 20, color: scheme.onPrimaryContainer),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Text(tr(label), style: text.bodyLarge)),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            for (final plan in PremiumPlan.values) ...[
              _PlanCard(
                plan: plan,
                selected: sub.plan == plan,
                enabled: !sub.isSubscribed && !sub.loading,
                onTap: () => sub.selectPlan(plan),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              planInfo,
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            if (sub.isSubscribed)
              FilledButton.icon(
                onPressed: null,
                icon: const Icon(Icons.check_circle),
                label: Text(tr('Suscripción activa')),
              )
            else ...[
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                enabled: !sub.loading,
                decoration: InputDecoration(
                  labelText: tr('Correo de tu cuenta de Mercado Pago'),
                  hintText: 'nombre@correo.cl',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _mercadoPagoBlue,
                  foregroundColor: Colors.white,
                ),
                onPressed: sub.loading
                    ? null
                    : () => sub.subscribe(_email.text, sub.plan),
                icon: sub.loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.lock_outline),
                label: Text(tr('Pagar {price} con Mercado Pago',
                    {'price': formatCLP(sub.plan.price)})),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: sub.loading ? null : () => sub.checkPayment(),
                child: Text(tr('Ya pagué: revisar mi pago')),
              ),
            ],
            if (sub.info != null) ...[
              const SizedBox(height: 8),
              Text(
                sub.info!,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.primary),
              ),
            ],
            if (sub.error != null) ...[
              const SizedBox(height: 8),
              Text(
                sub.error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.error),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.verified_user_outlined,
                    size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    tr('Pago seguro procesado por Mercado Pago'),
                    style: text.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            const Center(child: MadeByRivera()),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta seleccionable de un plan.
class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final PremiumPlan plan;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final best = plan == PremiumPlan.anual;
    final discounted = plan.months > 1;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: selected
              ? scheme.primaryContainer.withValues(alpha: 0.45)
              : scheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: enabled ? onTap : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 16, 14),
              child: Row(
                children: [
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: selected ? scheme.primary : scheme.outline,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr(plan.title), style: text.titleMedium),
                        Text(
                          discounted
                              ? tr('Equivale a {price} al mes',
                                  {'price': formatCLP(plan.monthlyEquivalent)})
                              : tr(plan.note),
                          style: text.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(formatCLP(plan.price), style: text.titleLarge),
                      Text(
                        tr(plan.period),
                        style: text.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        if (discounted)
          Positioned(
            top: -10,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: best ? scheme.tertiary : scheme.secondary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                tr(plan.note),
                style: TextStyle(
                  color: best ? scheme.onTertiary : scheme.onSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
