import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/i18n.dart';
import '../models/product.dart';
import '../models/stock_movement.dart';
import '../services/inventory_service.dart';
import '../utils/access_guard.dart';
import '../utils/formatters.dart';
import '../widgets/empty_state.dart';
import '../widgets/product_tile.dart';
import '../widgets/stock_adjust_dialog.dart';
import 'product_form_screen.dart';
import 'scanner_screen.dart';

enum _ProductAction { edit, entry, exit, history, delete }

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _search = TextEditingController();
  bool _onlyLow = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openForm({Product? product, String? barcode}) async {
    if (!await ensureAccess(context)) return;
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ProductFormScreen(product: product, initialBarcode: barcode),
      ),
    );
  }

  Future<void> _scanSearch() async {
    final code = await scanBarcode(context);
    if (code == null || !mounted) return;
    final product = context.read<InventoryService>().findByBarcode(code);
    if (product != null) {
      await _showActions(product);
      return;
    }
    final create = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('Producto no encontrado')),
        content: Text(tr('No hay productos con el código {code}. ¿Quieres crearlo?',
                {'code': code})),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(tr('No')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(tr('Crear producto')),
          ),
        ],
      ),
    );
    if (create == true && mounted) await _openForm(barcode: code);
  }

  Future<void> _showActions(Product product) async {
    final action = await showModalBottomSheet<_ProductAction>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(product.name,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                  tr('Stock: {stock} · Precio: {price} · Margen: {margin}', {
                  'stock': '${formatQty(product.stock)} ${unitLabel(product.unit)}',
                  'price': formatMoney(product.salePrice),
                  'margin': formatPercent(product.marginPercent),
                })),
            ),
            const Divider(),
            _actionTile(sheetContext, Icons.edit_outlined, tr('Editar producto'),
                _ProductAction.edit),
            _actionTile(sheetContext, Icons.add_box_outlined,
                tr('Entrada de stock (compra)'), _ProductAction.entry),
            _actionTile(sheetContext, Icons.indeterminate_check_box_outlined,
                tr('Salida / merma'), _ProductAction.exit),
            _actionTile(sheetContext, Icons.history, tr('Historial de movimientos'),
                _ProductAction.history),
            _actionTile(sheetContext, Icons.delete_outline, tr('Eliminar'),
                _ProductAction.delete,
                destructive: true),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;

    switch (action) {
      case _ProductAction.edit:
        await _openForm(product: product);
      case _ProductAction.entry:
      case _ProductAction.exit:
        if (!await ensureAccess(context) || !mounted) return;
        final saved = await showStockAdjustDialog(
          context,
          product,
          action == _ProductAction.entry
              ? MovementType.entrada
              : MovementType.salida,
        );
        if (saved == true && mounted) showMessage(context, tr('Stock actualizado'));
      case _ProductAction.history:
        await _showHistory(product);
      case _ProductAction.delete:
        await _confirmDelete(product);
    }
  }

  Widget _actionTile(BuildContext sheetContext, IconData icon, String label,
      _ProductAction action,
      {bool destructive = false}) {
    final color = destructive ? Theme.of(context).colorScheme.error : null;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color)),
      onTap: () => Navigator.of(sheetContext).pop(action),
    );
  }

  Future<void> _showHistory(Product product) async {
    final movements =
        context.read<InventoryService>().movementsFor(product.id).take(50);
    final scheme = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, controller) => movements.isEmpty
            ? EmptyState(
                icon: Icons.history,
                title: tr('Sin movimientos'),
                message: tr('Aún no hay movimientos para este producto.'),
              )
            : ListView(
                controller: controller,
                children: [
                  ListTile(
                    title: Text(tr('Movimientos de {name}', {'name': product.name}),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  for (final m in movements)
                    ListTile(
                      leading: Icon(
                        m.quantity >= 0
                            ? Icons.arrow_downward
                            : Icons.arrow_upward,
                        color: m.quantity >= 0 ? scheme.primary : scheme.error,
                      ),
                      title: Text(
                          '${m.type.label}: ${m.quantity >= 0 ? '+' : ''}${formatQty(m.quantity)} ${unitLabel(product.unit)}'),
                      subtitle: Text([
                        formatDateTime(m.date),
                        if (m.note.isNotEmpty) m.note,
                      ].join(' · ')),
                    ),
                ],
              ),
      ),
    );
  }

  Future<void> _confirmDelete(Product product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('Eliminar producto')),
        content: Text(
            tr('¿Eliminar "{name}"? Las ventas anteriores se mantienen en los reportes.',
            {'name': product.name})),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(tr('Cancelar')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(tr('Eliminar')),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await context.read<InventoryService>().deleteProduct(product.id);
    if (mounted) showMessage(context, tr('Producto eliminado'));
  }

  @override
  Widget build(BuildContext context) {
    final inv = context.watch<InventoryService>();
    final query = _search.text;
    final items =
        inv.search(query).where((p) => !_onlyLow || p.isLowStock).toList();
    final lowCount = inv.lowStockProducts.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Productos ({n})', {'n': inv.products.length})),
        actions: [
          IconButton(
            tooltip: tr('Buscar con escáner'),
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _scanSearch,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: tr('Buscar por nombre, código o categoría'),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(_search.clear),
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilterChip(
                label: Text(tr('Solo stock bajo ({n})', {'n': lowCount})),
                selected: _onlyLow,
                onSelected: (v) => setState(() => _onlyLow = v),
              ),
            ),
          ),
          Expanded(
            child: inv.products.isEmpty
                ? EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: tr('Sin productos'),
                    message:
                        tr('Agrega tu primer producto o carga productos de ejemplo para probar la app.'),
                    action: OutlinedButton.icon(
                      onPressed: () =>
                          context.read<InventoryService>().loadDemoData(),
                      icon: const Icon(Icons.auto_awesome_outlined),
                      label: Text(tr('Cargar ejemplo')),
                    ),
                  )
                : items.isEmpty
                    ? EmptyState(
                        icon: Icons.search_off,
                        title: tr('Sin resultados'),
                        message: tr('Prueba con otra búsqueda o quita el filtro.'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 96),
                        itemCount: items.length,
                        itemBuilder: (_, i) => ProductTile(
                          product: items[i],
                          onTap: () => _showActions(items[i]),
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_product',
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: Text(tr('Producto')),
      ),
    );
  }
}
