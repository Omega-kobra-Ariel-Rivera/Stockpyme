import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/i18n.dart';
import '../services/inventory_service.dart';
import '../services/report_service.dart';
import '../utils/access_guard.dart';
import '../utils/formatters.dart';
import '../widgets/price_calculator.dart';
import '../widgets/report_charts.dart';
import '../widgets/stat_card.dart';

/// Periodos rápidos de los reportes.
enum _Preset { today, week, month30, thisMonth, custom }

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  _Preset _preset = _Preset.week;
  DateTimeRange? _custom;

  ReportRange get _range {
    switch (_preset) {
      case _Preset.today:
        return ReportRange.lastDays(1);
      case _Preset.week:
        return ReportRange.lastDays(7);
      case _Preset.month30:
        return ReportRange.lastDays(30);
      case _Preset.thisMonth:
        return ReportRange.thisMonth();
      case _Preset.custom:
        final c = _custom;
        return c == null
            ? ReportRange.lastDays(7)
            : ReportRange.days(c.start, c.end);
    }
  }

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: _custom ??
          DateTimeRange(
              start: DateTime(now.year, now.month, now.day - 6), end: now),
      helpText: tr('Elige las fechas del reporte'),
      saveText: tr('Aplicar'),
    );
    if (picked == null) return;
    setState(() {
      _custom = picked;
      _preset = _Preset.custom;
    });
  }

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
    final report = ReportService(inv, _range);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr('Reportes')),
          actions: [
            IconButton(
              tooltip: tr('Calculadora de precios'),
              icon: const Icon(Icons.calculate_outlined),
              onPressed: () =>
                  showPriceCalculator(context, showUseButton: false),
            ),
            PopupMenuButton<String>(
              tooltip: tr('Exportar'),
              icon: const Icon(Icons.ios_share),
              onSelected: (value) {
                switch (value) {
                  case 'summary':
                    _copy(report.exportSummaryCsv(), tr('Resumen del periodo'));
                  case 'sales':
                    _copy(report.exportCsv(), tr('Reporte de ventas'));
                  case 'restock':
                    _copy(_RestockTab.csv(inv), tr('Lista de reposición'));
                  default:
                    _copy(inv.exportProductsCsv(), tr('Inventario'));
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'summary',
                  child: ListTile(
                    leading: const Icon(Icons.summarize_outlined),
                    title: Text(tr('Copiar resumen del periodo (CSV)')),
                  ),
                ),
                PopupMenuItem(
                  value: 'sales',
                  child: ListTile(
                    leading: const Icon(Icons.receipt_long_outlined),
                    title: Text(tr('Copiar detalle de ventas (CSV)')),
                  ),
                ),
                PopupMenuItem(
                  value: 'restock',
                  child: ListTile(
                    leading: const Icon(Icons.shopping_cart_outlined),
                    title: Text(tr('Copiar lista de reposición (CSV)')),
                  ),
                ),
                PopupMenuItem(
                  value: 'products',
                  child: ListTile(
                    leading: const Icon(Icons.inventory_2_outlined),
                    title: Text(tr('Copiar inventario (CSV)')),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: tr('Resumen')),
              Tab(text: tr('Productos')),
              Tab(text: tr('Reposición')),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _SummaryTab(report: report, header: _periodBar(report.range)),
            _ProductsTab(report: report, header: _periodBar(report.range)),
            const _RestockTab(),
          ],
        ),
      ),
    );
  }

  Widget _periodBar(ReportRange range) {
    final scheme = Theme.of(context).colorScheme;
    final compared = tr('comparado con los {n} días anteriores',
        {'n': range.dayCount});
    ChoiceChip chip(_Preset p, String label) => ChoiceChip(
          label: Text(label),
          selected: _preset == p,
          onSelected: (_) => setState(() => _preset = p),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            chip(_Preset.today, tr('Hoy')),
            chip(_Preset.week, tr('7 días')),
            chip(_Preset.month30, tr('30 días')),
            chip(_Preset.thisMonth, tr('Este mes')),
            ChoiceChip(
              avatar: const Icon(Icons.date_range, size: 18),
              label: Text(_preset == _Preset.custom
                  ? range.label
                  : tr('Elegir fechas')),
              selected: _preset == _Preset.custom,
              onSelected: (_) => _pickDates(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${tr('Periodo')}: ${range.label} · $compared',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Piezas comunes
// -----------------------------------------------------------------------------

/// Tarjeta con título, subtítulo y contenido.
class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.child,
    this.subtitle,
    this.icon,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: scheme.primary),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: text.titleMedium),
                      if (subtitle != null)
                        Text(subtitle!,
                            style: text.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

/// Dos paneles lado a lado en pantallas anchas (PC) y uno bajo el otro en el
/// celular.
class _TwoColumns extends StatelessWidget {
  const _TwoColumns({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 760) {
        return Column(children: [left, const SizedBox(height: 16), right]);
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: left),
          const SizedBox(width: 16),
          Expanded(child: right),
        ],
      );
    });
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: Text(message,
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant)),
      ),
    );
  }
}

/// Texto y color de "▲ 12% vs anterior".
class _Delta {
  const _Delta(this.text, this.color);
  final String? text;
  final Color? color;

  factory _Delta.of(BuildContext context, num now, num before) {
    final pct = ReportService.change(now, before);
    if (pct == null) {
      return _Delta(now == 0 ? null : tr('Sin datos anteriores'), null);
    }
    final up = pct >= 0;
    return _Delta(
      '${up ? '▲' : '▼'} ${pct.abs().toStringAsFixed(0)}% ${tr('vs anterior')}',
      up ? const Color(0xFF15803D) : Theme.of(context).colorScheme.error,
    );
  }
}

// -----------------------------------------------------------------------------
// Resumen
// -----------------------------------------------------------------------------

enum _DailyMetric { sales, profit }

class _SummaryTab extends StatefulWidget {
  const _SummaryTab({required this.report, required this.header});

  final ReportService report;
  final Widget header;

  @override
  State<_SummaryTab> createState() => _SummaryTabState();
}

class _SummaryTabState extends State<_SummaryTab> {
  _DailyMetric _metric = _DailyMetric.sales;

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    final prev = r.previous;
    final scheme = Theme.of(context).colorScheme;

    final dSales = _Delta.of(context, r.total, prev.total);
    final dProfit = _Delta.of(context, r.profit, prev.profit);
    final dCount = _Delta.of(context, r.sales.length, prev.sales.length);
    final dTicket = _Delta.of(context, r.average, prev.average);

    final bestDay = r.bestDay();
    final bestHour = r.bestHour();
    final categories = r.salesByCategory();
    final payments = r.salesByPayment();
    final perDay = r.units / r.range.dayCount;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        widget.header,
        const SizedBox(height: 16),
        StatGrid(
          maxColumns: 3,
          children: [
            StatCard(
              icon: Icons.payments_outlined,
              label: tr('Ventas'),
              value: formatMoney(r.total),
              caption: dSales.text,
              captionColor: dSales.color,
            ),
            StatCard(
              icon: Icons.trending_up,
              label: tr('Ganancia'),
              value: formatMoney(r.profit),
              caption: dProfit.text,
              captionColor: dProfit.color,
            ),
            StatCard(
              icon: Icons.percent,
              label: tr('Margen de ganancia'),
              value: formatPercent(r.marginPercent),
              caption: tr('de cada venta'),
            ),
            StatCard(
              icon: Icons.receipt_long_outlined,
              label: tr('N° de ventas'),
              value: '${r.sales.length}',
              caption: dCount.text,
              captionColor: dCount.color,
            ),
            StatCard(
              icon: Icons.shopping_basket_outlined,
              label: tr('Ticket promedio'),
              value: formatMoney(r.average),
              caption: dTicket.text,
              captionColor: dTicket.color,
            ),
            StatCard(
              icon: Icons.inventory_outlined,
              label: tr('Unidades vendidas'),
              value: formatQty(r.units),
              caption: r.range.dayCount > 1
                  ? tr('{n} por día', {'n': perDay.toStringAsFixed(1)})
                  : null,
            ),
          ],
        ),
        if (r.sales.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            color: scheme.secondaryContainer.withValues(alpha: 0.55),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 24,
                runSpacing: 12,
                children: [
                  if (bestDay != null && r.range.dayCount > 1)
                    _Insight(
                      icon: Icons.emoji_events_outlined,
                      title: tr('Mejor día'),
                      value:
                          '${formatDate(bestDay.day)} · ${formatMoney(bestDay.total)}',
                    ),
                  if (bestHour != null)
                    _Insight(
                      icon: Icons.schedule,
                      title: tr('Hora más fuerte'),
                      value:
                          '${bestHour.toString().padLeft(2, '0')}:00 – ${(bestHour + 1).toString().padLeft(2, '0')}:00',
                    ),
                  if (categories.isNotEmpty)
                    _Insight(
                      icon: Icons.category_outlined,
                      title: tr('Categoría que más vende'),
                      value: categories.first.label,
                    ),
                  if (payments.isNotEmpty)
                    _Insight(
                      icon: Icons.credit_card,
                      title: tr('Medio de pago más usado'),
                      value: payments.first.label,
                    ),
                ],
              ),
            ),
          ),
        ],
        if (r.range.dayCount > 1) ...[
          const SizedBox(height: 16),
          _Panel(
            icon: Icons.bar_chart,
            title: _metric == _DailyMetric.sales
                ? tr('Ventas por día')
                : tr('Ganancia por día'),
            subtitle: tr(
                'Pasa el mouse o mantén presionada una barra para ver el monto'),
            trailing: SegmentedButton<_DailyMetric>(
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: [
                ButtonSegment(
                    value: _DailyMetric.sales, label: Text(tr('Ventas'))),
                ButtonSegment(
                    value: _DailyMetric.profit, label: Text(tr('Ganancia'))),
              ],
              selected: {_metric},
              onSelectionChanged: (s) => setState(() => _metric = s.first),
            ),
            child: SizedBox(
              height: 190,
              child: SimpleBarChart(
                items: dailyBars(_metric == _DailyMetric.sales
                    ? r.dailySales()
                    : r.dailyProfit()),
                color: _metric == _DailyMetric.profit
                    ? const Color(0xFF15803D)
                    : null,
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        _Panel(
          icon: Icons.schedule,
          title: tr('Ventas por hora'),
          subtitle: tr('Te ayuda a saber a qué hora necesitas más atención'),
          child: r.sales.isEmpty
              ? _Empty(tr('Sin ventas en este periodo.'))
              : SizedBox(
                  height: 160,
                  child: SimpleBarChart(items: hourBars(r.salesByHour())),
                ),
        ),
        const SizedBox(height: 16),
        _TwoColumns(
          left: _Panel(
            icon: Icons.category_outlined,
            title: tr('Ventas por categoría'),
            child: categories.isEmpty
                ? _Empty(tr('Sin ventas en este periodo.'))
                : BreakdownList(items: categories),
          ),
          right: _Panel(
            icon: Icons.credit_card,
            title: tr('Por medio de pago'),
            child: payments.isEmpty
                ? _Empty(tr('Sin ventas en este periodo.'))
                : BreakdownList(items: payments),
          ),
        ),
        const SizedBox(height: 16),
        _SalesDetail(report: r),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _Insight extends StatelessWidget {
  const _Insight(
      {required this.icon, required this.title, required this.value});

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final fg = Theme.of(context).colorScheme.onSecondaryContainer;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: fg),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    TextStyle(fontSize: 12, color: fg.withValues(alpha: 0.8))),
            Text(value,
                style: TextStyle(fontWeight: FontWeight.w700, color: fg)),
          ],
        ),
      ],
    );
  }
}

class _SalesDetail extends StatelessWidget {
  const _SalesDetail({required this.report});
  final ReportService report;

  @override
  Widget build(BuildContext context) {
    final sales = report.sales;
    return _Panel(
      icon: Icons.receipt_long_outlined,
      title: tr('Detalle de ventas'),
      subtitle: sales.length > 100
          ? tr('Se muestran las 100 más recientes de {n}', {'n': sales.length})
          : null,
      child: sales.isEmpty
          ? _Empty(tr('Sin ventas en este periodo.'))
          : Column(
              children: [
                for (final sale in sales.take(100))
                  ExpansionTile(
                    shape: const Border(),
                    tilePadding: EdgeInsets.zero,
                    title: Text(
                        '${tr('N°')} ${sale.number} · ${formatMoney(sale.total)}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text([
                      formatDateTime(sale.date),
                      sale.paymentMethod.label,
                      tr('Ganancia {amount}',
                          {'amount': formatMoney(sale.profit)}),
                    ].join(' · ')),
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
    );
  }
}

// -----------------------------------------------------------------------------
// Productos
// -----------------------------------------------------------------------------

enum _ProductSort { total, profit, quantity, margin }

class _ProductsTab extends StatefulWidget {
  const _ProductsTab({required this.report, required this.header});

  final ReportService report;
  final Widget header;

  @override
  State<_ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<_ProductsTab> {
  _ProductSort _sort = _ProductSort.total;
  bool _all = false;

  String _sortLabel(_ProductSort s) {
    switch (s) {
      case _ProductSort.total:
        return tr('Más vendidos');
      case _ProductSort.profit:
        return tr('Más ganancia');
      case _ProductSort.quantity:
        return tr('Más unidades');
      case _ProductSort.margin:
        return tr('Mejor margen');
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    final scheme = Theme.of(context).colorScheme;
    final small = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: scheme.onSurfaceVariant);
    final list = r.productPerformance();
    switch (_sort) {
      case _ProductSort.total:
        break;
      case _ProductSort.profit:
        list.sort((a, b) => b.profit.compareTo(a.profit));
      case _ProductSort.quantity:
        list.sort((a, b) => b.quantity.compareTo(a.quantity));
      case _ProductSort.margin:
        list.sort((a, b) => b.marginPercent.compareTo(a.marginPercent));
    }
    final shown = _all ? list : list.take(15).toList();
    final unsold = r.unsold();
    final stuck =
        unsold.fold<int>(0, (sum, p) => sum + (p.costPrice * p.stock).round());
    var maxTotal = 1;
    for (final p in list) {
      if (p.total > maxTotal) maxTotal = p.total;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        widget.header,
        const SizedBox(height: 16),
        _Panel(
          icon: Icons.leaderboard_outlined,
          title: tr('Ranking de productos'),
          subtitle:
              tr('{n} productos vendidos en el periodo', {'n': list.length}),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in _ProductSort.values)
                    ChoiceChip(
                      label: Text(_sortLabel(s)),
                      selected: _sort == s,
                      onSelected: (_) => setState(() => _sort = s),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (list.isEmpty)
                _Empty(tr('Sin ventas en este periodo.'))
              else ...[
                for (var i = 0; i < shown.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 15,
                          backgroundColor: i < 3
                              ? scheme.tertiaryContainer
                              : scheme.surfaceContainerHighest,
                          child: Text('${i + 1}',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(shown[i].name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: shown[i].total / maxTotal,
                                  minHeight: 6,
                                  backgroundColor:
                                      scheme.surfaceContainerHighest,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                [
                                  tr('{qty} vendidos',
                                      {'qty': formatQty(shown[i].quantity)}),
                                  tr('Ganancia {amount}',
                                      {'amount': formatMoney(shown[i].profit)}),
                                  formatPercent(shown[i].marginPercent),
                                ].join(' · '),
                                style: small,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(formatMoney(shown[i].total),
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                if (list.length > 15)
                  Center(
                    child: TextButton(
                      onPressed: () => setState(() => _all = !_all),
                      child: Text(_all
                          ? tr('Ver menos')
                          : tr('Ver los {n} productos', {'n': list.length})),
                    ),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Panel(
          icon: Icons.hourglass_empty,
          title: tr('Productos sin ventas'),
          subtitle: unsold.isEmpty
              ? null
              : tr(
                  'Tienes {amount} en mercadería que no se movió en este periodo',
                  {'amount': formatMoney(stuck)}),
          child: unsold.isEmpty
              ? _Empty(tr('Todos tus productos con stock se vendieron. ¡Bien!'))
              : Column(
                  children: [
                    for (final p in unsold.take(20))
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(p.name,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(tr('Stock: {qty}', {
                          'qty': '${formatQty(p.stock)} ${unitLabel(p.unit)}'
                        })),
                        trailing: Text(
                            formatMoney((p.costPrice * p.stock).round()),
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    if (unsold.length > 20)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child:
                            Text(tr('y {n} más', {'n': unsold.length - 20})),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Reposición: cuándo se acaba cada producto
// -----------------------------------------------------------------------------

class _RestockTab extends StatefulWidget {
  const _RestockTab();

  /// Lista de compras para Excel.
  static String csv(InventoryService inv, {int coverDays = 14}) {
    final c = inv.currency;
    final b = StringBuffer(
        '${tr('Producto;Stock;Vende por día;Días que alcanza;Comprar;Costo estimado')}\n');
    for (final x in ReportService.restock(inv, coverDays: coverDays)) {
      b.writeln([
        x.product.name.replaceAll(';', ','),
        formatQty(x.product.stock),
        x.dailyAverage.toStringAsFixed(2),
        x.daysLeft == null ? '-' : x.daysLeft!.toStringAsFixed(0),
        formatQty(x.suggested),
        c.toPlain((x.suggested * x.product.costPrice).round()),
      ].join(';'));
    }
    return b.toString();
  }

  @override
  State<_RestockTab> createState() => _RestockTabState();
}

class _RestockTabState extends State<_RestockTab> {
  int _cover = 14;

  Future<void> _copyList(List<RestockInfo> items) async {
    final b = StringBuffer(
        '${tr('Pedido de reposición')} – ${formatDate(DateTime.now())}\n');
    for (final x in items.where((x) => x.suggested > 0)) {
      b.writeln(
          '• ${x.product.name}: ${formatQty(x.suggested)} ${unitLabel(x.product.unit)}');
    }
    await Clipboard.setData(ClipboardData(text: b.toString()));
    if (!mounted) return;
    showMessage(context,
        tr('Lista copiada. Pégala en WhatsApp para enviársela a tu proveedor.'));
  }

  Color _colorFor(ColorScheme scheme, double? days) {
    if (days == null) return scheme.outline;
    if (days <= 3) return scheme.error;
    if (days <= 7) return const Color(0xFFD97706);
    return const Color(0xFF15803D);
  }

  @override
  Widget build(BuildContext context) {
    final inv = context.watch<InventoryService>();
    final scheme = Theme.of(context).colorScheme;
    final small = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: scheme.onSurfaceVariant);
    final items = ReportService.restock(inv, coverDays: _cover);
    final urgent = items.where((x) => (x.daysLeft ?? 999) <= 7).length;
    final cost = items.fold<int>(
        0, (sum, x) => sum + (x.suggested * x.product.costPrice).round());
    final toBuy = items.where((x) => x.suggested > 0).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          tr('Calculado con lo que vendiste en los últimos 30 días.'),
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(tr('Comprar para:'),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            for (final d in [7, 14, 30])
              ChoiceChip(
                label: Text(tr('{n} días', {'n': d})),
                selected: _cover == d,
                onSelected: (_) => setState(() => _cover = d),
              ),
          ],
        ),
        const SizedBox(height: 16),
        StatGrid(
          maxColumns: 3,
          children: [
            StatCard(
              icon: Icons.warning_amber_rounded,
              label: tr('Se acaban en 7 días o menos'),
              value: '$urgent',
              highlight: urgent > 0,
            ),
            StatCard(
              icon: Icons.shopping_cart_outlined,
              label: tr('Productos para comprar'),
              value: '${toBuy.length}',
            ),
            StatCard(
              icon: Icons.account_balance_wallet_outlined,
              label: tr('Costo estimado de la compra'),
              value: formatMoney(cost),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _Panel(
          icon: Icons.event_busy_outlined,
          title: tr('Cuándo se acaba cada producto'),
          subtitle: tr('Ordenado del más urgente al menos urgente'),
          trailing: toBuy.isEmpty
              ? null
              : FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                  onPressed: () => _copyList(items),
                  icon: const Icon(Icons.copy, size: 18),
                  label: Text(tr('Copiar pedido')),
                ),
          child: items.isEmpty
              ? _Empty(tr(
                  'Aún no hay ventas suficientes para calcular. Vuelve cuando registres algunas ventas.'))
              : Column(
                  children: [
                    for (final x in items.take(60))
                      _RestockRow(
                        info: x,
                        color: _colorFor(scheme, x.daysLeft),
                        small: small,
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _RestockRow extends StatelessWidget {
  const _RestockRow(
      {required this.info, required this.color, required this.small});

  final RestockInfo info;
  final Color color;
  final TextStyle? small;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final x = info;
    final days = x.daysLeft;
    final daysText = days == null
        ? '–'
        : days >= 99
            ? '99+'
            : days.toStringAsFixed(0);
    final detail = x.dailyAverage > 0
        ? tr('Stock {stock} · vende {avg} por día', {
            'stock': formatQty(x.product.stock),
            'avg': x.dailyAverage.toStringAsFixed(x.dailyAverage < 10 ? 1 : 0),
          })
        : tr('Stock {stock} · bajo el mínimo, sin ventas recientes',
            {'stock': formatQty(x.product.stock)});

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 64,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(daysText,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: color)),
                Text(tr('días'), style: TextStyle(fontSize: 11, color: color)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(x.product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(detail, style: small),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                x.suggested > 0
                    ? '+${formatQty(x.suggested)} ${unitLabel(x.product.unit)}'
                    : tr('Alcanza'),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color:
                      x.suggested > 0 ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
              if (x.suggested > 0 && x.product.costPrice > 0)
                Text(
                    formatMoney((x.suggested * x.product.costPrice).round()),
                    style: small),
            ],
          ),
        ],
      ),
    );
  }
}
