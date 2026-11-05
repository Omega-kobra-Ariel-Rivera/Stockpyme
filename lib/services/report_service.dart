import 'dart:math';

import '../l10n/i18n.dart';
import '../models/product.dart';
import '../models/report_models.dart';
import '../models/sale.dart';
import '../utils/formatters.dart';
import 'inventory_service.dart';

/// Un periodo de reportes: desde [start] (incluido) hasta [end] (excluido).
class ReportRange {
  const ReportRange(this.start, this.end);

  /// Los últimos [days] días, incluido hoy.
  factory ReportRange.lastDays(int days) {
    final today = startOfDay(DateTime.now());
    return ReportRange(
      DateTime(today.year, today.month, today.day - (days - 1)),
      DateTime(today.year, today.month, today.day + 1),
    );
  }

  /// Del día [from] al día [to], ambos incluidos.
  factory ReportRange.days(DateTime from, DateTime to) {
    final a = startOfDay(from);
    final b = startOfDay(to);
    return ReportRange(a, DateTime(b.year, b.month, b.day + 1));
  }

  final DateTime start;
  final DateTime end;

  /// Desde el día 1 del mes actual hasta hoy.
  factory ReportRange.thisMonth() {
    final today = startOfDay(DateTime.now());
    return ReportRange(DateTime(today.year, today.month, 1),
        DateTime(today.year, today.month, today.day + 1));
  }

  int get dayCount => max(1, (end.difference(start).inHours / 24).round());

  /// Último día incluido.
  DateTime get lastDay => DateTime(end.year, end.month, end.day - 1);

  /// Periodo del mismo largo justo antes (para comparar).
  ReportRange get previous => ReportRange(
        DateTime(start.year, start.month, start.day - dayCount),
        start,
      );

  String get label => dayCount == 1
      ? formatDate(start)
      : tr('{from} al {to}',
          {'from': formatDate(start), 'to': formatDate(lastDay)});

  bool contains(DateTime date) => !date.isBefore(start) && date.isBefore(end);
}

/// Total por grupo (categoría, medio de pago...).
class Breakdown {
  const Breakdown(this.label, this.total);
  final String label;
  final int total;
}

/// Lo que vendió un producto en el periodo.
class ProductPerformance {
  ProductPerformance({required this.productId, required this.name});

  final String productId;
  final String name;
  double quantity = 0;
  int total = 0;
  int profit = 0;

  double get marginPercent => total == 0 ? 0 : profit / total * 100;
}

/// Cuándo se acaba un producto según lo que se vende.
class RestockInfo {
  const RestockInfo({
    required this.product,
    required this.dailyAverage,
    required this.daysLeft,
    required this.suggested,
  });

  final Product product;

  /// Unidades vendidas por día, en promedio.
  final double dailyAverage;

  /// Días que alcanza el stock actual (null si no se vende).
  final double? daysLeft;

  /// Cantidad sugerida para comprar.
  final double suggested;
}

/// Cálculos de los reportes (no guardan nada: leen el inventario).
class ReportService {
  ReportService(this.inv, this.range);

  final InventoryService inv;
  final ReportRange range;

  late final List<Sale> sales =
      inv.sales.where((s) => range.contains(s.date)).toList();

  int get total => sales.fold<int>(0, (sum, s) => sum + s.total);
  int get profit => sales.fold<int>(0, (sum, s) => sum + s.profit);
  int get average => sales.isEmpty ? 0 : (total / sales.length).round();

  /// Unidades vendidas (kg y litros se suman tal cual).
  double get units => sales.fold<double>(
      0, (sum, s) => sum + s.items.fold<double>(0, (a, i) => a + i.quantity));

  /// Mismo cálculo para el periodo anterior (para "▲ 12%").
  late final ReportService previous = ReportService(inv, range.previous);

  /// Cambio en % respecto al periodo anterior; null si antes no hubo nada.
  static double? change(num now, num before) =>
      before == 0 ? null : (now - before) / before.abs() * 100;

  /// Margen de ganancia del periodo (ganancia / ventas).
  double get marginPercent => total == 0 ? 0 : profit / total * 100;

  List<DateTime> get _days => [
        for (var i = 0; i < range.dayCount; i++)
          DateTime(range.start.year, range.start.month, range.start.day + i),
      ];

  /// Ventas de cada día del periodo.
  List<DailyTotal> dailySales() => [
        for (final day in _days)
          DailyTotal(
            day: day,
            total: sales
                .where((s) => startOfDay(s.date) == day)
                .fold<int>(0, (sum, s) => sum + s.total),
          ),
      ];

  /// Ganancia de cada día del periodo.
  List<DailyTotal> dailyProfit() => [
        for (final day in _days)
          DailyTotal(
            day: day,
            total: sales
                .where((s) => startOfDay(s.date) == day)
                .fold<int>(0, (sum, s) => sum + s.profit),
          ),
      ];

  /// Ventas por hora del día (0 a 23).
  List<int> salesByHour() {
    final hours = List<int>.filled(24, 0);
    for (final s in sales) {
      hours[s.date.hour] += s.total;
    }
    return hours;
  }

  /// Ventas por categoría de producto, de mayor a menor.
  List<Breakdown> salesByCategory() {
    final map = <String, int>{};
    for (final sale in sales) {
      for (final item in sale.items) {
        final product = inv.productById(item.productId);
        final category = (product?.category.trim().isNotEmpty ?? false)
            ? product!.category.trim()
            : tr('Sin categoría');
        map[category] = (map[category] ?? 0) + item.subtotal;
      }
    }
    final list = [for (final e in map.entries) Breakdown(e.key, e.value)]
      ..sort((a, b) => b.total.compareTo(a.total));
    return list;
  }

  /// Ventas por medio de pago, de mayor a menor.
  List<Breakdown> salesByPayment() {
    final map = <PaymentMethod, int>{};
    for (final sale in sales) {
      map[sale.paymentMethod] = (map[sale.paymentMethod] ?? 0) + sale.total;
    }
    final list = [for (final e in map.entries) Breakdown(e.key.label, e.value)]
      ..sort((a, b) => b.total.compareTo(a.total));
    return list;
  }

  /// Productos más vendidos del periodo.
  List<TopProduct> topProducts({int limit = 5}) {
    final map = <String, TopProduct>{};
    for (final sale in sales) {
      for (final item in sale.items) {
        final entry =
            map.putIfAbsent(item.productId, () => TopProduct(name: item.name));
        entry.quantity += item.quantity;
        entry.total += item.subtotal;
      }
    }
    final list = map.values.toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    return list.take(limit).toList();
  }

  /// Todos los productos vendidos en el periodo, de más a menos vendido.
  List<ProductPerformance> productPerformance() {
    final map = <String, ProductPerformance>{};
    for (final sale in sales) {
      for (final item in sale.items) {
        final perf = map.putIfAbsent(item.productId,
            () => ProductPerformance(productId: item.productId, name: item.name));
        perf.quantity += item.quantity;
        perf.total += item.subtotal;
        perf.profit += item.profit;
      }
    }
    return map.values.toList()..sort((a, b) => b.total.compareTo(a.total));
  }

  /// Productos con stock que no se vendieron en el periodo.
  List<Product> unsold() {
    final sold = {
      for (final sale in sales)
        for (final item in sale.items) item.productId,
    };
    final list = inv.products
        .where((p) => p.stock > 0 && !sold.contains(p.id))
        .toList()
      ..sort((a, b) => (b.costPrice * b.stock).compareTo(a.costPrice * a.stock));
    return list;
  }

  /// Día con más ventas del periodo (null si no hubo ventas).
  DailyTotal? bestDay() {
    DailyTotal? best;
    for (final d in dailySales()) {
      if (d.total > 0 && (best == null || d.total > best.total)) best = d;
    }
    return best;
  }

  /// Hora con más ventas (0 a 23), o null.
  int? bestHour() {
    final hours = salesByHour();
    var best = -1;
    for (var h = 0; h < 24; h++) {
      if (hours[h] > 0 && (best < 0 || hours[h] > hours[best])) best = h;
    }
    return best < 0 ? null : best;
  }

  /// Resumen del periodo en CSV (indicadores, categorías, medios de pago y
  /// productos) para abrir en Excel.
  String exportSummaryCsv() {
    final c = inv.currency;
    final b = StringBuffer()
      ..writeln('${tr('Reporte')};${range.label}')
      ..writeln()
      ..writeln('${tr('Indicador')};${tr('Valor')}')
      ..writeln('${tr('Ventas')};${c.toPlain(total)}')
      ..writeln('${tr('Ganancia')};${c.toPlain(profit)}')
      ..writeln('${tr('Margen')};${marginPercent.toStringAsFixed(1)}%')
      ..writeln('${tr('N° de ventas')};${sales.length}')
      ..writeln('${tr('Ticket promedio')};${c.toPlain(average)}')
      ..writeln('${tr('Unidades vendidas')};${formatQty(units)}')
      ..writeln()
      ..writeln('${tr('Categoría')};${tr('Ventas')}');
    for (final x in salesByCategory()) {
      b.writeln('${x.label};${c.toPlain(x.total)}');
    }
    b
      ..writeln()
      ..writeln('${tr('Medio de pago')};${tr('Ventas')}');
    for (final x in salesByPayment()) {
      b.writeln('${x.label};${c.toPlain(x.total)}');
    }
    b
      ..writeln()
      ..writeln(
          '${tr('Producto')};${tr('Cantidad')};${tr('Ventas')};${tr('Ganancia')};${tr('Margen')}');
    for (final p in productPerformance()) {
      b.writeln(
          '${p.name.replaceAll(';', ',')};${formatQty(p.quantity)};${c.toPlain(p.total)};${c.toPlain(p.profit)};${p.marginPercent.toStringAsFixed(1)}%');
    }
    return b.toString();
  }

  /// Copia de las ventas del periodo para Excel.
  String exportCsv() {
    final buffer = StringBuffer(
        '${tr('Fecha;Venta N°;Producto;Cantidad;Precio unitario;Subtotal;Ganancia;Medio de pago')}\n');
    String csv(Object? value) {
      final text = '${value ?? ''}';
      if (text.contains(';') || text.contains('"') || text.contains('\n')) {
        return '"${text.replaceAll('"', '""')}"';
      }
      return text;
    }

    for (final sale in sales) {
      for (final item in sale.items) {
        buffer.writeln([
          formatDateTime(sale.date),
          sale.number,
          item.name,
          formatQty(item.quantity),
          inv.currency.toPlain(item.unitPrice),
          inv.currency.toPlain(item.subtotal),
          inv.currency.toPlain(item.profit),
          sale.paymentMethod.label,
        ].map(csv).join(';'));
      }
    }
    return buffer.toString();
  }

  /// Cuándo se acaba cada producto, mirando las ventas de los últimos
  /// [historyDays] días. Sugiere comprar lo necesario para [coverDays] días.
  static List<RestockInfo> restock(
    InventoryService inv, {
    int historyDays = 30,
    int coverDays = 14,
  }) {
    final range = ReportRange.lastDays(historyDays);
    final sold = <String, double>{};
    for (final sale in inv.sales.where((s) => range.contains(s.date))) {
      for (final item in sale.items) {
        sold[item.productId] = (sold[item.productId] ?? 0) + item.quantity;
      }
    }
    final list = <RestockInfo>[];
    for (final p in inv.products) {
      final avg = (sold[p.id] ?? 0) / historyDays;
      if (avg <= 0 && !p.isLowStock) continue;
      final daysLeft = avg > 0 ? max(0.0, p.stock) / avg : null;
      var need = max(0.0, avg * coverDays - max(0.0, p.stock));
      if (avg <= 0 && p.isLowStock) need = max(0.0, p.minStock * 2 - p.stock);
      // Productos por unidad: se compra en números enteros.
      final whole = p.unit == 'unidad' || p.unit == 'caja' || p.unit == 'paquete';
      list.add(RestockInfo(
        product: p,
        dailyAverage: avg,
        daysLeft: daysLeft,
        suggested: whole ? need.ceilToDouble() : (need * 10).ceil() / 10,
      ));
    }
    list.sort((a, b) {
      final da = a.daysLeft ?? double.infinity;
      final db = b.daysLeft ?? double.infinity;
      final c = da.compareTo(db);
      return c != 0 ? c : a.product.name.compareTo(b.product.name);
    });
    return list;
  }
}
