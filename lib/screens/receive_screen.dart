import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/i18n.dart';
import '../models/product.dart';
import '../services/inventory_service.dart';
import '../utils/access_guard.dart';
import '../utils/formatters.dart';
import '../utils/platform.dart';
import '../widgets/price_calculator.dart';
import 'product_form_screen.dart';
import 'scanner_screen.dart';

/// Recibir mercadería: se escanea cada producto que llega (con la pistola,
/// la cámara o escribiendo el código) y al final se guarda todo junto.
/// Los productos que ya existen suman stock; los nuevos se crean una sola vez
/// con su precio, y desde ahí basta con escanearlos.
class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  final _code = TextEditingController();
  final _focus = FocusNode();

  /// Líneas en el orden en que se escanearon (la última arriba).
  final List<ReceiveLine> _lines = [];
  bool _saving = false;

  /// En el celular: después de cada lectura se vuelve a abrir la cámara.
  bool _continuous = true;

  @override
  void dispose() {
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _refocus() {
    if (!mounted) return;
    _code.clear();
    // En el PC el cuadro queda listo para la siguiente lectura de la pistola.
    // En el celular no, para que no se abra el teclado a cada rato.
    if (!AppPlatform.hasCameraScanner || _focus.hasFocus) {
      _focus.requestFocus();
    }
  }

  ReceiveLine? _lineFor(String productId) {
    for (final l in _lines) {
      if (l.productId == productId) return l;
    }
    return null;
  }

  /// Procesa un código leído. Devuelve true si se sumó a la lista.
  Future<bool> _handleCode(String raw) async {
    final code = raw.trim();
    if (code.isEmpty) return false;
    final inv = context.read<InventoryService>();
    final product = inv.findByBarcode(code);
    if (product != null) {
      setState(() {
        final line = _lineFor(product.id) ?? ReceiveLine(productId: product.id);
        _lines.remove(line);
        line.quantity += 1;
        _lines.insert(0, line);
      });
      HapticFeedback.lightImpact();
      SystemSound.play(SystemSoundType.click);
      return true;
    }

    // Producto nuevo: se crea una sola vez con nombre y precio.
    SystemSound.play(SystemSoundType.alert);
    final create = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.fiber_new_outlined),
        title: Text(tr('Producto nuevo')),
        content: Text(tr(
            'El código {code} no está en tus productos. Créalo una vez con su nombre y precio; la próxima vez solo lo escaneas.',
            {'code': code})),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(tr('Saltar')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(tr('Crear producto')),
          ),
        ],
      ),
    );
    if (create != true || !mounted) return false;
    await Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => ProductFormScreen(initialBarcode: code)),
    );
    if (!mounted) return false;
    final created = context.read<InventoryService>().findByBarcode(code);
    if (created != null) {
      showMessage(
          context,
          tr('{name} creado con stock {qty}. Si llegan más, sigue escaneando.',
              {'name': created.name, 'qty': formatQty(created.stock)}));
    }
    return false;
  }

  Future<void> _onSubmitted(String value) async {
    await _handleCode(value);
    _refocus();
  }

  Future<void> _scanCamera() async {
    while (mounted) {
      final code = await scanBarcode(context);
      if (code == null || !mounted) break;
      final added = await _handleCode(code);
      if (!_continuous || !added) break;
    }
  }

  Future<void> _editQuantity(ReceiveLine line, Product product) async {
    final c = TextEditingController(text: formatQty(line.quantity));
    final value = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(product.name),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: tr('Cantidad que llegó ({unit})',
                {'unit': unitLabel(product.unit)}),
          ),
          onSubmitted: (v) => Navigator.of(dialogContext).pop(parseQty(v)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(tr('Cancelar')),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(parseQty(c.text)),
            child: Text(tr('Aceptar')),
          ),
        ],
      ),
    );
    c.dispose();
    if (value == null || !mounted) return;
    setState(() {
      if (value <= 0) {
        _lines.remove(line);
      } else {
        line.quantity = value;
      }
    });
    _refocus();
  }

  Future<void> _editPrices(ReceiveLine line, Product product) async {
    final cost =
        TextEditingController(text: moneyInput(line.costPrice ?? product.costPrice));
    final price = TextEditingController(
        text: moneyInput(line.salePrice ?? product.salePrice));
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(product.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(tr('Si el proveedor cambió el precio, actualízalo aquí.')),
              const SizedBox(height: 14),
              TextField(
                controller: cost,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: tr('Costo por unidad')),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: price,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: tr('Precio de venta'),
                  suffixIcon: IconButton(
                    tooltip: tr('Calculadora de precios'),
                    icon: const Icon(Icons.calculate_outlined),
                    onPressed: () async {
                      final v = await showPriceCalculator(context,
                          initialCost: parseMoney(cost.text));
                      if (v != null) setLocal(() => price.text = moneyInput(v));
                    },
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(tr('Cancelar')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(tr('Aceptar')),
            ),
          ],
        ),
      ),
    );
    if (ok == true && mounted) {
      final newCost = parseMoney(cost.text);
      final newPrice = parseMoney(price.text);
      setState(() {
        line.costPrice =
            newCost != null && newCost != product.costPrice ? newCost : null;
        line.salePrice = newPrice != null &&
                newPrice > 0 &&
                newPrice != product.salePrice
            ? newPrice
            : null;
      });
    }
    cost.dispose();
    price.dispose();
    _refocus();
  }

  Future<void> _save() async {
    if (_lines.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      final n =
          await context.read<InventoryService>().receiveGoods(List.of(_lines));
      if (!mounted) return;
      showMessage(context,
          tr('Ingreso guardado: {n} productos actualizados.', {'n': n}));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showMessage(context, '$e', error: true);
    }
  }

  Future<bool> _confirmExit() async {
    if (_lines.isEmpty) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('¿Salir sin guardar?')),
        content: Text(tr(
            'Escaneaste {n} productos. Si sales ahora no se suma nada al stock.',
            {'n': _lines.length})),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(tr('Seguir escaneando')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(tr('Salir sin guardar')),
          ),
        ],
      ),
    );
    return leave == true;
  }

  @override
  Widget build(BuildContext context) {
    final inv = context.watch<InventoryService>();
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final camera = AppPlatform.hasCameraScanner;

    var units = 0.0;
    var cost = 0;
    for (final l in _lines) {
      final p = inv.productById(l.productId);
      if (p == null) continue;
      units += l.quantity;
      cost += ((l.costPrice ?? p.costPrice) * l.quantity).round();
    }

    return PopScope(
      canPop: _lines.isEmpty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmExit()) {
          setState(_lines.clear);
          navigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(tr('Recibir mercadería'))),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              color: scheme.primaryContainer.withValues(alpha: 0.5),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    camera
                        ? tr('Escanea cada producto que llegó. Cada lectura suma 1; toca la cantidad para cambiarla.')
                        : tr('Pasa la pistola por cada producto que llegó. Cada lectura suma 1; haz clic en la cantidad para cambiarla.'),
                    style: text.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _code,
                          focusNode: _focus,
                          autofocus: !camera,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          onSubmitted: _onSubmitted,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.qr_code_2),
                            labelText: tr('Código de barras'),
                            hintText: camera
                                ? tr('Escribe el código o usa la cámara')
                                : tr('Listo para la pistola'),
                            filled: true,
                            fillColor: scheme.surface,
                          ),
                        ),
                      ),
                      if (camera) ...[
                        const SizedBox(width: 8),
                        IconButton.filled(
                          tooltip: tr('Escanear con la cámara'),
                          iconSize: 30,
                          onPressed: _scanCamera,
                          icon: const Icon(Icons.qr_code_scanner),
                        ),
                      ],
                    ],
                  ),
                  if (camera)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: _continuous,
                      onChanged: (v) => setState(() => _continuous = v),
                      title: Text(tr('Escanear seguido (la cámara se abre sola otra vez)')),
                    ),
                ],
              ),
            ),
            Expanded(
              child: _lines.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.move_to_inbox_outlined,
                                size: 64, color: scheme.primary),
                            const SizedBox(height: 12),
                            Text(tr('Aún no escaneas nada'),
                                style: text.titleMedium),
                            const SizedBox(height: 6),
                            Text(
                              tr('Lo que escanees aparece aquí. Cuando termines, toca Guardar ingreso y se suma todo al stock.'),
                              textAlign: TextAlign.center,
                              style: TextStyle(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                      itemCount: _lines.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final line = _lines[i];
                        final p = inv.productById(line.productId);
                        if (p == null) return const SizedBox.shrink();
                        return _LineCard(
                          product: p,
                          line: line,
                          onMinus: () => setState(() {
                            line.quantity -= 1;
                            if (line.quantity <= 0) _lines.remove(line);
                          }),
                          onPlus: () => setState(() => line.quantity += 1),
                          onQuantity: () => _editQuantity(line, p),
                          onPrices: () => _editPrices(line, p),
                          onRemove: () => setState(() => _lines.remove(line)),
                        );
                      },
                    ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            decoration: BoxDecoration(
              color: scheme.surface,
              border: Border(top: BorderSide(color: scheme.outlineVariant)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('{n} productos · {u} unidades',
                            {'n': _lines.length, 'u': formatQty(units)}),
                        style: text.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      Text(tr('Costo {amount}', {'amount': formatMoney(cost)}),
                          style: text.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
                  onPressed: _lines.isEmpty || _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save_alt),
                  label: Text(tr('Guardar ingreso')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard({
    required this.product,
    required this.line,
    required this.onMinus,
    required this.onPlus,
    required this.onQuantity,
    required this.onPrices,
    required this.onRemove,
  });

  final Product product;
  final ReceiveLine line;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onQuantity;
  final VoidCallback onPrices;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final small = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: scheme.onSurfaceVariant);
    final cost = line.costPrice ?? product.costPrice;
    final price = line.salePrice ?? product.salePrice;
    final changed = line.costPrice != null || line.salePrice != null;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    tr('Stock {from} → {to}', {
                      'from': formatQty(product.stock),
                      'to': formatQty(product.stock + line.quantity),
                    }),
                    style: small,
                  ),
                  InkWell(
                    onTap: onPrices,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            tr('Costo {cost} · Venta {price}', {
                              'cost': formatMoney(cost),
                              'price': formatMoney(price),
                            }),
                            style: small?.copyWith(
                              color: changed ? scheme.primary : null,
                              fontWeight: changed ? FontWeight.w700 : null,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.edit_outlined,
                              size: 14, color: scheme.primary),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: tr('Quitar uno'),
              onPressed: onMinus,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            InkWell(
              onTap: onQuantity,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                constraints: const BoxConstraints(minWidth: 56),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '+${formatQty(line.quantity)}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: tr('Sumar uno'),
              onPressed: onPlus,
              icon: const Icon(Icons.add_circle_outline),
            ),
            IconButton(
              tooltip: tr('Quitar de la lista'),
              onPressed: onRemove,
              icon: Icon(Icons.close, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
