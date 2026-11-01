import 'dart:math';

import 'package:flutter/material.dart';

import '../models/report_models.dart';
import '../utils/formatters.dart';

/// Gráfico de barras simple, sin dependencias externas.
class SalesBarChart extends StatelessWidget {
  const SalesBarChart({super.key, required this.data});

  final List<DailyTotal> data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final labelStyle = Theme.of(context)
        .textTheme
        .labelSmall
        ?.copyWith(color: scheme.onSurfaceVariant);
    final maxValue = data.fold<int>(0, (m, d) => max(m, d.total));
    final dense = data.length > 10;
    final today = startOfDay(DateTime.now());

    return LayoutBuilder(
      builder: (context, constraints) {
        const labelHeight = 16.0;
        final barMaxHeight = max(0.0, constraints.maxHeight - labelHeight - 6);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < data.length; i++)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: dense ? 1 : 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Tooltip(
                        message:
                            '${formatDate(data[i].day)}: ${formatMoney(data[i].total)}',
                        child: Container(
                          height: maxValue == 0
                              ? 3
                              : max(3.0, barMaxHeight * data[i].total / maxValue),
                          decoration: BoxDecoration(
                            color: data[i].day == today
                                ? scheme.tertiary
                                : scheme.primary,
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
                          child: Text(
                            _label(i),
                            style: labelStyle,
                            maxLines: 1,
                          ),
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

  String _label(int index) {
    final day = data[index].day;
    if (data.length <= 10) return weekdayInitials[day.weekday - 1];
    final isLast = index == data.length - 1;
    return (index % 5 == 0 || isLast) ? '${day.day}' : '';
  }
}
