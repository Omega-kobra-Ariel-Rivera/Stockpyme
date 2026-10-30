/// Formato de moneda chilena: $12.345
String formatCLP(num value) {
  final rounded = value.round();
  final negative = rounded < 0;
  final digits = rounded.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return '${negative ? '-' : ''}\$$buffer';
}

/// Cantidades: 3 → "3", 1.25 → "1,25"
String formatQty(double quantity) {
  if (quantity == quantity.roundToDouble()) {
    return quantity.toInt().toString();
  }
  var text = quantity.toStringAsFixed(3);
  text = text.replaceFirst(RegExp(r'0+$'), '');
  return text.replaceAll('.', ',');
}

String _two(int n) => n.toString().padLeft(2, '0');

String formatDate(DateTime date) =>
    '${_two(date.day)}-${_two(date.month)}-${date.year}';

String formatDateTime(DateTime date) =>
    '${formatDate(date)} ${_two(date.hour)}:${_two(date.minute)}';

String formatPercent(double value) =>
    '${value.toStringAsFixed(0)}%';

/// Acepta "1,5" o "1.5".
double? parseQty(String text) {
  final clean = text.trim().replaceAll(',', '.');
  if (clean.isEmpty) return null;
  return double.tryParse(clean);
}

/// Acepta "$4.990", "4990" o "4.990".
int? parseCLP(String text) {
  final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return null;
  return int.tryParse(digits);
}

DateTime startOfDay(DateTime date) =>
    DateTime(date.year, date.month, date.day);

const List<String> weekdayInitials = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

/// "hace 5 min", "hace 3 h", "hace 2 días" o la fecha si es más antiguo.
String formatAgo(DateTime? date) {
  if (date == null) return 'sin datos';
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'recién';
  if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'hace ${diff.inHours} h';
  if (diff.inDays < 30) {
    return diff.inDays == 1 ? 'hace 1 día' : 'hace ${diff.inDays} días';
  }
  return formatDate(date);
}
