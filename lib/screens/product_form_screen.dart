import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/i18n.dart';
import '../models/product.dart';
import '../services/inventory_service.dart';
import '../utils/access_guard.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../utils/id_generator.dart';
import 'scanner_screen.dart';

/// Crear o editar un producto.
class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, this.product, this.initialBarcode});

  final Product? product;
  final String? initialBarcode;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _barcode;
  late final TextEditingController _category;
  late final TextEditingController _cost;
  late final TextEditingController _price;
  late final TextEditingController _stock;
  late final TextEditingController _minStock;
  late String _unit;

  static TextInputType get _moneyKeyboard => Money.currency.decimals > 0
      ? const TextInputType.numberWithOptions(decimal: true)
      : TextInputType.number;

  static String get _moneyPrefix => '${Money.currency.symbol.trim()} ';
  bool _saving = false;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _name = TextEditingController(text: p?.name ?? '');
    _barcode =
        TextEditingController(text: p?.barcode ?? widget.initialBarcode ?? '');
    _category = TextEditingController(text: p?.category ?? '');
    _cost = TextEditingController(text: p == null ? '' : moneyInput(p.costPrice));
    _price =
        TextEditingController(text: p == null ? '' : moneyInput(p.salePrice));
    _stock = TextEditingController(text: p == null ? '' : formatQty(p.stock));
    _minStock =
        TextEditingController(text: p == null ? '' : formatQty(p.minStock));
    _unit = p?.unit ?? AppConstants.units.first;
    if (!AppConstants.units.contains(_unit)) _unit = AppConstants.units.first;
  }

  @override
  void dispose() {
    for (final c in [_name, _barcode, _category, _cost, _price, _stock, _minStock]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _scan() async {
    final code = await scanBarcode(context);
    if (code != null && mounted) setState(() => _barcode.text = code);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final inv = context.read<InventoryService>();
    final product = Product(
      id: widget.product?.id ?? newId(),
      name: _name.text.trim(),
      barcode: _barcode.text.trim(),
      category: _category.text.trim(),
      unit: _unit,
      costPrice: parseMoney(_cost.text) ?? 0,
      salePrice: parseMoney(_price.text) ?? 0,
      stock: parseQty(_stock.text) ?? 0,
      minStock: parseQty(_minStock.text) ?? 0,
    );
    try {
      if (_isEditing) {
        await inv.updateProduct(product);
      } else {
        await inv.addProduct(product);
      }
      if (!mounted) return;
      showMessage(context, _isEditing ? tr('Producto actualizado') : tr('Producto creado'));
      Navigator.of(context).pop();
    } on InventoryException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showMessage(context, e.message, error: true);
    }
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? tr('Campo obligatorio') : null;

  String? _validQty(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final q = parseQty(v);
    return (q == null || q < 0) ? tr('Número no válido') : null;
  }

  @override
  Widget build(BuildContext context) {
    final inv = context.watch<InventoryService>();
    final scheme = Theme.of(context).colorScheme;
    final cost = parseMoney(_cost.text) ?? 0;
    final price = parseMoney(_price.text) ?? 0;
    final margin = price - cost;
    final marginPct = price == 0 ? 0.0 : margin / price * 100;
    final categories = inv.categories;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? tr('Editar producto') : tr('Nuevo producto')),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: tr('Nombre *')),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _barcode,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: tr('Código de barras'),
                suffixIcon: IconButton(
                  tooltip: tr('Escanear'),
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: _scan,
                ),
              ),
              validator: (v) =>
                  inv.isBarcodeTaken(v ?? '', exceptId: widget.product?.id)
                      ? tr('Este código ya está en uso')
                      : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _category,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                  labelText: tr('Categoría'), hintText: tr('Ej: Bebidas, Abarrotes')),
            ),
            if (categories.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final c in categories)
                    ActionChip(
                      label: Text(c),
                      onPressed: () => setState(() => _category.text = c),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _unit,
              decoration: InputDecoration(labelText: tr('Unidad de venta')),
              items: [
                for (final u in AppConstants.units)
                  DropdownMenuItem(value: u, child: Text(unitLabel(u))),
              ],
              onChanged: (v) => setState(() => _unit = v ?? _unit),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cost,
                    keyboardType: _moneyKeyboard,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                        labelText: tr('Costo'), prefixText: _moneyPrefix),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _price,
                    keyboardType: _moneyKeyboard,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                        labelText: tr('Precio venta *'),
                        prefixText: _moneyPrefix),
                    validator: (v) => (parseMoney(v ?? '') ?? 0) <= 0
                        ? tr('Ingresa un precio')
                        : null,
                  ),
                ),
              ],
            ),
            if (price > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4),
                child: Text(
                  tr('Ganancia por {unit}: {amount} ({pct})', {
                    'unit': unitLabel(_unit),
                    'amount': formatMoney(margin),
                    'pct': formatPercent(marginPct),
                  }),
                  style: TextStyle(
                    color: margin < 0 ? scheme.error : scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _stock,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                        labelText: _isEditing ? tr('Stock actual') : tr('Stock inicial')),
                    validator: _validQty,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _minStock,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        InputDecoration(labelText: tr('Stock mínimo')),
                    validator: _validQty,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4),
              child: Text(
                tr('Te avisaremos cuando el stock llegue al mínimo.'),
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
              ),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_isEditing ? tr('Guardar cambios') : tr('Crear producto')),
            ),
          ],
        ),
      ),
    );
  }
}
