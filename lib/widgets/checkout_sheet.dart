import 'package:flutter/material.dart';

import '../l10n/i18n.dart';
import '../models/sale.dart';
import '../utils/formatters.dart';

class CheckoutResult {
  const CheckoutResult({required this.method, this.cashReceived});

  final PaymentMethod method;
  final int? cashReceived;
}

/// Hoja de cobro: medio de pago y cálculo de vuelto.
Future<CheckoutResult?> showCheckoutSheet(BuildContext context, int total) {
  return showModalBottomSheet<CheckoutResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _CheckoutSheet(total: total),
  );
}

class _CheckoutSheet extends StatefulWidget {
  const _CheckoutSheet({required this.total});

  final int total;

  @override
  State<_CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<_CheckoutSheet> {
  PaymentMethod _method = PaymentMethod.efectivo;
  final _cash = TextEditingController();

  int? get _cashValue => parseMoney(_cash.text);

  @override
  void dispose() {
    _cash.dispose();
    super.dispose();
  }

  /// Montos rápidos: exacto y billetes de la moneda que cubran el total.
  List<int> get _quickAmounts {
    final bills = Money.currency.quickBills;
    final amounts = <int>{widget.total};
    for (final bill in bills) {
      final rounded = ((widget.total + bill - 1) ~/ bill) * bill;
      if (rounded >= widget.total) amounts.add(rounded);
    }
    final list = amounts.toList()..sort();
    return list.take(4).toList();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final cash = _cashValue;
    final change = cash == null ? null : cash - widget.total;
    final cashInvalid =
        _method == PaymentMethod.efectivo && cash != null && cash < widget.total;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tr('Total a cobrar'),
                style: text.bodyMedium, textAlign: TextAlign.center),
            Text(
              formatMoney(widget.total),
              textAlign: TextAlign.center,
              style: text.displaySmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 20),
            Text(tr('Medio de pago'), style: text.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final method in PaymentMethod.values)
                  ChoiceChip(
                    label: Text(method.label),
                    selected: _method == method,
                    onSelected: (_) => setState(() => _method = method),
                  ),
              ],
            ),
            if (_method == PaymentMethod.efectivo) ...[
              const SizedBox(height: 20),
              TextField(
                controller: _cash,
                keyboardType: Money.currency.decimals > 0
                    ? const TextInputType.numberWithOptions(decimal: true)
                    : TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: tr('Paga con'),
                  prefixText: '${Money.currency.symbol.trim()} ',
                  errorText: cashInvalid ? tr('El monto es menor al total') : null,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final amount in _quickAmounts)
                    ActionChip(
                      label: Text(amount == widget.total
                          ? tr('Exacto')
                          : formatMoney(amount)),
                      onPressed: () => setState(
                          () => _cash.text = moneyInput(amount)),
                    ),
                ],
              ),
              if (change != null && change >= 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(tr('Vuelto'),
                          style: text.titleMedium
                              ?.copyWith(color: scheme.onPrimaryContainer)),
                      Text(
                        formatMoney(change),
                        style: text.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: cashInvalid
                  ? null
                  : () => Navigator.of(context).pop(
                        CheckoutResult(
                          method: _method,
                          cashReceived:
                              _method == PaymentMethod.efectivo ? cash : null,
                        ),
                      ),
              icon: const Icon(Icons.check_circle_outline),
              label: Text(tr('Confirmar venta')),
            ),
          ],
        ),
      ),
    );
  }
}
