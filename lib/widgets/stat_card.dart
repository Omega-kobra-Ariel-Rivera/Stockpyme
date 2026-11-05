import 'package:flutter/material.dart';

/// Tarjeta de un indicador (KPI): ícono, valor grande y etiqueta.
/// Tiene alto fijo para que no se estire en pantallas grandes.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
    this.caption,
    this.captionColor,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;

  /// Resalta la tarjeta en color de alerta.
  final bool highlight;

  /// Texto pequeño extra (por ejemplo "▲ 12% vs periodo anterior").
  final String? caption;
  final Color? captionColor;
  final VoidCallback? onTap;

  /// Alto recomendado para grillas de StatCard.
  static const double height = 104;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final color = highlight ? scheme.error : scheme.primary;

    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        style: text.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: highlight ? scheme.error : null,
                        ),
                      ),
                    ),
                    if (caption != null)
                      Text(
                        caption!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.labelSmall?.copyWith(
                          color: captionColor ?? scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grilla de StatCard que se adapta al ancho (2, 3 o 4 columnas).
class StatGrid extends StatelessWidget {
  const StatGrid({super.key, required this.children, this.maxColumns = 4});

  final List<Widget> children;
  final int maxColumns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      var columns = w >= 900 ? 4 : (w >= 600 ? 3 : 2);
      if (columns > maxColumns) columns = maxColumns;
      if (columns > children.length) columns = children.length;
      return GridView.count(
        crossAxisCount: columns,
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: (w - (columns - 1) * 12) / columns / StatCard.height,
        children: children,
      );
    });
  }
}
