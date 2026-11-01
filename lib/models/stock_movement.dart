import '../l10n/i18n.dart';
import '../utils/id_generator.dart';

enum MovementType {
  entrada('Entrada'),
  salida('Salida / merma'),
  venta('Venta'),
  ajuste('Ajuste');

  const MovementType(this.spanishLabel);
  final String spanishLabel;
  String get label => tr(spanishLabel);
}

class StockMovement {
  StockMovement({
    required this.id,
    required this.productId,
    required this.productName,
    required this.type,
    required this.quantity,
    required this.date,
    this.note = '',
  });

  final String id;
  final String productId;
  final String productName;
  final MovementType type;

  /// Positivo suma stock, negativo lo descuenta.
  final double quantity;
  final DateTime date;
  final String note;

  Map<String, dynamic> toJson() => {
        'id': id,
        'productId': productId,
        'productName': productName,
        'type': type.name,
        'quantity': quantity,
        'date': date.toIso8601String(),
        'note': note,
      };

  factory StockMovement.fromJson(Map<String, dynamic> json) => StockMovement(
        id: json['id'] as String,
        productId: json['productId'] as String? ?? '',
        productName: json['productName'] as String? ?? '',
        type: enumByName(
          MovementType.values,
          json['type'] as String?,
          MovementType.ajuste,
        ),
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
        date: DateTime.tryParse(json['date'] as String? ?? '') ??
            DateTime.now(),
        note: json['note'] as String? ?? '',
      );
}
