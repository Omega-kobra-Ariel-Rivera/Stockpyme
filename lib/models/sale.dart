import '../l10n/i18n.dart';
import '../utils/id_generator.dart';

enum PaymentMethod {
  efectivo('Efectivo'),
  debito('Débito'),
  credito('Crédito'),
  transferencia('Transferencia');

  const PaymentMethod(this.spanishLabel);
  final String spanishLabel;
  String get label => tr(spanishLabel);
}

class SaleItem {
  SaleItem({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.unitCost,
  });

  final String productId;
  final String name;
  final double quantity;
  final int unitPrice;
  final int unitCost;

  int get subtotal => (unitPrice * quantity).round();
  int get profit => ((unitPrice - unitCost) * quantity).round();

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'name': name,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'unitCost': unitCost,
      };

  factory SaleItem.fromJson(Map<String, dynamic> json) => SaleItem(
        productId: json['productId'] as String? ?? '',
        name: json['name'] as String? ?? '',
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
        unitPrice: (json['unitPrice'] as num?)?.toInt() ?? 0,
        unitCost: (json['unitCost'] as num?)?.toInt() ?? 0,
      );
}

class Sale {
  Sale({
    required this.id,
    required this.number,
    required this.date,
    required this.items,
    required this.paymentMethod,
  });

  final String id;

  /// Número correlativo visible para el negocio (venta N° 1, 2, 3...).
  final int number;
  final DateTime date;
  final List<SaleItem> items;
  final PaymentMethod paymentMethod;

  int get total => items.fold(0, (sum, item) => sum + item.subtotal);
  int get profit => items.fold(0, (sum, item) => sum + item.profit);
  int get itemCount => items.length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'number': number,
        'date': date.toIso8601String(),
        'paymentMethod': paymentMethod.name,
        'items': items.map((i) => i.toJson()).toList(),
      };

  factory Sale.fromJson(Map<String, dynamic> json) => Sale(
        id: json['id'] as String,
        number: (json['number'] as num?)?.toInt() ?? 0,
        date: DateTime.tryParse(json['date'] as String? ?? '') ??
            DateTime.now(),
        paymentMethod: enumByName(
          PaymentMethod.values,
          json['paymentMethod'] as String?,
          PaymentMethod.efectivo,
        ),
        items: (json['items'] as List<dynamic>? ?? [])
            .map((e) => SaleItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}
