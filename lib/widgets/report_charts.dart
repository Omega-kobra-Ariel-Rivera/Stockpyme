import 'dart:math';

import 'package:flutter/material.dart';

import '../models/report_models.dart';
import '../services/report_service.dart';
import '../utils/formatters.dart';

/// Una barra del gráfico.
class BarItem {
  const BarItem({
    required this.label,
    required this.value,
    required this.tooltip,
    this.highlight = false,
  });

  /// Texto bajo la barra (puede ir vacío para no amontonar).
  final String label;
  final int value;
  final String tooltip;
  final bool highlight;
}

/// Gráfico de barras verticales, sin dependencias externas.
/// Admite valores negativos (por ejemplo, días con pérdida).
class SimpleBarChart extends StatelessWidget {
  const SimpleBarChart({super.key, required this.items, this.color});

  final List<BarItem> items;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final labelStyle = Theme.of(context)
        .textTheme
        .labelSmall
        ?.copyWith(color: scheme.onSurfaceVariant);
    final maxValue = items.fold<int>(0, (m, d) => max(m, d.value.abs()));
    final dense = items.length > 12;
    final barColor = color ?? scheme.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        const labelHeight = 16.0;
        final barMaxHeight = max(0.0, constraints.maxHeight - labelHeight - 6);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final item in items)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: dense ? 1 : 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Tooltip(
                        message: item.tooltip,
                        child: Container(
                          height: maxValue == 0
                              ? 3
                              : max(3.0,
                                  barMaxHeight * item.value.abs() / maxValue),
                          decoration: BoxDecoration(
                            color: item.value < 0
                                ? scheme.error
                                : item.highlight
                                    ? scheme.tertiary
                                    : barColor,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: labelHeight,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(item.label,
                              style: labelStyle, maxLines: 1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Barras de un periodo día a día (ventas o ganancia).
List<BarItem> dailyBars(List<DailyTotal> days) {
  final today = startOfDay(DateTime.now());
  final n = days.length;
  final step = n <= 10 ? 1 : (n / 8).ceil();
  return [
    for (var i = 0; i < n; i++)
      BarItem(
        label: n <= 10
            ? weekdayInitials[days[i].day.weekday - 1]
            : (i % step == 0 || i == n - 1)
                ? '${days[i].day.day}'
                : '',
        value: days[i].total,
        tooltip: '${formatDate(days[i].day)}: ${formatMoney(days[i].total)}',
        highlight: days[i].day == today,
      ),
  ];
}

/// Barras de las 24 horas del día.
List<BarItem> hourBars(List<int> hours) {
  final best = hours.fold<int>(0, max);
  return [
    for (var h = 0; h < 24; h++)
      BarItem(
        label: h % 3 == 0 ? '$h' : '',
        value: hours[h],
        tooltip: '${h.toString().padLeft(2, '0')}:00 · ${formatMoney(hours[h])}',
        highlight: best > 0 && hours[h] == best,
      ),
  ];
}

/// Lista con barras horizontales y porcentaje (categorías, medios de pago).
class BreakdownList extends StatelessWidget {
  const BreakdownList({super.key, required this.items, this.limit = 8});

  final List<Breakdown> items;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final sum = items.fold<int>(0, (s, b) => s + b.total);
    final colors = [
      scheme.primary,
      scheme.tertiary,
      scheme.secondary,
      scheme.error,
      scheme.primaryContainer,
      scheme.tertiaryContainer,
    ];
    return Column(
      children: [
        for (var i = 0; i < min(limit, items.length); i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(items[i].label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodyMedium),
                    ),
                    Text(
                      '${formatMoney(items[i].total)} · ${sum == 0 ? 0 : (items[i].total / sum * 100).round()}%',
                      style: text.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: sum == 0 ? 0 : items[i].total / sum,
                    minHeight: 10,
                    color: colors[i % colors.length],
                    backgroundColor: scheme.surfaceContainerHighest,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
