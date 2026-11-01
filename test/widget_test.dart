import 'package:flutter_test/flutter_test.dart';

import 'package:stock_pyme/utils/formatters.dart';

void main() {
  test('Formato de pesos chilenos', () {
    expect(formatCLP(4990), r'$4.990');
    expect(formatCLP(1250000), r'$1.250.000');
  });

  test('Monedas con y sin centavos', () {
    expect(AppCurrency.clp.format(1290), r'$1.290');
    expect(AppCurrency.usd.format(1250), r'US$12.50');
    expect(AppCurrency.eur.format(123456), '1.234,56 €');
    expect(AppCurrency.brl.format(990), r'R$ 9,90');
    expect(AppCurrency.usd.parse('12,5'), 1250);
    expect(AppCurrency.usd.parse('1,234.50'), 123450);
    expect(AppCurrency.clp.parse(r'$4.990'), 4990);
    expect(AppCurrency.eur.toInput(-1990), '-19,90');
  });

  test('Cantidades a granel', () {
    expect(formatQty(3), '3');
    expect(formatQty(1.25), '1,25');
    expect(parseQty('1,5'), 1.5);
  });
}
