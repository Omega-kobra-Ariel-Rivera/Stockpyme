import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/i18n.dart';
import '../services/inventory_service.dart';
import '../utils/access_guard.dart';
import '../utils/formatters.dart';
import '../widgets/sales_bar_chart.dart';
import '../widgets/stat_card.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _days = 7;

  Future<void> _copy(String csv, String what) async {
    await Clipboard.setData(ClipboardData(text: csv));
    if (!mounted) return;
    showMessage(context,
        tr('{what} copiado. Pégalo en Excel o Google Sheets (separador ";").',
            {'what': what}));
  }

  @override
  Widget build(BuildContext context) {
    final inv = context.watch<InventoryService>();
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final sales = inv.salesLastDays(_days);
    final total = sales.fold<int>(0, (sum, s) => sum + s.total);
    final profit = sales.fold<int>(0, (sum, s) => sum + s.profit);
    final average = sales.isEmpty ? 0 : (total / sales.length).round();
    final daily = inv.dailyTotals(_days);
    final top = inv.topProducts(_days);
    final byPayment = inv.totalsByPayment(_days);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Reportes')),
        actions: [
          PopupMenuButton<String>(
            tooltip: tr('Exportar'),
            icon: const Icon(Icons.ios_share),
            onSelected: (value) {
              if (value == 'sales') {
                _copy(inv.exportSalesCsv(_days), tr('Reporte de ventas'));
              } else {
                _copy(inv.exportProductsCsv(), tr('Inventario'));
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'sales',
                child: Text(tr('Copiar ventas de {n} días (CSV)', {'n': _days})),
              ),
              PopupMenuItem(
                value: 'products',
                child: Text(tr('Copiar inventario (CSV)')),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<int>(
            segments: [
              ButtonSegment(value: 1, label: Text(tr('Hoy'))),
              ButtonSegment(value: 7, label: Text(tr('7 días'))),
              ButtonSegment(value: 30, label: Text(tr('30 días'))),
            ],
            selected: {_days},
            onSelectionChanged: (s) => setState(() => _days = s.first),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.45,
            children: [
              StatCard(
                  icon: Icons.payments_outlined,
                  label: tr('Ventas'),
                  value: formatMoney(total)),
              StatCard(
                  icon: Icons.trending_up,
                  label: tr('Ganancia'),
                  value: formatMoney(profit)),
              StatCard(
                  icon: Icons.receipt_long_outlined,
                  label: tr('N° de ventas'),
                  value: '${sales.length}'),
              StatCard(
                  icon: Icons.shopping_basket_outlined,
                  label: tr('Ticket promedio'),
                  value: formatMoney(average)),
            ],
          ),
          if (_days > 1) ...[
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('Ventas por día'), style: text.titleMedium),
                    const SizedBox(height: 16),
                    SizedBox(height: 170, child: SalesBarChart(data: daily)),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Text(tr('Más vendidos'), style: text.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: top.isEmpty
                ? ListTile(title: Text(tr('Sin ventas en este periodo.')))
                : Column(
                    children: [
                      for (var i = 0; i < top.length; i++)
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor: i == 0
                                ? scheme.tertiaryContainer
                                : scheme.primaryContainer,
                            child: Text('${i + 1}'),
                          ),
                          title: Text(top[i].name,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(tr('{qty} vendidos',
                              {'qty': formatQty(top[i].quantity)})),
                          trailing: Text(formatMoney(top[i].total),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                    ],
                  ),
          ),
          if (byPayment.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(tr('Por medio de pago'), style: text.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  for (final entry in byPayment.entries)
                    ListTile(
                      dense: true,
                      title: Text(entry.key.label),
                      trailing: Text(formatMoney(entry.value),
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Text(tr('Detalle de ventas'), style: text.titleMedium),
          const SizedBox(height: 8),
          if (sales.isEmpty)
            Card(child: ListTile(title: Text(tr('Sin ventas en este periodo.'))))
          else
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final sale in sales.take(100))
                    ExpansionTile(
                      shape: const Border(),
                      title: Text(
                          '${tr('N°')} ${sale.number} · ${formatMoney(sale.total)}',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                          '${formatDateTime(sale.date)} · ${sale.paymentMethod.label}'),
                      children: [
                        for (final item in sale.items)
                          ListTile(
                            dense: true,
                            title: Text(item.name),
                            subtitle: Text(
                                '${formatQty(item.quantity)} × ${formatMoney(item.unitPrice)}'),
                            trailing: Text(formatMoney(item.subtotal)),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
