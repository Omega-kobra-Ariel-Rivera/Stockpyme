/// Monedas que puede usar cada negocio.
///
/// Los montos se guardan como números enteros en la unidad más chica de la
/// moneda: pesos chilenos tal cual ($1.290 → 1290) y, en monedas con
/// centavos, en centavos (US$12,50 → 1250).
enum AppCurrency {
  clp('CLP', 'Peso chileno', r'$', 0, '.', ','),
  ars('ARS', 'Peso argentino', r'$', 0, '.', ','),
  cop('COP', 'Peso colombiano', r'$', 0, '.', ','),
  mxn('MXN', 'Peso mexicano', r'$', 2, ',', '.'),
  pen('PEN', 'Sol peruano', 'S/ ', 2, ',', '.'),
  usd('USD', 'Dólar', r'US$', 2, ',', '.'),
  eur('EUR', 'Euro', '€', 2, '.', ',', symbolAfter: true),
  brl('BRL', 'Real brasileño', r'R$ ', 2, '.', ',');

  const AppCurrency(
    this.code,
    this.label,
    this.symbol,
    this.decimals,
    this.thousandsSeparator,
    this.decimalSeparator, {
    this.symbolAfter = false,
  });

  final String code;

  /// Nombre en español (se traduce con tr al mostrarlo).
  final String label;
  final String symbol;
  final int decimals;
  final String thousandsSeparator;
  final String decimalSeparator;
  final bool symbolAfter;

  int get factor => _pow10(decimals);

  /// Billetes comunes (en la unidad más chica) para los montos rápidos
  /// al cobrar en efectivo.
  List<int> get quickBills {
    final List<int> whole = switch (this) {
      AppCurrency.clp => [1000, 2000, 5000, 10000, 20000],
      AppCurrency.ars => [1000, 2000, 10000, 20000],
      AppCurrency.cop => [2000, 5000, 10000, 20000, 50000, 100000],
      AppCurrency.mxn => [20, 50, 100, 200, 500],
      AppCurrency.pen => [10, 20, 50, 100, 200],
      AppCurrency.usd => [1, 5, 10, 20, 50, 100],
      AppCurrency.eur => [5, 10, 20, 50, 100],
      AppCurrency.brl => [2, 5, 10, 20, 50, 100],
    };
    return [for (final b in whole) b * factor];
  }

  static AppCurrency fromCode(String? code) => AppCurrency.values.firstWhere(
        (c) => c.code == code,
        orElse: () => AppCurrency.clp,
      );

  /// 1290 → "$1.290" · 1250 (USD) → "US$12.50" · 1250 (EUR) → "12,50 €"
  String format(num minorUnits) {
    final value = minorUnits.round();
    final negative = value < 0;
    final abs = value.abs();
    final whole = abs ~/ factor;
    final fraction = abs % factor;

    final digits = whole.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write(thousandsSeparator);
      }
      buffer.write(digits[i]);
    }
    if (decimals > 0) {
      buffer
        ..write(decimalSeparator)
        ..write(fraction.toString().padLeft(decimals, '0'));
    }
    final amount = buffer.toString();
    final text = symbolAfter ? '$amount $symbol' : '$symbol$amount';
    return negative ? '-$text' : text;
  }

  /// Texto para un campo editable, sin símbolo ni miles: "1290" o "12,50".
  String toInput(int minorUnits) {
    if (decimals == 0) return '$minorUnits';
    final sign = minorUnits < 0 ? '-' : '';
    final abs = minorUnits.abs();
    final whole = abs ~/ factor;
    final fraction = (abs % factor).toString().padLeft(decimals, '0');
    return '$sign$whole$decimalSeparator$fraction';
  }

  /// Número para exportar a planillas (sin símbolo ni miles).
  String toPlain(int minorUnits) => toInput(minorUnits);

  /// Acepta "$4.990", "4990", "12,50", "12.5" o "1,234.50".
  /// Devuelve el monto en la unidad más chica (centavos si corresponde).
  int? parse(String text) {
    final clean = text.trim().replaceAll(RegExp(r'[^0-9.,]'), '');
    if (clean.isEmpty) return null;

    if (decimals == 0) {
      final digits = clean.replaceAll(RegExp(r'[^0-9]'), '');
      return digits.isEmpty ? null : int.tryParse(digits);
    }

    // El último punto o coma es decimal si le siguen 1 o 2 dígitos.
    var whole = clean;
    var fraction = '';
    final last = clean.lastIndexOf(RegExp(r'[.,]'));
    if (last >= 0) {
      final after = clean.length - last - 1;
      if (after >= 1 && after <= decimals) {
        whole = clean.substring(0, last);
        fraction = clean.substring(last + 1);
      }
    }
    whole = whole.replaceAll(RegExp(r'[^0-9]'), '');
    if (whole.isEmpty && fraction.isEmpty) return null;
    final w = int.tryParse(whole.isEmpty ? '0' : whole);
    final f = int.tryParse(fraction.padRight(decimals, '0'));
    if (w == null || f == null) return null;
    return w * factor + f;
  }
}

int _pow10(int n) {
  var result = 1;
  for (var i = 0; i < n; i++) {
    result *= 10;
  }
  return result;
}

/// Moneda del negocio que tiene la sesión abierta.
class Money {
  Money._();

  static AppCurrency currency = AppCurrency.clp;
}

/// Monto en la moneda del negocio.
String formatMoney(num minorUnits) => Money.currency.format(minorUnits);

/// Lee un monto escrito por el usuario en la moneda del negocio.
int? parseMoney(String text) => Money.currency.parse(text);

/// Monto para mostrar en un campo editable.
String moneyInput(int minorUnits) => Money.currency.toInput(minorUnits);
