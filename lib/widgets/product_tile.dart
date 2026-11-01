import 'package:flutter/material.dart';

import '../l10n/i18n.dart';
import '../models/product.dart';
import '../utils/formatters.dart';

class ProductTile extends StatelessWidget {
  const ProductTile({super.key, required this.product, this.onTap});

  final Product product;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final low = product.isLowStock;
    final initial =
        product.name.isEmpty ? '?' : product.name.substring(0, 1).toUpperCase();

    final details = [
      if (product.category.isNotEmpty) product.category,
      if (product.barcode.isNotEmpty) product.barcode,
    ];

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: low ? scheme.errorContainer : scheme.primaryContainer,
        foregroundColor:
            low ? scheme.onErrorContainer : scheme.onPrimaryContainer,
        child: Text(initial),
      ),
      title: Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        details.isEmpty ? tr('Sin categoría') : details.join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            formatMoney(product.salePrice),
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            '${formatQty(product.stock)} ${unitLabel(product.unit)}',
            style: text.bodySmall?.copyWith(
              color: low ? scheme.error : scheme.onSurfaceVariant,
              fontWeight: low ? FontWeight.w600 : null,
            ),
          ),
        ],
      ),
    );
  }
}
