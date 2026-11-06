import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/i18n.dart';
import '../services/inventory_service.dart';
import '../services/product_import.dart';
import '../utils/access_guard.dart';
import '../utils/formatters.dart';

/// Carga muchos productos de una vez copiándolos desde Excel o Google Sheets.
class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final _text = TextEditingController();
  List<ImportRow> _rows = [];
  bool _addStock = false;
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _parse() => setState(() => _rows = ProductImport.parse(_text.text));

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    if (!mounted) return;
    if (text.trim().isEmpty) {
      showMessage(context,
          tr('No hay nada copiado. Selecciona las filas en Excel y copia con Ctrl+C.'),
          error: true);
      return;
    }
    _text.text = text;
    _parse();
  }

  Future<void> _copyTemplate() async {
    await Clipboard.setData(ClipboardData(
        text: '${ProductImport.templateHeader}\n'
            '${tr('Arroz 1 kg')}\t7802900001234\t${tr('Abarrotes')}\t${tr('unidad')}\t990\t1290\t48\t10\n'));
    if (!mounted) return;
    showMessage(context,
        tr('Plantilla copiada. Pégala en la celda A1 de una hoja nueva de Excel.'));
  }

  Future<void> _import() async {
    if (!await ensureAccess(context)) return;
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      final r = await context
          .read<InventoryService>()
          .importProducts(_rows, addStock: _addStock);
      if (!mounted) return;
      showMessage(context,
          tr('Listo: {a} productos nuevos y {u} actualizados.',
              {'a': r.added, 'u': r.updated}));
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        showMessage(context, e is InventoryException ? e.message : '$e',
            error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final inv = context.watch<InventoryService>();
    final valid = _rows.where((r) => r.isValid).toList();
    final invalid = _rows.where((r) => !r.isValid).toList();
    var updates = 0;
    for (final r in valid) {
      final exists = (r.barcode.isNotEmpty && inv.findByBarcode(r.barcode) != null) ||
          inv.products.any((p) =>
              p.name.toLowerCase().trim() == r.name.toLowerCase().trim());
      if (exists) updates++;
    }

    return Scaffold(
      appBar: AppBar(title: Text(tr('Importar desde Excel'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('Cómo hacerlo'), style: text.titleMedium),
                      const SizedBox(height: 8),
                      for (final step in [
                        tr('1. En Excel, ordena las columnas: Nombre, Código, Categoría, Unidad, Costo, Precio, Stock y Stock mínimo. La primera fila puede llevar esos títulos.'),
                        tr('2. Selecciona las filas (con los títulos) y cópialas con Ctrl+C.'),
                        tr('3. Vuelve aquí y toca "Pegar desde Excel".'),
                        tr('Consejo: pon la columna Código en formato Texto para que Excel no cambie los números largos.'),
                      ])
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Text(step),
                        ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          FilledButton.icon(
                            onPressed: _paste,
                            icon: const Icon(Icons.content_paste),
                            label: Text(tr('Pegar desde Excel')),
                          ),
                          OutlinedButton.icon(
                            onPressed: _copyTemplate,
                            icon: const Icon(Icons.table_chart_outlined),
                            label: Text(tr('Copiar plantilla')),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _text,
                minLines: 4,
                maxLines: 8,
                onChanged: (_) => _parse(),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                decoration: InputDecoration(
                  labelText: tr('O pega o escribe aquí las filas'),
                  alignLabelWithHint: true,
                ),
              ),
              if (_rows.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      avatar: const Icon(Icons.add_circle_outline, size: 18),
                      label: Text(tr('{n} nuevos', {'n': valid.length - updates})),
                    ),
                    Chip(
                      avatar: const Icon(Icons.sync, size: 18),
                      label: Text(tr('{n} se actualizan', {'n': updates})),
                    ),
                    if (invalid.isNotEmpty)
                      Chip(
                        avatar: Icon(Icons.error_outline,
                            size: 18, color: scheme.error),
                        label: Text(tr('{n} con errores', {'n': invalid.length})),
                      ),
                  ],
                ),
                if (updates > 0)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _addStock,
                    onChanged: (v) => setState(() => _addStock = v),
                    title: Text(tr('Sumar el stock al que ya tengo')),
                    subtitle: Text(_addStock
                        ? tr('Ej.: tenías 10 y la planilla dice 5 → quedan 15')
                        : tr('Ej.: tenías 10 y la planilla dice 5 → quedan 5')),
                  ),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      for (final r in _rows.take(50))
                        ListTile(
                          dense: true,
                          leading: Icon(
                            r.isValid ? Icons.check_circle : Icons.error,
                            color: r.isValid ? const Color(0xFF15803D) : scheme.error,
                          ),
                          title: Text(r.name.isEmpty ? '—' : r.name,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(r.isValid
                              ? [
                                  if (r.barcode.isNotEmpty) r.barcode,
                                  if (r.salePrice != null) formatMoney(r.salePrice!),
                                  if (r.stock != null)
                                    '${tr('Stock')} ${formatQty(r.stock!)} ${unitLabel(r.unit)}',
                                ].join(' · ')
                              : tr('Fila {n}: {error}',
                                  {'n': r.line, 'error': r.error ?? ''})),
                        ),
                      if (_rows.length > 50)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(tr('y {n} más', {'n': _rows.length - 50})),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _rows.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                  onPressed: valid.isEmpty || _busy ? null : _import,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.download_done),
                  label: Text(tr('Importar {n} productos', {'n': valid.length})),
                ),
              ),
            ),
    );
  }
}
