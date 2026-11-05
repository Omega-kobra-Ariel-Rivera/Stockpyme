import 'package:flutter/material.dart';

import '../l10n/i18n.dart';
import '../utils/formatters.dart';

/// Abre la calculadora de precios. Devuelve el precio elegido (en la moneda
/// del negocio) o null si se cierra sin usarlo.
///
/// [initialCost] llena el costo; [showUseButton] muestra "Usar este precio".
Future<int?> showPriceCalculator(
  BuildContext context, {
  int? initialCost,
  bool showUseButton = true,
}) {
  return showDialog<int>(
    context: context,
    builder: (_) => _PriceCalculatorDialog(
      initialCost: initialCost,
      showUseButton: showUseButton,
    ),
  );
}

enum _MarginMode { onPrice, onCost }

class _PriceCalculatorDialog extends StatefulWidget {
  const _PriceCalculatorDialog({this.initialCost, required this.showUseButton});

  final int? initialCost;
  final bool showUseButton;

  @override
  State<_PriceCalculatorDialog> createState() => _PriceCalculatorDialogState();
}

class _PriceCalculatorDialogState extends State<_PriceCalculatorDialog> {
  late final TextEditingController _cost;
  final _percent = TextEditingController(text: '30');
  final _tax = TextEditingController(text: '0');
  final _qty = TextEditingController(text: '1');
  _MarginMode _mode = _MarginMode.onPrice;
  bool _round = true;

  @override
  void initState() {
    super.initState();
    final c = widget.initialCost ?? 0;
    _cost = TextEditingController(text: c > 0 ? moneyInput(c) : '');
  }

  @override
  void dispose() {
    _cost.dispose();
    _percent.dispose();
    _tax.dispose();
    _qty.dispose();
    super.dispose();
  }

  double _num(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0;

  /// Costo de una unidad. Si se compra un paquete, costo / cantidad.
  int get _unitCost {
    final total = parseMoney(_cost.text) ?? 0;
    final qty = _num(_qty);
    return qty > 1 ? (total / qty).round() : total;
  }

  int get _price {
    final cost = _unitCost;
    final pct = _num(_percent);
    double net;
    if (_mode == _MarginMode.onPrice) {
      // Margen sobre el precio de venta (como en la ficha del producto).
      net = pct >= 100 ? 0 : cost / (1 - pct / 100);
    } else {
      // Recargo sobre el costo.
      net = cost * (1 + pct / 100);
    }
    var price = net * (1 + _num(_tax) / 100);
    if (_round && price > 0) {
      // Redondea hacia arriba a 10 unidades mínimas ($10 en pesos chilenos).
      price = (price / 10).ceil() * 10.0;
    }
    return price.round();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final cost = _unitCost;
    final price = _price;
    final taxPct = _num(_tax);
    final net = taxPct > 0 ? (price / (1 + taxPct / 100)).round() : price;
    final profit = net - cost;
    final marginOnPrice = net == 0 ? 0.0 : profit / net * 100;
    final markup = cost == 0 ? 0.0 : profit / cost * 100;
    final pctInvalid = _mode == _MarginMode.onPrice && _num(_percent) >= 100;

    InputDecoration deco(String label, {String? suffix, String? helper}) =>
        InputDecoration(
          labelText: label,
          suffixText: suffix,
          helperText: helper,
          isDense: true,
        );

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
      title: Row(
        children: [
          Icon(Icons.calculate_outlined, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(tr('Calculadora de precios'))),
          IconButton(
            tooltip: tr('Cerrar'),
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _cost,
                      autofocus: widget.initialCost == null,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      decoration: deco(tr('Costo de compra'),
                          helper: tr('Lo que pagaste')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _qty,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      decoration: deco(tr('Unidades'),
                          helper: tr('Si es un pack')),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SegmentedButton<_MarginMode>(
                segments: [
                  ButtonSegment(
                      value: _MarginMode.onPrice,
                      label: Text(tr('Sobre la venta'))),
                  ButtonSegment(
                      value: _MarginMode.onCost,
                      label: Text(tr('Sobre el costo'))),
                ],
                selected: {_mode},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _mode = s.first),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _percent,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      decoration: deco(tr('Ganancia'), suffix: '%').copyWith(
                        errorText: pctInvalid ? tr('Debe ser menor a 100%') : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _tax,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      decoration: deco(tr('Impuesto (IVA)'), suffix: '%'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final p in [15, 20, 25, 30, 40, 50])
                    ActionChip(
                      label: Text('$p%'),
                      onPressed: () =>
                          setState(() => _percent.text = '$p'),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.receipt_long_outlined, size: 16),
                    label: Text(tr('IVA 19%')),
                    onPressed: () => setState(() => _tax.text = '19'),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: _round,
                onChanged: (v) => setState(() => _round = v),
                title: Text(tr('Redondear el precio hacia arriba')),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('Precio de venta sugerido'),
                        style: text.labelLarge
                            ?.copyWith(color: scheme.onPrimaryContainer)),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        formatMoney(price),
                        style: text.headlineMedium?.copyWith(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _ResultRow(tr('Costo por unidad'), formatMoney(cost)),
                    if (taxPct > 0)
                      _ResultRow(tr('Precio sin impuesto'), formatMoney(net)),
                    _ResultRow(tr('Ganancia por unidad'), formatMoney(profit),
                        bold: true),
                    _ResultRow(tr('Margen sobre la venta'),
                        formatPercent(marginOnPrice)),
                    _ResultRow(
                        tr('Recargo sobre el costo'), formatPercent(markup)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.showUseButton)
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: price > 0 && !pctInvalid
                ? () => Navigator.pop(context, price)
                : null,
            icon: const Icon(Icons.check),
            label: Text(tr('Usar este precio')),
          )
        else
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('Listo')),
          ),
      ],
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow(this.label, this.value, {this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onPrimaryContainer;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: TextStyle(color: color.withValues(alpha: 0.8)))),
          Text(value,
              style: TextStyle(
                color: color,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              )),
        ],
      ),
    );
  }
}
